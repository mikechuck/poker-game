import { SSMClient, SendCommandCommand, GetCommandInvocationCommand } from "@aws-sdk/client-ssm";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";

const ssm = new SSMClient();
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const INSTANCE_ID = process.env.POKER_SERVER_INSTANCE_ID;
const GAMES_TABLE = process.env.GAMES_TABLE;

/*
Validate:
    - check to see if user has game record active, if so return connection info for it
    - if not, continue
Create:
    - call SSM to start server
    - when getting port back from log, create record for host_account_id, 
*/

export const handler = async (event) => {
    // Game params -  figure out what we want for these
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

        console.log("Sending SSM command...");

        // Send the command to run our helper script
        const sendRes = await ssm.send(new SendCommandCommand({
            InstanceIds: [INSTANCE_ID],
            DocumentName: "AWS-RunShellScript",
            Parameters: {
                'commands': [`/home/ec2-user/start_game_session.sh --blind=${blindValue}`]
            }
        }));
    
        const commandId = sendRes.Command.CommandId;

        let output;
        let attempts = 0;
        const maxAttempts = 25;

        while (attempts < maxAttempts) {
            // Wait exactly 1 second between updates
            await new Promise(resolve => setTimeout(resolve, 1000));
            attempts++;

            console.log(`Polling SSM Command status (Attempt ${attempts}/${maxAttempts})...`);

            output = await ssm.send(new GetCommandInvocationCommand({
                CommandId: commandId,
                InstanceId: INSTANCE_ID
            }));

            // If the code loop sees a status transition away from In Progress / Pending, break out immediately!
            if (output.Status !== "InProgress" && output.Status !== "Pending") {
                console.log(`SSM Command completed with status: ${output.Status}`);
                break;
            }
        }

        console.log("Final SSM command output metadata:", output);

        if (output.ResponseCode !== 0) {
            console.error("Error creating game instance or command timed out. Exit Status:", output.Status);
            console.error("Standard Error Payload:", output.StandardErrorContent);
            return {
                statusCode: 500,
                body: JSON.stringify({ message: "Internal server error starting instance" })
            };
        }

        const assignedPort = output.StandardOutputContent.trim();

        const newGame = {
            GameId: crypto.randomUUID(),
            HostPlayerId: accountId,
            CreateTimeEpochMilliseconds: Date.now(),
            Port: assignedPort,
            EndTimeEpochMilliseconds: Date.now() + 30000, // 30s from now
            Blind: blindValue
        };

        await docClient.send(new PutCommand({
            TableName: GAMES_TABLE,
            Item: newGame
        }));

        return {
            statusCode: 201,
            body: JSON.stringify(newGame)
        }
    } catch (error) {
        console.error("SSM Execution Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to spin up game server session", error: error.message })
        };
    }
};