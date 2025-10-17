var credentials = require('../../credentials.json')
const spawn = require('child_process')
const fs = require('fs')
const archiver = require('archiver')
var AWS = require('aws-sdk')
const path = require('path');
import { IAMClient, CreateInstanceProfileCommand } from "@aws-sdk/client-iam";
require('aws-sdk/lib/maintenance_mode_message').suppress = true;

AWS.config.update({
	region: "us-east-1",
	accessKeyId: credentials.key,
	secretAccessKey: credentials.secret
});

const s3 = new AWS.S3();
const iamClient = new IAMClient();

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

async function createIAMInstanceProfile(profileName) {
  try {
    const command = new CreateInstanceProfileCommand({
        InstanceProfileName: profileName
    });
    const data = await client.send(command);
    console.log("Instance Profile created successfully:", data.InstanceProfile);
    return data.InstanceProfile;
  } catch (error) {
    console.error("Error creating instance profile:", error);
    throw error;
  }
}


uploadFolderToS3(localFolderToUpload, targetS3Bucket, s3TargetPrefix)
    .then(() => console.log('Folder upload complete.'))
    .catch(err => console.error('Folder upload failed:', err));

createIAMInstanceProfile("poker-ec2-instance")
    .then(() => console.log("instance profile created"))
    .catch(err => console.log("Instance profile failed:", err))
    
const ec2Client = new AWS.EC2();