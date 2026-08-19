import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ACCOUNTS_TABLE = process.env.ACCOUNTS_TABLE;

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const AccountRecord = pokerApiProto.lookupType("poker_api.AccountRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

export const handler = async (event) => {
    let accountId = ""
    let username = ""

    // If invoked from server
    if (event.pathParameters?.accountId) {
        accountId = event.pathParameters.accountId;
    } 
    // If invoked from client
    else if (event.requestContext?.authorizer?.jwt?.claims?.sub) {
        accountId = event.requestContext.authorizer.jwt.claims.sub;
        username = event.requestContext?.authorizer?.jwt?.claims["cognito:username"];
    }

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

        var friendCode = "";
        var friendCodeLength = 7;
        var friendCodeChars = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ";

        for (let i = 0; i < friendCodeLength; i++) {
            friendCode += friendCodeChars[Math.floor(Math.random() * friendCodeChars.length)];
        }

        const colorOptions = ["#227C9D", "#17C3B2", "#FFCB77", "#FEF9EF", "#FE6D73"];
        const newPlayerColor = colorOptions[Math.random(0, 4)];

        // Account not found, create one with initial values if we have sub data
        if (account == null) {
            if (username == "") {
                return {
                    statusCode: 404,
                    body: JSON.stringify(
                        ErrorResponse.create({ 
                            message: "Account not found", 
                            error: error.message 
                        })
                    )
                };
            }

            accountRecord = AccountRecord.create({
                accountId: accountId,
                playerName: username,
                createTimeEpochMilliseconds: Date.now(),
                profilePictureUrl: "",
                handsWon: 0,
                handsPlayed: 0,
                playerColor: "#ff8407",
                friendCode: friendCode
            });

            await docClient.send(new PutCommand({
                TableName: ACCOUNTS_TABLE,
                Item: accountRecord
            }));
        } else {
            accountRecord = AccountRecord.create(account);
        }

        const accountRecordObject = AccountRecord.toObject(accountRecord, {
            enums: Number,
            defaults: true
        });

        return {
            statusCode: 200,
            body: JSON.stringify(accountRecordObject),
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