import { SSMClient, SendCommandCommand } from "@aws-sdk/client-ssm";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ssm = new SSMClient();
const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameStatus = pokerApiProto.lookupEnum("poker_api.GameStatus");
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const GamePrivacy = pokerApiProto.lookupEnum("poker_api.GamePrivacy");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const INSTANCE_ID = process.env.POKER_SERVER_INSTANCE_ID;
const GAMES_TABLE = process.env.GAMES_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

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

    const body = JSON.parse(event.body)
    const blindChips = body.blind || 10
    const buyInChips = body.buyInChips || 100
    const chipRatio = body.chipRatio || 0 // 0 is a free game
    const gamePrivacy = body.gamePrivacy || GamePrivacy.values.PUBLIC

    // Get all active games for this player
    const params = {
        TableName: GAMES_TABLE,
        IndexName: "HostAccountIdIndex", 
        KeyConditionExpression: "hostAccountId = :accId",
        FilterExpression: "gameStatus <> :endedStatus",
        ExpressionAttributeValues: {
            ":accId": accountId,
            ":endedStatus": GameStatus.values.ENDED
        }
    };

    try {
        const command = new QueryCommand(params);
        const response = await docClient.send(command);
        let existingGame = response?.Items?.[0] ?? null;

        if (existingGame) {
            return {
                statusCode: 200,
                body: JSON.stringify(GameRecord.toObject(GameRecord.create(existingGame), {
                    enums: Number,
                    defaults: true
                }))
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
            hostAccountId: accountId,
            createTimeEpochMilliseconds: Date.now(),
            gameStatus: GameStatus.values.STARTING,
            endTimeEpochMilliseconds: 0,
            connectedPlayers: [],
            port: 0,
            blind: blindChips,
            buyInChips: buyInChips,
            chipRatio: chipRatio,
            handsPlayed: 0,
            gamePrivacy: gamePrivacy
        };

        const errMsg = GameRecord.verify(newGameData);
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
        const newGameRecordObject = GameRecord.toObject(newGameRecord, {
            enums: Number,
            defaults: true
        });

        await docClient.send(new PutCommand({
            TableName: GAMES_TABLE,
            Item: newGameRecord
        }));

        // Send the command to run our start game script
        const sendRes = await ssm.send(new SendCommandCommand({
            InstanceIds: [INSTANCE_ID],
            DocumentName: "AWS-RunShellScript",
            Parameters: {
                'commands': [`sudo -u ec2-user /home/ec2-user/start_game_session.sh "${GAMES_TABLE}" "${newGameRecord.gameId}" "${accountId}" "${blindChips}"`]
            },
            CloudWatchOutputConfig: {
                CloudWatchLogGroupName: "/apps/poker-game",
                CloudWatchOutputEnabled: true
            }
        }));

        console.log("SSM sendRes:", sendRes)

        return {
            statusCode: 202,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(newGameRecordObject)
        };
    } catch (error) {
        console.error("SSM Execution Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Failed to spin up game server session",
                    error: error 
                })
            )
        };
    }
};