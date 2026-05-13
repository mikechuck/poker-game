const { SSMClient, SendCommandCommand, GetCommandInvocationCommand } = require("@aws-sdk/client-ssm");
const ssm = new SSMClient();

exports.handler = async (event) => {
    // Game params -  figure out what we want for these
    const body = JSON.parse(event.body)
    const blindValue = body.blind || 10

    // TODO: get this id dynamically. Assign the ec2 instance a name on creation and query the id for that name
    const instanceId = "i-08000c779b501a6aa"; // Your waiting EC2

    // Send the command to run our helper script
    const sendRes = await ssm.send(new SendCommandCommand({
        InstanceIds: [instanceId],
        DocumentName: "AWS-RunShellScript",
        Parameters: {
            'commands': [`/home/ec2-user/start_game_session.sh --blind=${blindValue}`]
        }
    }));

    const commandId = sendRes.Command.CommandId;

    // Wait a moment for the script to finish and return the output
    // In a real app, you might loop/poll this for 2-3 seconds
    await new Promise(resolve => setTimeout(resolve, 2000));

    const output = await ssm.send(new GetCommandInvocationCommand({
        CommandId: commandId,
        InstanceId: instanceId
    }));

    const assignedPort = output.StandardOutputContent.trim();
    
    return {
        statusCode: 200,
        body: JSON.stringify({ port: assignedPort })
    };
};