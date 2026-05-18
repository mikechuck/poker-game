const { SSMClient, SendCommandCommand, GetCommandInvocationCommand } = require("@aws-sdk/client-ssm");
const ssm = new SSMClient();

exports.handler = async (event) => {
    // Game params -  figure out what we want for these
    const body = JSON.parse(event.body)
    const blindValue = body.blind || 10

    const INSTANCE_ID = process.env.POKER_SERVER_INSTANCE_ID;

    if (!INSTANCE_ID) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Server configuration error: Missing Instance ID" })
        };
    }

    try {

        // Send the command to run our helper script
        const sendRes = await ssm.send(new SendCommandCommand({
            InstanceIds: [INSTANCE_ID],
            DocumentName: "AWS-RunShellScript",
            Parameters: {
                'commands': [`/home/ec2-user/start_game_session.sh --blind=${blindValue}`]
            }
        }));
    
        const commandId = sendRes.Command.CommandId;
    
        // Wait a moment for the script to finish and return the output
        // In a real app, you might loop/poll this for 2-3 seconds
        await new Promise(resolve => setTimeout(resolve, 2500));
    
        const output = await ssm.send(new GetCommandInvocationCommand({
            CommandId: commandId,
            InstanceId: INSTANCE_ID
        }));
    
        const assignedPort = output.StandardOutputContent.trim();
        
        return {
            statusCode: 200,
            body: JSON.stringify({ port: assignedPort })
        };
    } catch (error) {
        console.error("SSM Execution Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to spin up game server session", error: error.message })
        };
    }
};