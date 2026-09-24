import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DynamoDBDocumentClient, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const FriendStatus = pokerApiProto.lookupEnum("poker_api.FriendStatus");

const FRIENDS_TABLE = process.env.FRIENDS_TABLE;

export const handler = async (event) => {
    const rejectorAccountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    if (!rejectorAccountId) {
        return {
            statusCode: 401,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Unauthorized" 
                })
            )
        };
    }

    if (!FRIENDS_TABLE) {
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
        // Delete both incoming and outgoing request records

        await docClient.send(new DeleteCommand({
            TableName: FRIENDS_TABLE,
            Key: {
                accountId: rejectorAccountId,
                peerAccountId: requestorAccountId
            },
            ConditionExpression: "friendStatus = :expectedStatus",
            ExpressionAttributeValues: {
                ":expectedStatus": FriendStatus.values.INCOMING_PENDING
            }
        }));

        await docClient.send(new DeleteCommand({
            TableName: FRIENDS_TABLE,
            Key: {
                accountId: requestorAccountId,
                peerAccountId: rejectorAccountId
            },
            ConditionExpression: "friendStatus = :expectedStatus",
            ExpressionAttributeValues: {
                ":expectedStatus": FriendStatus.values.OUTGOING_PENDING
            }
        }));

        console.log(`[Lambda] Friend request from ${requestorAccountId} to ${rejectorAccountId} accepted`)
        
        return {
            statusCode: 200
        }
        
    } catch (error) {
        if (error.name === "ConditionalCheckFailedException") {
            console.warn("Update skipped: Friend is not in INCOMING_PENDING state.");
            
            return {
                statusCode: 400,
                body: JSON.stringify({ message: "No pending friend request found to reject." })
            };
        }

        console.log("Internal server error:", error)
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Failed to reject friend request"
                })
            )
        };
    }
};