import { DynamoDBDocumentClient, UpdateCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameStatus = pokerApiProto.lookupType("poker_api.GameStatus");
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;
const SERVER_SECRET_TOKEN = process.env.SERVER_SECRET_TOKEN;

export const handler = async (event) => {
    if (!event.body) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing request body"
                })
            )
        }; 
    }

    if (!SERVER_SECRET_TOKEN || !GAMES_TABLE) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Server configuration error"
                })
            )
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
    var game;
    var gameRecord;

    // TODO: update logic to migrate to a new dynamo record if trying to change hosts
    // Maybe best to just create a new endpoint for this...
    // const hostPlayerId = body.hostPlayerId;

    try {
        const queryResponse = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            KeyConditionExpression: "gameId = :gId",
            ExpressionAttributeValues: {
                ":gId": gameId
            }
        }));

        game = queryResponse.Items?.[0] ?? null;

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

        gameRecord = GameRecord.create(game);
        hostPlayerId = gameRecord.hostPlayerId;
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Failed to fetch game record",
                    error: error.message
                })
            )
        };
    }

    // Add all of our update values
    let updateExpressions = []
    let updateValues = {}

    if (newGameStatus) {
        if (newGameStatus == GameStatus.STARTED) {
            updateExpressions.push("gameStatus = :statusValue");
            updateValues[":statusValue"] = newGameStatus;
        } else if (newGameStatus == GameStatus.ENDED) {
            updateExpressions.push("gameStatus = :statusValue, endTimeEpochMilliseconds = :endTimeValue");
            updateValues[":statusValue"] = newGameStatus;
            updateValues[":endTimeValue"] = Date.now();
        } else {
            return {
                statusCode: 403,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: "Unmapped gameStatus value"
                    })
                )
            };
        }
    }

    if (newPort) {
        updateExpressions.push("port = :newPort");
        updateValues[":newPort"] = newPort;
    }

    if (addPlayers && addPlayers.length > 0) {
        const currentPlayers = gameRecord.connectedPlayers;
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
            gameRecord.connectedPlayers.forEach((currentPlayerId) => {
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
            body: JSON.stringify(GameRecord.create(response.Attributes))
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Failed to update game record",
                    error: error.message
                })
            )
        };
    }
};