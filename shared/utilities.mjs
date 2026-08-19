import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const RelationshipStatus = pokerApiProto.lookupEnum("poker_api.RelationshipStatus");
const RelationshipRecordList = pokerApiProto.lookupType("poker_api.RelationshipRecordList");


// Helper utility to query game record from dynamo table
export const GetGameRecord = async (gameId, gamesTableName) => {
    try {
        const gameQueryResponse = await docClient.send(new QueryCommand({
            TableName: gamesTableName,
            KeyConditionExpression: "gameId = :gId",
            ExpressionAttributeValues: {
                ":gId": gameId
            },
            ConsistentRead: true
        }));
    
        const game = gameQueryResponse.Items?.[0] ?? null;
    
        if (GameRecord.verify(game) == null) {
            return GameRecord.create(game);
        } else {
            console.error("Invalid game record:", GameRecord.verify(game))
        }

    } catch (error) {
        console.error("Invernal server error:", error.message);
    }
}

export const GetFriendsList = async (accountId, relationshipsTableName) => {
    try {
        const friendsQueryResponse = await docClient.send(new QueryCommand({
            TableName: relationshipsTableName,
            KeyConditionExpression: "accountId = :aId",
            FilterExpression: "relationshipStatus = :friendStatus",
            ExpressionAttributeValues: {
                ":aId": accountId,
                ":friendStatus": RelationshipStatus.values.FRIEND
            }
        }));
    
        return RelationshipRecordList.create({
            relationships: friendsQueryResponse.Items ?? []
        });
    } catch (error) {
        console.error("Invernal server error:", error.message);
    }
}