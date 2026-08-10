import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const GameRecordList = pokerApiProto.lookupType("poker_api.GameRecordList");

const GAMES_TABLE = process.env.GAMES_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    try {
        const queryResponse = await docClient.send(new QueryCommand({
            TableName: GAMES_TABLE,
            IndexName: "HostAccountIdIndex", 
            KeyConditionExpression: "hostAccountId = :hId",
            ExpressionAttributeValues: {
                ":hId": accountId
            }
        }));

        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(
                GameRecordList.create({
                    records: queryResponse.Items
                })
            )
        };

    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Internal server error",
                    error: error.message
                })
            )
        };
    }
};