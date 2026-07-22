import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import Enums from "./shared/enums.json" with { type: "json" };

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const GAMES_TABLE = process.env.GAMES_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;
    console.log("Account id:", accountId);

    try {
        const response = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            IndexName: "HostPlayerIdIndex", 
            KeyConditionExpression: "hostPlayerId = :hId",
            ExpressionAttributeValues: {
                ":hId": accountId
            }
        }));

        console.log("response:", response);

        // Return the current status (Whether PENDING or ACTIVE along with the port)
        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                games: response.Items
            })
        };

    } catch (error) {
        return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
    }
};