//  WARNING: DEPRECATED, use terraform scripts for server deployment!

var credentials = require('../../credentials.json')
const fs = require('fs')
const { S3Client } = require("@aws-sdk/client-s3");
const { EC2Client, AuthorizeSecurityGroupIngressCommand, RunInstancesCommand } = require('@aws-sdk/client-ec2');
const { Upload } = require("@aws-sdk/lib-storage");
const path = require('path');
require('aws-sdk/lib/maintenance_mode_message').suppress = true;

const region = "us-east-1";
const bucketName = 'chuckycodes-games';
const s3Prefix = 'poker-game/server/linux';

const clientConfig = {
    region: region,
    credentials: {
        accessKeyId: credentials.key,
        secretAccessKey: credentials.secret
    }
};

const STARTUP_COMMANDS_SCRIPT = `#!/bin/bash
set -e

# System Update and Dependencies
sudo dnf update -y
sudo dnf install -y nginx libXcursor libXinerama libXrandr libXi fontconfig nmap-ncat
mkdir -p /home/ec2-user/logs

# Download Files (Including the Nginx config)
aws s3 cp s3://${bucketName}/${s3Prefix} /home/ec2-user/ --recursive
cd /home/ec2-user

# Nginx setup
# Ensure the config exists before copying
if [ -f "poker.conf" ]; then
    # Copy the downloaded configuration file to the Nginx conf.d directory
    sudo cp poker.conf /etc/nginx/conf.d/poker.conf
    # Test Nginx configuration file for syntax errors
    sudo nginx -t
    # Enable Nginx to start on boot and start the service now
    sudo systemctl enable nginx
    sudo systemctl start nginx
else
    echo "Error: poker.conf not found in S3 download"
    exit 1
fi

# Apply permissions for game server file
chmod +x ./poker_server.x86_64

# Create a small "port finder" helper script on the EC2
cat << 'EOF' > /home/ec2-user/start_game_session.sh
#!/bin/bash
# start_game_session.sh

# Goal of this script: 
#  - free a port
#  - launch a new godot server process 
#  - register that new port as a path (/game/PORT) so that nginx can route requests to it
#  - report back to the launcher process (lambda function) what that new port is

# Settings
MIN_PORT=12000
MAX_PORT=13000
SERVER_BIN="/home/ec2-user/poker_server.x86_64"
LOG_DIR="/home/ec2-user/logs"

# Find available port
while :; do
    PORT=$(( (RANDOM % ($MAX_PORT - $MIN_PORT + 1)) + $MIN_PORT))
    # Is anything listening on this port?
    (echo >/dev/tcp/localhost/$PORT) >/dev/null 2>&1 || break
done

# Start the server instance
# "$@" -> this will add any custom game parameters we are sending from lambda
sudo -u ec2-user $SERVER_BIN --server --headless --port=$PORT "$@" > "$LOG_DIR/poker_$PORT.log" 2>&1 &

# Lambda is going to read 'StandardOutputContent' from SSM, so print the port here
echo $PORT
EOF

# Ensure new file permissions are correct
chmod +x /home/ec2-user/start_game_session.sh
chown ec2-user:ec2-user /home/ec2-user/logs
`;

const s3Client = new S3Client(clientConfig);
const ec2Client = new EC2Client(clientConfig);

const uploadFolderToS3 = async () => {
    const localFolderPath = './exports/server/linux';
    const files = fs.readdirSync(localFolderPath, { recursive: true, withFileTypes: true });

    for (const file of files) {
        const fullLocalPath = path.join(localFolderPath, file.name);
        if (file.isFile()) {
            const relativePath = path.relative(localFolderPath, fullLocalPath);
            const s3Key = path.posix.join(s3Prefix, relativePath); // Use path.posix for S3 keys
            const fileStream = fs.createReadStream(fullLocalPath);

            const s3ParallelUploads = new Upload({
                client: s3Client,
                params: {
                    Bucket: bucketName,
                    Key: s3Key,
                    Body: fileStream
                }
            });

            await s3ParallelUploads.done()
            console.log(`Successfully uploaded ${s3Key}`);
        }
    }

    // Then upload the nginx config to the s3 folder as well
    const filePath = "./poker.conf";
    const nginxS3Key = path.posix.join(s3Prefix, filePath);
    const fileStream = fs.createReadStream(filePath);

    const nginxConfigUpload = new Upload({
        client: s3Client,
        params: {
            Bucket: bucketName,
            Key: nginxS3Key,
            Body: fileStream
        }
    });

    await nginxConfigUpload.done()
    console.log(`Successfully uploaded poker.conf to ${nginxS3Key}`);
};

async function createAndLaunchEC2() {
    const cleanScript = STARTUP_COMMANDS_SCRIPT.trim();
    const STARTUP_COMMANDS_BASE64 = Buffer.from(cleanScript).toString('base64');

    const AMI_ID = "ami-0341d95f75f311023"; // Linux server ami
    const INSTANCE_TYPE = "t3.micro";
    const SECURITY_GROUP_ID = "sg-0f27397c21075ecfc";
    const INSTANCE_PROFILE_ARN = "arn:aws:iam::072351085675:instance-profile/game-server-ec2-role";

    // Authorize Ingress Rules
    try {
        console.log("Authorizing Ingress Rules...");
        const ingressCommand = new AuthorizeSecurityGroupIngressCommand({
            GroupId: SECURITY_GROUP_ID,
            IpPermissions: [
                {
                    IpProtocol: 'tcp',
                    FromPort: 8000,
                    ToPort: 8000,
                    IpRanges: [{ CidrIp: '0.0.0.0/0', Description: 'Nginx Front Door' }]
                }
            ]
        });
        await ec2Client.send(ingressCommand);
        console.log("Ingress Rules Authorized successfully.");

    } catch (e) {

        if (e.name === 'InvalidPermission.Duplicate') {
            console.log("Ingress rules already exist. Skipping ingress rule creation.");
        } else {
            console.error("Error authorizing ingress:", e);
            throw(e);
        }
    }
    
    // Run/Launch EC2 Instance
    try {
        console.log("Launching EC2 Instance...");
        const runInstancesCommand = new RunInstancesCommand({
            ImageId: AMI_ID,
            MinCount: 1,
            MaxCount: 1,
            InstanceType: INSTANCE_TYPE,
            // The IAM Profile is passed as a structure containing ARN and Name
            IamInstanceProfile: {
                Arn: INSTANCE_PROFILE_ARN,
            },
            // Specify Network Interface to ensure a Public IP is assigned
            NetworkInterfaces: [{
                DeviceIndex: 0, // Primary network interface
                AssociatePublicIpAddress: true,
                Groups: [SECURITY_GROUP_ID] // Attach the security group to the interface
            }],
            UserData: STARTUP_COMMANDS_BASE64,
        });

        const instanceResponse = await ec2Client.send(runInstancesCommand);
        const instanceId = instanceResponse.Instances[0].InstanceId;
        console.log(`EC2 Instance Launched successfully! ID: ${instanceId}`);
        
    } catch (e) {
        console.error("Error launching EC2 instance:", e);
    }
}

// Main
uploadFolderToS3()
    .then(() => {
        createAndLaunchEC2().then(() => {
            console.log("EC2 instance successfully launchhed")
        }).catch(err => console.error("Failed to launch EC2 instance:", err))
    })
    .catch(err => console.error('Folder upload failed:', err));