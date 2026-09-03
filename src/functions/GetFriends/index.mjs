import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");
const RelationshipRecordList = pokerApiProto.lookupType("poker_api.RelationshipRecordList");

const RELATIONSHIPS_TABLE = process.env.RELATIONSHIPS_TABLE;

export const handler = async (event) => {
    const accountId = event.requestContext?.authorizer?.jwt?.claims?.sub;

    try {
        const queryResponse = await docClient.send(new QueryCommand({
            TableName: RELATIONSHIPS_TABLE,
            KeyConditionExpression: "accountId = :aId",
            ExpressionAttributeValues: {
                ":aId": accountId
            }
        }));

        console.log("queryResponse:", queryResponse);

        const relationshipRecordList = RelationshipRecordList.create({
            relationships: queryResponse.Items
        })

        const relationshipRecordListObject = RelationshipRecordList.toObject(relationshipRecordList, {
            enums: Number,
            defaults: true
        });

        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(relationshipRecordListObject)
        };

    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Internal server error",
                    error: error
                })
            )
        };
    }
};