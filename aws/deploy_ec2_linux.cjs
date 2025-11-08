var credentials = require('../../credentials.json')
const fs = require('fs')
var AWS = require('aws-sdk')
const { EC2Client, AuthorizeSecurityGroupIngressCommand, RunInstancesCommand } = require('@aws-sdk/client-ec2');
const path = require('path');
require('aws-sdk/lib/maintenance_mode_message').suppress = true;

const region = "us-east-1";
const bucketName = 'chuckycodes-games';
const s3Prefix = 'poker-game/server/linux';

// AWS.config.update({
// 	region,
// 	accessKeyId: credentials.key,
// 	secretAccessKey: credentials.secret
// });

// console.log("awsconfig: ", awsConfig)

const s3 = new AWS.S3();
const ec2Client = new EC2Client();

const uploadFolderToS3 = async () => {
    const localFolderPath = './exports/server/linux';
    const files = fs.readdirSync(localFolderPath, { recursive: true, withFileTypes: true });

    for (const file of files) {
        const fullLocalPath = path.join(localFolderPath, file.name);
        if (file.isFile()) {
            const relativePath = path.relative(localFolderPath, fullLocalPath);
            const s3Key = path.posix.join(s3Prefix, relativePath); // Use path.posix for S3 keys

            const fileContent = fs.readFileSync(fullLocalPath);

            const params = {
                Bucket: bucketName,
                Key: s3Key,
                Body: fileContent,
            };

            await s3.upload(params).promise();
            console.log(`Successfully uploaded ${fullLocalPath} to s3://${bucketName}/${s3Key}`);
        }
    }

    // Then upload the nginx config to the s3 folder as well
    const filePath = "./poker.conf";
    const fileContent = fs.readFileSync(filePath);

    const params = {
        Bucket: bucketName,
        Key: path.posix.join(s3Prefix, filePath),
        Body: fileContent,
    };

    await s3.upload(params).promise();
    console.log(`Successfully uploaded poker.conf to s3://${bucketName}/`);
};


async function createAndLaunchEC2() {
    // NOTE: Keep the script flush with the left margin inside the template literal
    // to prevent unwanted leading spaces in the encoded string.
//     const STARTUP_COMMANDS_SCRIPT = `#!/bin/bash
// set -e

// # --- 1. System Update and Dependencies ---
// sudo dnf update -y
// # Install Nginx and other required libs
// sudo dnf install -y nginx libXcursor libXinerama libXrandr libXi fontconfig

// # --- 2. Download Files (Including the Nginx config) ---
// aws s3 cp s3://${bucketName}/${s3Prefix} /home/ec2-user/ --recursive
// cd /home/ec2-user

// # --- 3. Configure and Start Nginx ---
// NGINX_CONF_PATH="/etc/nginx/conf.d/poker.conf"

// # Copy the downloaded configuration file to the Nginx conf.d directory
// sudo cp server_nginx.conf $NGINX_CONF_PATH

// # Test Nginx configuration file for syntax errors
// sudo nginx -t

// # Enable Nginx to start on boot and start the service now
// sudo systemctl enable nginx
// sudo systemctl start nginx

// # --- 4. Start Godot Game Server (Example) ---
// chmod +x ./poker_server.x86_64

// # Start the first Godot server instance (port 12001) in the background
// ./poker_server.x86_64 --server --headless --port=12001 > /var/log/poker_server.log 2>&1 &`;

    const STARTUP_COMMANDS_SCRIPT = `#!/bin/bash
set -e

# --- 1. System Update and Dependencies ---
sudo dnf update -y
sudo dnf install -y nginx libXcursor libXinerama libXrandr libXi fontconfig nmap-ncat

# --- 2. Download Files (Including the Nginx config) ---
aws s3 cp s3://${bucketName}/${s3Prefix} /home/ec2-user/ --recursive
cd /home/ec2-user

# --- 3. FIX: Ensure Nginx loads custom config and set up services ---
NGINX_CONF_D_PATH="/etc/nginx/conf.d/poker.conf"

# Copy the downloaded configuration file to the Nginx conf.d directory
sudo cp poker.conf $NGINX_CONF_D_PATH
sudo sed -i '/include \/etc\/nginx\/default.d\/\*\.conf;/a include \/etc\/nginx\/conf\.d\/\*\.conf;' /etc/nginx/nginx.conf

# Test Nginx configuration file for syntax errors
sudo nginx -t

# Enable Nginx to start on boot and start the service now
sudo systemctl enable nginx
sudo systemctl start nginx

# --- 4. Start Godot Game Server Safely (Port 12001) ---
chmod +x ./poker_server.x86_64

# Start the Godot server as the standard 'ec2-user' to avoid root warnings/issues.
sudo -u ec2-user ./poker_server.x86_64 --server --headless --port=12001 > /home/ec2-user/poker_server.log 2>&1 &
`;
    const cleanScript = STARTUP_COMMANDS_SCRIPT.trim();
    const STARTUP_COMMANDS_BASE64 = Buffer.from(cleanScript).toString('base64');

    const AMI_ID = "ami-0341d95f75f311023"; // Linux server ami
    const INSTANCE_TYPE = "t3.micro";
    const SECURITY_GROUP_ID = "sg-0f27397c21075ecfc";
    const NLB_SECURITY_GROUP_ID = "sg-08910acd8a0aa5cb2";

    const INSTANCE_PROFILE_ARN = "arn:aws:iam::072351085675:instance-profile/game-server-ec2-role";

    // Authorize Ingress Rules
    try {
        console.log("Authorizing Ingress Rules...");
        const ingressCommand = new AuthorizeSecurityGroupIngressCommand({
            GroupId: SECURITY_GROUP_ID,
            IpPermissions: [
                {
                    IpProtocol: 'tcp',
                    FromPort: 8000, // The specific port Nginx is listening on
                    ToPort: 8000,
                    
                    // Restrict source to ONLY the NLB/VPC
                    UserIdGroupPairs: [{ GroupId: NLB_SECURITY_GROUP_ID }]
                }
            ]
        });
        await ec2Client.send(ingressCommand);
        console.log("Ingress Rules Authorized successfully.");

    } catch (e) {
        if (e.name === 'InvalidPermission.Duplicate') {
            console.warn("Ingress rules already exist. Skipping authorization.");
        } else {
            console.error("Error authorizing ingress:", e);
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


uploadFolderToS3()
    .then(() => {
        //  Run ec2 instantiation here
        createAndLaunchEC2().then(() => {
            console.log("EC2 instance successfully launchhed")
        }).catch(err => console.error("Failed to launch EC2 instance:", err))
    })
    .catch(err => console.error('Folder upload failed:', err));