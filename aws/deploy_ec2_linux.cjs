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

            try {
                await s3.upload(params).promise();
                console.log(`Successfully uploaded ${fullLocalPath} to s3://${bucketName}/${s3Key}`);
            } catch (error) {
                console.error(`Error uploading ${fullLocalPath}:`, error);
            }
        }
    }
};


async function createAndLaunchEC2() {
    // NOTE: Keep the script flush with the left margin inside the template literal
    // to prevent unwanted leading spaces in the encoded string.
    const STARTUP_COMMANDS_SCRIPT = `#!/bin/bash
set -e
sudo dnf update -y
sudo dnf install -y libXcursor libXinerama libXrandr libXi
aws s3 cp s3://${bucketName}/${s3Prefix} . --recursive
chmod +x ./poker_server.x86_64
./poker_server.x86_64 --server --headless --port=12001 > /var/log/poker_server.log 2>&1 &`;

    const cleanScript = STARTUP_COMMANDS_SCRIPT.trim();
    const STARTUP_COMMANDS_BASE64 = Buffer.from(cleanScript).toString('base64');

    const AMI_ID = "ami-0341d95f75f311023"; // Linux server ami
    const INSTANCE_TYPE = "t3.micro";
    const SECURITY_GROUP_NAME = "poker-game-sg";
    const INSTANCE_PROFILE_NAME = "game-server-ec2-role";
    const SECURITY_GROUP_ID = "sg-0f27397c21075ecfc";

    const INSTANCE_PROFILE_ARN = "arn:aws:iam::072351085675:instance-profile/game-server-ec2-role";


    // Authorize Ingress Rules (UDP on 12077-12087)
    try {
        console.log("Authorizing Ingress Rules...");
        const ingressCommand = new AuthorizeSecurityGroupIngressCommand({
            GroupId: SECURITY_GROUP_ID,
            IpPermissions: [
                {
                    IpProtocol: 'tcp',
                    FromPort: 12000,
                    ToPort: 13000,
                    IpRanges: [{ CidrIp: '0.0.0.0/0' }]
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