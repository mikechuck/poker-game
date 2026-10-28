import protobuf from "protobufjs";
import path from "node:path";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";

const GAME_LEDGERS_TABLE = process.env.GAME_LEDGERS_TABLE;

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameLedgerRecord = pokerApiProto.lookupType("poker_api.GameLedgerRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;


/**
 * Called when a player leaves the game or the user is disconnected
 */

export const handler = async (event) => {
    const gameId = event.pathParameters?.gameId;
    const accountId = event.pathParameters?.accountId;
    
    if (gameId == null) {
        return {
            statusCode: 403,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Invalid parameters, missing gameId" 
                })
            )
        };
    }

    if (accountId == null) {
        return {
            statusCode: 403,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Invalid parameters, missing accountId" 
                })
            )
        };
    }

    if (!event.body) {
        return {
            statusCode: 403,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing request body"
                })
            )
        }; 
    }

    if (await GetGameRecord(gameId, GAMES_TABLE) == null) {
        return {
            statusCode: 403,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Invalid gameId" 
                })
            )
        };
    }

    const body = JSON.parse(event.body)
    const cashOutChips = body.cashOutChips;

    const gameLedgerRecord = GameLedgerRecord.create({
        gameId,
        accountId,
        cashOutChips,
    });

    try {
        await docClient.send(new PutCommand({
            TableName: GAME_LEDGERS_TABLE,
            Item: gameLedgerRecord
        }));

        return {
            statusCode: 200
        }

    } catch (error) {
        return {
            status: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Internal Server Error",
                    error: error
                })
            )
        }
    }
}