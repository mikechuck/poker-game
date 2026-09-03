import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetAccountByFriendCode, GetAccount } from "./shared/utilities.mjs";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const RelationshipRecord = pokerApiProto.lookupType("poker_api.RelationshipRecord");
const RelationshipStatus = pokerApiProto.lookupEnum("poker_api.RelationshipStatus");

const RELATIONSHIPS_TABLE = process.env.RELATIONSHIPS_TABLE;
const ACCOUNTS_TABLE = process.env.ACCOUNTS_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

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

    if (!accountId) {
        return {
            statusCode: 401,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Unauthorized" 
                })
            )
        };
    }

    if (!RELATIONSHIPS_TABLE || !ACCOUNTS_TABLE) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Server configuration error"
                })
            )
        };
    }

    const body = JSON.parse(event.body)
    const friendCode = body.friendCode

    if (!friendCode) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing friendCode field in request body" 
                })
            )
        }; 
    }

    try {
        const requestorAccountRecord = await GetAccount(accountId, ACCOUNTS_TABLE);
        const friendAccountRecord = await GetAccountByFriendCode(friendCode, ACCOUNTS_TABLE);
        const now = Date.now()

        if (friendAccountRecord == null) {
            return {
                statusCode: 403,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: "Invalid friend code" 
                    })
                )
            };
        }

        // Construct record for requestor account

        const newRequestorRelationshipRecordObject = RelationshipRecord.toObject(
            RelationshipRecord.create({
                accountId: requestorAccountRecord.accountId,
                peerAccountId: friendAccountRecord.accountId,
                peerPlayerName: friendAccountRecord.playerName,
                peerProfilePictureUrl: friendAccountRecord.profilePictureUrl,
                peerPlayerColor: friendAccountRecord.playerColor,
                relationshipStatus: RelationshipStatus.values.OUTGOING_PENDING,
                createTimeEpochMilliseconds: now
            }), {
            enums: Number,
            defaults: true
        });

        // Construct record for peer account

        const newPeerRelationshipRecordObject = RelationshipRecord.toObject(
            RelationshipRecord.create({
                accountId: friendAccountRecord.accountId,
                peerAccountId: requestorAccountRecord.accountId,
                peerPlayerName: requestorAccountRecord.playerName,
                peerProfilePictureUrl: requestorAccountRecord.profilePictureUrl,
                peerPlayerColor: requestorAccountRecord.playerColor,
                relationshipStatus: RelationshipStatus.values.INCOMING_PENDING,
                createTimeEpochMilliseconds: now
            }), {
            enums: Number,
            defaults: true
        });

        try {

            // Insert both directions of the relationship
            await docClient.send(
                new PutCommand({
                    TableName: RELATIONSHIPS_TABLE,
                    Item: newRequestorRelationshipRecordObject,
                    // Checks if the partition key (or sort key) does NOT exist yet
                    ConditionExpression: "attribute_not_exists(accountId) AND attribute_not_exists(peerAccountId)"
                })
            );

            await docClient.send(
                new PutCommand({
                    TableName: RELATIONSHIPS_TABLE,
                    Item: newPeerRelationshipRecordObject,
                    // Checks if the partition key (or sort key) does NOT exist yet
                    ConditionExpression: "attribute_not_exists(accountId) AND attribute_not_exists(peerAccountId)"
                })
            );

        } catch (error) {
            if (error.name === "ConditionalCheckFailedException") {
                console.log(`Relationship already exists between ${requestorAccountRecord.accountId} and ${friendAccountRecord.accountId}`)
                
                return {
                    statusCode: 200
                }
            } else {
                throw error
            }
        }

        return {
            statusCode: 201
        };
        
    } catch (error) {
        console.error("Internal server error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Failed to create friend request"
                })
            )
        };
    }
};