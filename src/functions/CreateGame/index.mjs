import { SSMClient, SendCommandCommand, GetCommandInvocationCommand } from "@aws-sdk/client-ssm";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";

const ssm = new SSMClient();
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const INSTANCE_ID = process.env.POKER_SERVER_INSTANCE_ID;
const GAMES_TABLE = process.env.GAMES_TABLE;

export const handler = async (event) => {
    if (!event.body) {
        return {
            statusCode: 400,
            body: JSON.stringify({ message: "Missing request body" })
        }; 
    }

    const body = JSON.parse(event.body)
    const blindValue = body.blind || 10
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    if (!accountId) {
        return {
            statusCode: 401,
            body: JSON.stringify({ message: "Unauthorized" })
        };
    }

    if (!INSTANCE_ID || !GAMES_TABLE) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Server configuration error" })
        };
    }

    // Get all active games for this player
    const params = {
        TableName: GAMES_TABLE,
        IndexName: "HostPlayerIdIndex",
        KeyConditionExpression: "HostPlayerId = :accId AND EndTimeEpochMilliseconds > :targetTime",
        ExpressionAttributeValues: {
            ":accId": accountId,
            ":targetTime": Date.now()
        }
    };

    try {
        const command = new QueryCommand(params);
        const response = await docClient.send(command);
        let game = response?.Items?.[0] ?? null;

        if (game) {  
            return {
                statusCode: 200,
                body: JSON.stringify(game)
            }
        }

        const newGame = {
            GameId: crypto.randomUUID(),
            HostPlayerId: accountId,
            CreateTimeEpochMilliseconds: Date.now(),
            Port: 0,
            GameStatus: "STARTING",
            EndTimeEpochMilliseconds: Date.now() + 3600000, // 1 hour limit for game
            Blind: blindValue
        };

        await docClient.send(new PutCommand({
            TableName: GAMES_TABLE,
            Item: newGame
        }));

        // Send the command to run our start game script
        const sendRes = await ssm.send(new SendCommandCommand({
            InstanceIds: [INSTANCE_ID],
            DocumentName: "AWS-RunShellScript",
            Parameters: {
                'commands': [`sudo -i -u ec2-user /home/ec2-user/start_game_session.sh "${GAMES_TABLE}" "${newGame.GameId}" "${accountId}" "${blindValue}"`]
            }
        }));

        return {
            statusCode: 202,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ 
                message: "Game server configuration initialization started", 
                gameId: newGame.GameId
            })
        };
    } catch (error) {
        console.error("SSM Execution Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to spin up game server session", error: error.message })
        };
    }
};