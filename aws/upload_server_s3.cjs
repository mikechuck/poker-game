const fs = require('fs')
const mime = require('mime-types');
const { S3Client } = require("@aws-sdk/client-s3");
const { EC2Client, AuthorizeSecurityGroupIngressCommand, RunInstancesCommand } = require('@aws-sdk/client-ec2');
const { Upload } = require("@aws-sdk/lib-storage");
const path = require('path');
require('aws-sdk/lib/maintenance_mode_message').suppress = true;

const BUCKET_NAME = 'chuckycodes-games';
const S3_PREFIX = 'poker-game/server/linux';

const clientConfig = {
    region: "us-east-1",
};

const s3Client = new S3Client(clientConfig);
const ec2Client = new EC2Client(clientConfig);

const uploadFolderToS3 = async () => {
    console.log("Starting upload...");
    const localFolderPath = './exports/server/linux';
    const files = fs.readdirSync(localFolderPath, { recursive: true, withFileTypes: true });

    for (const file of files) {
        const fullLocalPath = path.join(localFolderPath, file.name);
        if (file.isFile()) {
            const s3Key = path.relative(localFolderPath, fullLocalPath);
            const fileStream = fs.createReadStream(fullLocalPath);
            const contentType = mime.lookup(fullLocalPath) || 'application/octet-stream';
            console.log("content type:", contentType);

            const s3ParallelUploads = new Upload({
                client: s3Client,
                params: {
                    Bucket: BUCKET_NAME,
                    Key: s3Key,
                    Body: fileStream,
                    ContentType: contentType
                }
            });

            await s3ParallelUploads.done()
            console.log(`Successfully uploaded ${s3Key}`);
        }
    }

    // Then upload the nginx config to the s3 folder as well
    const filePath = "./poker.conf";
    const nginxS3Key = path.posix.join(S3_PREFIX, filePath);
    const fileStream = fs.createReadStream(filePath);
    const contentType = mime.lookup(filePath) || 'application/octet-stream';

    const nginxConfigUpload = new Upload({
        client: s3Client,
        params: {
            Bucket: BUCKET_NAME,
            Key: nginxS3Key,
            Body: fileStream,
            ContentType: contentType
        }
    });

    await nginxConfigUpload.done()
    console.log(`Successfully uploaded poker.conf to ${nginxS3Key}`);
};


// Main
uploadFolderToS3()
    .then(() => {
        console.log("Done.")
    })
    .catch(err => console.error('Folder upload failed:', err));