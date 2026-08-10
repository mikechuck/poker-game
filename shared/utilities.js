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


// Helper utility to query game record from dynamo table
export const GetGameRecord = async (gameId, games_table_name) => {
    try {
        const gameQueryResponse = await docClient.send(new QueryCommand({
            TableName: games_table_name,
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
                        message: "Game not found"
                    })
                )
            };
        }
    
        var gameRecord = GameRecord.create(game)
        
        if (gameRecord.gameStatus != GameRecord.STARTED) {
            return {
                statusCode: 404,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: "Game not found"
                    })
                )
            };
        }
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
}