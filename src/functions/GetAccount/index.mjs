import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ACCOUNTS_TABLE = process.env.ACCOUNTS_TABLE;

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const AccountRecord = pokerApiProto.lookupType("poker_api.AccountRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;
    const username = event.requestContext?.authorizer?.jwt?.claims["cognito:username"];

    if (!accountId) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing AccountId parameter"
                })
            )
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
        let accountRecord;

        // Account not found, create one with initial values
        if (account == null) {
            accountRecord = AccountRecord.create({
                accountId: accountId,
                playerName: username,
                createTimeEpochMilliseconds: Date.now(),
                profilePictureUrl: "",
                handsWon: 0,
                handsPlayed: 0,
                playerColor: "#ff8407"
            });

            await docClient.send(new PutCommand({
                TableName: ACCOUNTS_TABLE,
                Item: newAccount
            }));
        } else {
            accountRecord = AccountRecord.create(account);
        }

        return {
            statusCode: 200,
            body: JSON.stringify(accountRecord),
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({ 
                    message: "Internal Server Error", 
                    error: error.message 
                })
            )
        };
    }
};