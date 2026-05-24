import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const GAMES_TABLE = process.env.GAMES_TABLE;

export const handler = async (event) => {
    const gameId = event.queryStringParameters?.gameId;

    if (!gameId) {
        return { statusCode: 400, body: JSON.stringify({ message: "Missing gameId parameter" }) };
    }

    try {
        const response = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            KeyConditionExpression: "GameId = :gId",
            ExpressionAttributeValues: {
                ":gId": gameId
            }
        }));

        const game = response.Items?.[0] ?? null;

        if (!game) {
            return { statusCode: 404, body: JSON.stringify({ message: "Game session not found" }) };
        }

        // Return the current status (Whether PENDING or ACTIVE along with the port)
        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                GameStatus: game.GameStatus,
                Port: game.Port,
            })
        };

    } catch (error) {
        return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
    }
};