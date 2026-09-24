import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const GameRecordList = pokerApiProto.lookupType("poker_api.GameRecordList");
const GameStatus = pokerApiProto.lookupEnum("poker_api.GameStatus");
const GamePrivacy = pokerApiProto.lookupEnum("poker_api.GamePrivacy");
const FriendStatus = pokerApiProto.lookupEnum("poker_api.FriendStatus");

const GAMES_TABLE = process.env.GAMES_TABLE;
const FRIENDS_TABLE = process.env.FRIENDS_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    try {
        var activeFriendsGames = []

        // Query Friends table for active friends
        const friendsResponse = await docClient.send(new QueryCommand({
            TableName: FRIENDS_TABLE,
            KeyConditionExpression: "accountId = :accId",
            FilterExpression: "friendStatus = :friendStatus",
            ExpressionAttributeValues: {
                ":accId": accountId,
                ":friendStatus": FriendStatus.values.FRIEND
            }
        }));

        const friendIds = friendsResponse.Items.map(item => item.peerAccountId);

        if (friendIds.length > 0) {
            // Then query Games table GSI in parallel (Promise.all)
            // Only get active games that have privacy PUBLIC or FRIENDS
            const gameQueries = friendIds.map(friendId => docClient.send(new QueryCommand({
                TableName: GAMES_TABLE,
                IndexName: "HostAccountIdIndex",
                KeyConditionExpression: "hostAccountId = :hostId",
                FilterExpression: "gameStatus <> :endedStatus AND gamePrivacy IN (:publicPrivacy, :friendsPrivacy)",
                ExpressionAttributeValues: {
                    ":hostId": friendId,
                    ":endedStatus": GameStatus.values.ENDED,
                    ":publicPrivacy": GamePrivacy.values.PUBLIC,
                    ":friendsPrivacy": GamePrivacy.values.FRIENDS
                }
                }))
            );

            const gameResults = await Promise.all(gameQueries);
            activeFriendsGames = gameResults.flatMap(res => res.Items || []);
            console.log(`Number of friend games found: ${activeFriendsGames.length}`)
        }

        // Lastly get games hosted by requestor as well, merge results

        const gamesQueryResponse = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            IndexName: "HostAccountIdIndex", 
            KeyConditionExpression: "hostAccountId = :hostId",
            FilterExpression: "gameStatus <> :endedStatus",
            ExpressionAttributeValues: {
                ":hostId": accountId,
                ":endedStatus": GameStatus.values.ENDED,
            }
        }));

        const gameRecordsList = GameRecordList.create({
            records: [...activeFriendsGames, ...gamesQueryResponse.Items]
        })

        const gameRecordsListObject = GameRecordList.toObject(gameRecordsList, {
            enums: Number,
            defaults: true
        });

        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(gameRecordsListObject)
        };

    } catch (error) {
        console.error(error);
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Internal server error"
                })
            )
        };
    }
};