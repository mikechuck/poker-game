import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;

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
        const queryResponse = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            KeyConditionExpression: "gameId = :gId",
            ExpressionAttributeValues: {
                ":gId": gameId
            }
        }));

        const game = queryResponse.Items?.[0] ?? null;

        if (!game) {
            return {
                statusCode: 404,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: "Game session not found"
                    })
                )
            };
        }

        // Return the current status (Whether PENDING or ACTIVE along with the port)
        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(GameRecord.create(game))
        };

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