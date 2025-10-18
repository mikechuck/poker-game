var credentials = require('../../credentials.json')
const spawn = require('child_process')
const fs = require('fs')
const archiver = require('archiver')
var AWS = require('aws-sdk')
const path = require('path');
require('aws-sdk/lib/maintenance_mode_message').suppress = true;

AWS.config.update({
	region: "us-east-1",
	accessKeyId: credentials.key,
	secretAccessKey: credentials.secret
});

const s3 = new AWS.S3();

const uploadFolderToS3 = async () => {
    const localFolderPath = './exports/server';
    const bucketName = 'chuckycodes-games';
    const s3Prefix = 'poker-game/server';
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
    let sgId;
    const STARTUP_COMMANDS_SCRIPT = `#!/bin/bash
    sudo apt update
    sudo apt install -y libxcursor-dev libxinerama-dev libxrandr-dev libxi-dev &
    # Wait for apt installs to finish (optional, but safer)
    wait
    aws s3 cp s3://godot-server-totally-unique-name-987654321/GodotServer . &
    chmod +x GodotServer &
    ./GodotServer --server --headless`;
    const STARTUP_COMMANDS_BASE64 = Buffer.from(USER_DATA_SCRIPT).toString('base64');

    const AMI_ID = "ami-0e3c2921641a4a215"; // Windows server
    const INSTANCE_TYPE = "t3.micro";
    const SECURITY_GROUP_NAME = "poker-game-sg";
    const INSTANCE_PROFILE_NAME = "game-server-ec2-role";
    const SECURITY_GROUP_ID = "sg-0f27397c21075ecfc";

    // NOTE: You must replace 'YOUR_INSTANCE_PROFILE_ARN' with the actual ARN
    const INSTANCE_PROFILE_ARN = "arn:aws:iam::072351085675:instance-profile/game-server-ec2-role";


    // Authorize Ingress Rules (UDP on 12077-12087)
    try {
        console.log("Authorizing Ingress Rules...");
        const ingressCommand = new AuthorizeSecurityGroupIngressCommand({
            GroupId: sgId,
            IpPermissions: [
                {
                    IpProtocol: 'tcp',
                    FromPort: 12077,
                    ToPort: 12087,
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
                Name: INSTANCE_PROFILE_NAME 
            },
            // Note: SecurityGroupIds must be an array of IDs
            SecurityGroupIds: [sgId], 
            // Specify Network Interface to ensure a Public IP is assigned
            NetworkInterfaces: [{
                DeviceIndex: 0, // Primary network interface
                AssociatePublicIpAddress: true,
                Groups: [sgId] // Attach the security group to the interface
            }],
            UserData: USER_DATA_BASE64,
        });

        const instanceResponse = await ec2Client.send(runInstancesCommand);
        const instanceId = instanceResponse.Instances[0].InstanceId;
        console.log(`EC2 Instance Launched successfully! ID: ${instanceId}`);
        
    } catch (e) {
        console.error("Error launching EC2 instance:", e);
    }
}


uploadFolderToS3(localFolderToUpload, targetS3Bucket, s3TargetPrefix)
    .then(() => {
        //  Run ec2 instantiation here
        createAndLaunchEC2().then(() => {
            console.log("EC2 instance successfully launchhed")
        }).catch(err => console.error("Failed to launch EC2 instance:", err))
    })
    .catch(err => console.error('Folder upload failed:', err));
    
const ec2Client = new AWS.EC2();