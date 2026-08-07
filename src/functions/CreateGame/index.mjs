import { SSMClient, SendCommandCommand, GetCommandInvocationCommand } from "@aws-sdk/client-ssm";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ssm = new SSMClient();
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameStatus = pokerApiProto.lookupType("poker_api.GameStatus");
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const GamePrivacy = pokerApiProto.lookupType("poker_api.GamePrivacy");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const INSTANCE_ID = process.env.POKER_SERVER_INSTANCE_ID;
const GAMES_TABLE = process.env.GAMES_TABLE;

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

    const body = JSON.parse(event.body)
    const blindValue = body.blind || 10
    const buyIn = body.buyIn || 0 // 0 is free game
    const chipRatio = body.chipRatio || 1
    const gamePrivacy = body.gamePrivacy || GamePrivacy.PUBLIC
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    if (!accountId) {
        return {
            statusCode: 401,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Unauthorized" 
                })
            )
        };
    }

    if (!INSTANCE_ID || !GAMES_TABLE) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Server configuration error"
                })
            )
        };
    }

    // Get all active games for this player
    const params = {
        TableName: GAMES_TABLE,
        IndexName: "HostPlayerIdIndex", 
        KeyConditionExpression: "hostPlayerId = :accId",
        FilterExpression: "gameStatus <> :endedStatus",
        ExpressionAttributeValues: {
            ":accId": accountId,
            ":endedStatus": GameStatus.ENDED
        }
    };

    try {
        const command = new QueryCommand(params);
        const response = await docClient.send(command);
        let existingGame = response?.Items?.[0] ?? null;

        if (existingGame) {  
            return {
                statusCode: 200,
                body: JSON.stringify(GameRecord.create(existingGame))
            }
        }

        // Create game code
        var gameCode = "";
        var gameCodeLength = 7;
        var gameCodeChars = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ";

        for (let i = 0; i < gameCodeLength; i++) {
            gameCode += gameCodeChars[Math.floor(Math.random() * gameCodeChars.length)];
        }

        const newGameData = {
            gameId: gameCode,
            hostPlayerId: accountId,
            createTimeEpochMilliseconds: Date.now(),
            gameStatus: GameStatus.STARTING,
            endTimeEpochMilliseconds: 0,
            connectedPlayers: [],
            port: 0,
            blind: blindValue,
            buyInDollars: buyIn,
            chipRatio: chipRatio,
            handsPlayed: 0,
            gamePrivacy: gamePrivacy
        };

        const errMsg = GameRecord.verify(payload);
        if (errMsg) {
            return {
                statusCode: 500,
                body: JSON.stringify(
                    ErrorResponse.create({ 
                        message: "Server configuration error",
                        error: errMsg 
                    })
                )
            };
        }

        const newGameRecord = GameRecord.create(newGameData);

        await docClient.send(new PutCommand({
            TableName: GAMES_TABLE,
            Item: newGameRecord
        }));

        // Send the command to run our start game script
        const sendRes = await ssm.send(new SendCommandCommand({
            InstanceIds: [INSTANCE_ID],
            DocumentName: "AWS-RunShellScript",
            Parameters: {
                'commands': [`sudo -u ec2-user /home/ec2-user/start_game_session.sh "${GAMES_TABLE}" "${newGame.gameId}" "${accountId}" "${blindValue}"`]
            },
            CloudWatchOutputConfig: {
                CloudWatchLogGroupName: "/apps/poker-game",
                CloudWatchOutputEnabled: true
            }
        }));

        return {
            statusCode: 202,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(newGameRecord)
        };
    } catch (error) {
        console.error("SSM Execution Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Failed to spin up game server session",
                    error: error.message 
                })
            )
        };
    }
};