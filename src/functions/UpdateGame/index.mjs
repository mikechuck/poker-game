import { DynamoDBDocumentClient, UpdateCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameStatus = pokerApiProto.lookupEnum("poker_api.GameStatus");
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

    if (!SERVER_SECRET_TOKEN) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Server configuration error"
                })
            )
        };
    }

    const gameId = event.pathParameters?.gameId;
    const body = JSON.parse(event.body)
    const newGameStatus = body.gameStatus;
    const newPort = body.port
    const addPlayers = body.addPlayers;
    const removePlayers = body.removePlayers;
    var hostAccountId = "";
    var updateParams;
    var game;
    var gameRecordRaw;

    // TODO: update logic to migrate to a new dynamo record if trying to change hosts
    // Maybe best to just create a new endpoint for this...
    // const hostAccountId = body.hostAccountId;

    try {
        gameRecordRaw = await GetGameRecord(gameId, GAMES_TABLE);
        if (!gameRecordRaw) {
            return {
                statusCode: 400,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: "Invalid gameId" 
                    })
                )
            };
        }
        hostAccountId = gameRecordRaw.hostAccountId;
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

    const gameRecord = GameRecord.toObject(gameRecordRaw, {
        enums: Number,
        longs: Number,
        defaults: true
    });

    // Add all of our update values
    let updateExpressions = []
    let updateValues = {}

    if (newGameStatus) {
        if (newGameStatus == GameStatus.values.ACTIVE) {
            updateExpressions.push("gameStatus = :statusValue");
            updateValues[":statusValue"] = newGameStatus;
        } else if (newGameStatus == GameStatus.values.ENDED) {
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

    let playersChanged = false;
    let currentPlayers = gameRecord.connectedPlayers || [];

    if (Array.isArray(addPlayers) && addPlayers.length > 0) {
        const playerSet = new Set(currentPlayers);
        addPlayers.forEach(id => playerSet.add(id));
        currentPlayers = Array.from(playerSet);
        playersChanged = true;
    }

    if (Array.isArray(removePlayers) && removePlayers.length > 0) {
        const playersToRemove = new Set(removePlayers);
        currentPlayers = currentPlayers.filter(id => !playersToRemove.has(id));
        playersChanged = true;
    }

    if (playersChanged) {
        updateExpressions.push("connectedPlayers = :connectedPlayers");
        updateValues[":connectedPlayers"] = currentPlayers;
    }

    if (updateExpressions.length === 0) {
        return {
            statusCode: 200,
            body: JSON.stringify(GameRecord.toObject(gameRecordRaw, { 
                enums: Number,
                defaults: true
            }))
        };
    }

    updateParams = {
        TableName: GAMES_TABLE,
        Key: {
            gameId: gameId,
            hostAccountId: hostAccountId
        },
        UpdateExpression: "SET " + updateExpressions.join(", "),
        ExpressionAttributeValues: updateValues,
        ReturnValues: "ALL_NEW"
    };

    try {
        const response = await docClient.send(new UpdateCommand(updateParams));
        const gameRecord = GameRecord.create(response.Attributes);
        console.log("[Lambda] Game record updated successfully.");
        
        return {
            statusCode: 200,
            body: JSON.stringify(GameRecord.toObject(gameRecord, {
                enums: Number,
                defaults: true
            }))
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