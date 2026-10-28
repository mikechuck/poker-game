import protobuf from "protobufjs";
import path from "node:path";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { fileURLToPath } from "node:url";

const GAME_LEDGERS_TABLE = process.env.GAME_LEDGERS_TABLE;

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameLedgerRecord = pokerApiProto.lookupType("poker_api.GameLedgerRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

export const handler = async (event) => {
    const gameId = event.pathParameters?.gameId;

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

    const body = JSON.parse(event.body)
    const accountId = body.accountId;

    try {
        const response = await docClient.send(new QueryCommand({
            TableName: GAME_LEDGERS_TABLE,
            KeyConditionExpression: "gameId = :gId AND accountId = :aId",
            ExpressionAttributeValues: {
                "gId": gameId,
                "aId": accountId
            }
        }));

        let record = response?.Items?.[0] ?? null;

        if (record == null) {
            return {
                statusCode: 500,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: `Failed to find game ledger record for account ${accountId} in game ${gameId}`
                    })
                )
            }
        } else {
            const gameLedgerRecordObject = GameLedgerRecord.toObject(
                GameLedgerRecord.create(record), {
                enums: Number,
                defaults: true
            })

            return {
                statusCode: 200,
                body: JSON.stringify(gameLedgerRecordObject),
            }
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