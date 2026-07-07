import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import Enums from "./shared/enums.json" with { type: "json" };

const ACCOUNTS_TABLE = process.env.ACCOUNTS_TABLE;

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;
    const username = event.requestContext?.authorizer?.jwt?.claims["cognito:username"];

    if (!accountId) {
        return {
            statusCode: 400,
            body: JSON.stringify({ message: "Missing AccountId parameter" }),
        };
    }

    const params = {
        TableName: ACCOUNTS_TABLE,
        KeyConditionExpression: "accountId = :accId",
        ExpressionAttributeValues: {
            ":accId": accountId
        }
    };

    try {
        const command = new QueryCommand(params);
        const response = await docClient.send(command);

        let account = response?.Items?.[0] ?? null;

        // Account not found, create one with initial values
        if (account == null) {
            const newAccount = {
                accountId: accountId,
                playerName: username,
                createTimeEpochMilliseconds: Date.now(),
                profilePictureUrl: "",
                handsWon: 0,
                handsPlayed: 0,
                playerColor: "#ff8407"
            };

            await docClient.send(new PutCommand({
                TableName: ACCOUNTS_TABLE,
                Item: newAccount
            }));

            // Set the response.Item to the new record for the return statement
            account = newAccount;
        } else {
            console.log("not null account, returning found account")
        }

        return {
            statusCode: 200,
            body: JSON.stringify(account),
        };
    } catch (error) {
        console.error("DynamoDB Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Internal Server Error", error: error.message }),
        };
    }
};