import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.js";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;
const JOIN_TOKENS_TABLE = process.env.JOIN_TOKENS_TABLE;

export const handler = async (event) => {
    const gameId = event.queryStringParameters?.gameId;

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
        // 1. Query dynamo Games table for the game_id record, get gamePrivacy value and hostAccountId value
        // 2. Check game privacy 
        // - if PUBLIC, generate join token and create join association in dynamo
        // - if FRIENDS, query the friends table to see if the requesting user is friends with the host. If so, create a join token
        // - if INVITE, deny connection for now
        // - if PRIVATE, query game table to see if player is host, if so create join token

        const game = await GetGameRecord(gameId, GAMES_TABLE);

    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Internal server error",
                    error: error.message
                })
            )
        };
    }
};