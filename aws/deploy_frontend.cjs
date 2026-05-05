var credentials = require('../../credentials.json')
const fs = require('fs')
const mime = require('mime-types');
const { S3Client } = require("@aws-sdk/client-s3");
const { Upload } = require("@aws-sdk/lib-storage");
const { CloudFrontClient, CreateInvalidationCommand } = require("@aws-sdk/client-cloudfront");
const path = require('path');
require('aws-sdk/lib/maintenance_mode_message').suppress = true;

const BUCKET_NAME = 'chuckycodes-poker-game';
const DIST_ID = "E1SJ2O1VFU30SP";

const clientConfig = {
    region: "us-east-1",
    credentials: {
        accessKeyId: credentials.key,
        secretAccessKey: credentials.secret
    }
};

const s3Client = new S3Client(clientConfig);
const cfClient = new CloudFrontClient(clientConfig);

const uploadFolderToS3 = async () => {
    const localFolderPath = './exports/web';
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
};

const invalidateCloudfrontCache = async () => {
    await cfClient.send(new CreateInvalidationCommand({
      DistributionId: DIST_ID,
      InvalidationBatch: {
        CallerReference: `deploy-${Date.now()}`,
        Paths: { Quantity: 1, Items: ["/*"] }
      }
    }));
}

async function deploy() {
    try {
        console.log("Starting deployment...");
        await uploadFolderToS3();

        console.log("Invalidating cloudfront cache...");
        await invalidateCloudfrontCache();
        console.log("Deployment complete.");
    } catch (err) {
        console.error("Deployment failed", err);
    }
}

deploy();