import protobuf from "protobufjs";
import path from "node:path";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";

const GAME_LEDGERS_TABLE = process.env.GAME_LEDGERS_TABLE;
const GAMES_TABLE = process.env.GAMES_TABLE;

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameLedgerRecord = pokerApiProto.lookupType("poker_api.GameLedgerRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");


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
    console.log("body:", body);
    const buyInChips = body.buyInChips;
    const cashOutChips = body.cashOutChips;

    if (!buyInChips && !cashOutChips) {
        return {
            statusCode: 403,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Internal Server Error",
                    error: "Must send either buyInChips or cashOutChips in the request body"
                })
            )
        }
    }

    const params = {
        TableName: GAME_LEDGERS_TABLE,
        Key: {
            gameId: gameId,       // Hash key
            accountId: accountId, // Range key
        },
        ReturnValues: "ALL_NEW",
    };

    // Creating new record, use the buyIn for both buyInChips and cashOutChips
    if (buyInChips && !cashOutChips) {
        params.UpdateExpression = "SET #buyIn = :val, #cashOut = if_not_exists(#cashOut, :val)";
        params.ExpressionAttributeNames = {
            "#buyIn": "buyInChips",
            "#cashOut": "cashOutChips",
        };
        params.ExpressionAttributeValues = {
            ":val": buyInChips,
        };
    } else if (cashOutChips && !buyInChips) {
        params.UpdateExpression = "SET #cashOut = :val";
        params.ExpressionAttributeNames = {
            "#cashOut": "cashOutChips",
        };
        params.ExpressionAttributeValues = {
            ":val": cashOutChips,
        };
    } else {
        params.UpdateExpression = "SET #buyIn = :buyInVal, #cashOut = :cashOutVal";
        params.ExpressionAttributeNames = {
            "#buyIn": "buyInChips",
            "#cashOut": "cashOutChips",
        };
        params.ExpressionAttributeValues = {
            ":buyInVal": buyInChips,
            ":cashOutVal": cashOutChips
        };
    }

    try {
        await docClient.send(new UpdateCommand(params));
        return {
            statusCode: 200
        }
    } catch (error) {
        console.error("Error executing operation:", error);
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Internal Server Error",
                    error: error
                })
            )
        }
    }
}