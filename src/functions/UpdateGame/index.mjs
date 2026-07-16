import { DynamoDBDocumentClient, UpdateCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";
import Enums from "./shared/enums.json" with { type: "json" };

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const GAMES_TABLE = process.env.GAMES_TABLE;
const SERVER_SECRET_TOKEN = process.env.SERVER_SECRET_TOKEN;

export const handler = async (event) => {
    if (!event.body) {
        return {
            statusCode: 400,
            body: JSON.stringify({ message: "Missing request body" })
        }; 
    }

    if (!SERVER_SECRET_TOKEN || !GAMES_TABLE) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Server configuration error" })
        };
    }

    const gameId = event.queryStringParameters?.gameId;
    const body = JSON.parse(event.body)
    const newGameStatus = body.gameStatus;
    const newPort = body.port
    const addPlayers = body.addPlayers;
    const removePlayers = body.removePlayers;
    var hostPlayerId = "";
    var updateParams;

    console.log("GAME ID:", gameId);
    console.log("body:", body);

    // TODO: update logic to migrate to a new dynamo record if trying to change hosts
    // Maybe best to just create a new endpoint for this...
    // const hostPlayerId = body.hostPlayerId;

    try {
        const response = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            KeyConditionExpression: "gameId = :gId",
            ExpressionAttributeValues: {
                ":gId": gameId
            }
        }));

        const game = response.Items?.[0] ?? null;

        if (!game) {
            return { statusCode: 404, body: JSON.stringify({ message: "Game session not found" }) };
        }

        hostPlayerId = game.hostPlayerId;
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to fetch game record", error: error.message })
        };
    }

    // Add all of our update values
    let updateExpressions = []
    let updateValues = {}

    if (newGameStatus) {
        if (newGameStatus == Enums.GameStatus.STARTED) {
            updateExpressions.push("gameStatus = :statusValue");
            updateValues[":statusValue"] = newGameStatus;
        } else if (newGameStatus == Enums.GameStatus.ENDED) {
            updateExpressions.push("gameStatus = :statusValue, endTimeEpochMilliseconds = :endTimeValue");
            updateValues[":statusValue"] = newGameStatus;
            updateValues[":endTimeValue"] = Date.now();
        } else {
            return {
                statusCode: 403,
                body: JSON.stringify({ message: "Unmapped gameStatus value" })
            };
        }
    }

    if (newPort) {
        updateExpressions.push("port = :newPort");
        updateValues[":newPort"] = newPort;
    }

    if (addPlayers && addPlayers.length > 0) {
        const currentPlayers = game.connectedPlayers;
        addPlayers.forEach((playerId) => {
            currentPlayers.push(playerId);
        });

        updateExpressions.push("connectedPlayers = :connectedPlayers");
        updateValues[":connectedPlayers"] = currentPlayers
    }

    if (removePlayers && removePlayers.length > 0) {
        // get players, find player id, remove from list, update
        // ignore id if player doesn't exist in game list
        const playersList = []
        addPlayers.forEach((playerId) => {
            game.connectedPlayers.forEach((currentPlayerId) => {
                if (currentPlayerId != playerId) {
                    playersList.push(currentPlayerId);
                }
            })
        });

        updateExpressions.push("connectedPlayers = :connectedPlayers");
        updateValues[":connectedPlayers"] = playersList
    }

    updateParams = {
        TableName: GAMES_TABLE,
        Key: {
            gameId: gameId,
            hostPlayerId: hostPlayerId
        },
        UpdateExpression: "SET " + updateExpressions.join(", "),
        ExpressionAttributeValues: updateValues,
        ReturnValues: "ALL_NEW"
    };

    try {
        const response = await docClient.send(new UpdateCommand(updateParams));
        console.log("[Lambda] Game record updated successfully.");
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: "Game updated successfully", attributes: response.Attributes })
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to update game record", error: error.message })
        };
    }
};