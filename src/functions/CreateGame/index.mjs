import { SSMClient, SendCommandCommand, GetCommandInvocationCommand } from "@aws-sdk/client-ssm";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

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
    const body = JSON.parse(event.body)
    const blindValue = body.blind || 10
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    if (!accountId)
    {
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

    const params = {
        TableName: GAMES_TABLE,
        KeyConditionExpression: "HostPlayerId = :accId",
        ExpressionAttributeValues: {
            ":accId": accountId
        }
    };

    try {

        const command = new QueryCommand(params);
        const response = await docClient.send(command);
        let game = response?.Items?.[0] ?? null;

        if (game)
        {  
            return {
                statusCode: 200,
                body: JSON.stringify(game)
            }
        } else {
            const newGame = {
                GameId: "78372894728394",
                HostPlayerId: accountId,
                CreateTimeEpochMilliseconds: Date.now(),
                Port: 12001,
                EndTimeEpochMilliseconds: Date.now() + 3600000 // 1 hour from now
            };

            await docClient.send(new PutCommand({
                TableName: GAMES_TABLE,
                Item: newGame
            }));

            return {
                statusCode: 201,
                body: JSON.stringify(newGame)
            }
        }

        // Send the command to run our helper script
        // const sendRes = await ssm.send(new SendCommandCommand({
        //     InstanceIds: [INSTANCE_ID],
        //     DocumentName: "AWS-RunShellScript",
        //     Parameters: {
        //         'commands': [`/home/ec2-user/start_game_session.sh --blind=${blindValue}`]
        //     }
        // }));
    
        // const commandId = sendRes.Command.CommandId;
    
        // // Wait a moment for the script to finish and return the output
        // // In a real app, you might loop/poll this for 2-3 seconds
        // await new Promise(resolve => setTimeout(resolve, 2500));
    
        // const output = await ssm.send(new GetCommandInvocationCommand({
        //     CommandId: commandId,
        //     InstanceId: INSTANCE_ID
        // }));
    
        // const assignedPort = output.StandardOutputContent.trim();
        
        // return {
        //     statusCode: 200,
        //     body: JSON.stringify({ port: assignedPort })
        // };
    } catch (error) {
        console.error("SSM Execution Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to spin up game server session", error: error.message })
        };
    }
};