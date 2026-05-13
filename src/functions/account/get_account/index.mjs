import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";

const ACCOUNTS_TABLE = process.env.ACCOUNTS_TABLE;

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    if (!accountId) {
        return {
            statusCode: 400,
            body: JSON.stringify({ message: "Missing AccountId parameter" }),
        };
    }

    const params = {
        TableName: ACCOUNTS_TABLE,
        KeyConditionExpression: "AccountId = :accId",
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
            console.log("null account, creating record")
            const newAccount = {
                AccountId: accountId,
                PlayerName: accountId,
                CreateTimeEpochMilliseconds: Date.now(),
                ProfilePictureUrl: "",
                HandsWon: 0,
                HandsPlayed: 0
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