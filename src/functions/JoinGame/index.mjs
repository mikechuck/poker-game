import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord, GetFriendsList } from "./shared/utilities.mjs";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const GamePrivacy = pokerApiProto.lookupEnum("poker_api.GamePrivacy");
const GameStatus = pokerApiProto.lookupEnum("poker_api.GameStatus");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const RelationshipRecordList = pokerApiProto.lookupType("poker_api.RelationshipRecordList");
const JoinTokenRecord = pokerApiProto.lookupType("poker_api.JoinTokenRecord");

const GAMES_TABLE = process.env.GAMES_TABLE;
const JOIN_TOKENS_TABLE = process.env.JOIN_TOKENS_TABLE;
const RELATIONSHIPS_TABLE = process.env.RELATIONSHIPS_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;
    const gameId = event.pathParameters?.gameId;

    if (!gameId) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing gameId parameter" 
                })
            )
        };
    }

    try {
        const game = await GetGameRecord(gameId, GAMES_TABLE);
        var joinToken = "";

        switch (game.gamePrivacy)
        {
            // As long as the game id is valid, allow anyone to join
            case GamePrivacy.values.PUBLIC:
                joinToken = await saveJoinCodeForPlayer(accountId, gameId);
                break;
            // Validate against friends table to see if player is friends with the hostAccountId of the game record
            case GamePrivacy.values.FRIENDS:
                // Host can always join
                if (game.hostAccountId == accountId) {
                    joinToken = await saveJoinCodeForPlayer(accountId, gameId);
                    break;
                }

                // If not host, check friend status
                const friendsList = await GetFriendsList(accountId, RELATIONSHIPS_TABLE);
                var isFriendsWithHost = false
                friendsList.relationships.forEach(friendsListRecord => {
                    if (friendAccountId.peerAccountId == game.hostAccountId) {
                        isFriendsWithHost = true
                    }
                })

                if (isFriendsWithHost) {
                    joinToken = await saveJoinCodeForPlayer(accountId, gameId);
                } else {
                    return {
                        statusCode: 403
                    };
                }
                break;

            // Only the host player can hoin their own private game
            case GamePrivacy.values.PRIVATE:
                if (game.hostAccountId == accountId) {
                    joinToken = await saveJoinCodeForPlayer(accountId, gameId)
                } else {
                    return {
                        statusCode: 403
                    };
                }
                break;

            // TODO: Invite code required
            case GamePrivacy.values.INVITE:
            default:
                return {
                    statusCode: 403
                };
                break;
        }

        return {
            statusCode: 200,
            body: joinToken
        };

    } catch (error) {
        console.error("Failed to create join token record for player.", error);
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

const saveJoinCodeForPlayer = async (accountId, gameId) => {
    const joinToken = crypto.randomUUID()

    const newJoinTokenEntry = {
        accountId: accountId,
        gameId: gameId,
        joinToken: joinToken,
        expirationTimeEpochMilliseconds: Date.now() + 60000 // Expire 1 minute from now
    }

    const errMsg = JoinTokenRecord.verify(newJoinTokenEntry);
    if (errMsg) {
        throw new Error(errMsg);
    }

    const newJoinTokenRecord = JoinTokenRecord.create(newJoinTokenEntry);
    const newJoinTokenRecordObject = JoinTokenRecord.toObject(newJoinTokenRecord, {
        enums: Number,
        defaults: true
    });

    await docClient.send(new PutCommand({
        TableName: JOIN_TOKENS_TABLE,
        Item: newJoinTokenRecordObject
    }));
    
    return joinToken;
}