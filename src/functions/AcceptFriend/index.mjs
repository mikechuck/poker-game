import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const RelationshipStatus = pokerApiProto.lookupEnum("poker_api.RelationshipStatus");

const RELATIONSHIPS_TABLE = process.env.RELATIONSHIPS_TABLE;

export const handler = async (event) => {
    const acceptorAccountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    if (!event.body) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing request body" 
                })
            )
        }; 
    }

    if (!acceptorAccountId) {
        return {
            statusCode: 401,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Unauthorized" 
                })
            )
        };
    }

    if (!RELATIONSHIPS_TABLE) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Server configuration error"
                })
            )
        };
    }

    const requestorAccountId = event.pathParameters.requestorAccountId;

    if (!requestorAccountId) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing requestorAccountId" 
                })
            )
        }; 
    }

    try {
        // Update the incoming request first, and if that succeeds then update the matching outgoing record

        await docClient.send(new UpdateCommand({
            TableName: RELATIONSHIPS_TABLE,
            Key: {
                accountId: acceptorAccountId,
                peerAccountId: requestorAccountId
            },
            UpdateExpression: "SET relationshipStatus = :newStatus",
            ConditionExpression: "relationshipStatus = :expectedStatus",
            ExpressionAttributeValues: {
                ":newStatus": RelationshipStatus.values.FRIEND,
                ":expectedStatus": RelationshipStatus.values.INCOMING_PENDING
            },
            ReturnValues: "ALL_NEW"
        }));

        await docClient.send(new UpdateCommand({
            TableName: RELATIONSHIPS_TABLE,
            Key: {
                accountId: requestorAccountId,
                peerAccountId: acceptorAccountId
            },
            UpdateExpression: "SET status = :status",
            ExpressionAttributeValues: {
                ":status": RelationshipStatus.values.FRIEND
            }
        }));

        console.log(`[Lambda] Friend request from ${requestorAccountId} to ${acceptorAccountId} accepted`)
        
        return {
            statusCode: 200
        }
        
    } catch (error) {
        if (error.name === "ConditionalCheckFailedException") {
            console.warn("Update skipped: Relationship is not in INCOMING_PENDING state.");
            
            return {
                statusCode: 400,
                body: JSON.stringify({ message: "No pending friend request found to accept." })
            };
        }

        console.log("Internal server error:", error)
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Failed to accept friend request"
                })
            )
        };
    }
};