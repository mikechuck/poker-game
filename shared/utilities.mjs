import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const AccountRecord = pokerApiProto.lookupType("poker_api.AccountRecord");
const FriendRecordList = pokerApiProto.lookupType("poker_api.FriendRecordList");

// Note: we pass in table name because not all lambdas (i.e edge auth) have env variables available,
// and I want to keep all table names terraform-authoritative

// Helper utility to query game record from dynamo table
export const GetGameRecord = async (gameId, gamesTableName, docClient) => {
    try {
        const gameQueryResponse = await docClient.send(new QueryCommand({
            TableName: gamesTableName,
            KeyConditionExpression: "gameId = :gId",
            ExpressionAttributeValues: {
                ":gId": gameId
            },
            ConsistentRead: true
        }));
    
        const game = gameQueryResponse.Items?.[0] ?? null;
    
        if (GameRecord.verify(game) == null) {
            return GameRecord.create(game);
        } else {
            console.error("Invalid game record:", GameRecord.verify(game))
        }

    } catch (error) {
        console.error("Invernal server error:", error);
    }
}

export const GetFriendsList = async (accountId, friendsTableName, docClient) => {
    try {
        const friendsQueryResponse = await docClient.send(new QueryCommand({
            TableName: friendsTableName,
            KeyConditionExpression: "accountId = :aId",
            ExpressionAttributeValues: {
                ":aId": accountId
            }
        }));
    
        return FriendRecordList.create({
            friends: friendsQueryResponse.Items ?? []
        });
    } catch (error) {
        console.error("Invernal server error:", error);
    }
}

export const IsFriendsWithPlayer = async (accountId, peerAcountId, friendsTableName, docClient) => {
    try {
        const friendsQueryResponse = await docClient.send(new QueryCommand({
            TableName: friendsTableName,
            IndexName: "PeerAccountIdIndex", 
            KeyConditionExpression: "accountId = :accId AND peerAccountId = :peerId",
            ExpressionAttributeValues: {
                ":accId": accountId,
                ":peerId": peerAcountId,
            }
        }));

        return friendsQueryResponse.Items.length > 0;
    } catch (error) {
        console.error("Invernal server error:", error);
        return false;
    }
}

export const GetAccount = async (accountId, accountsTableName, docClient) => {
    try {
        const accountQueryResponse = await docClient.send(new QueryCommand({
            TableName: accountsTableName,
            KeyConditionExpression: "accountId = :aId",
            ExpressionAttributeValues: {
                ":aId": accountId
            }
        }));

        const account = accountQueryResponse.Items?.[0] ?? null;

        if (AccountRecord.verify(account) == null) {
            return AccountRecord.create(account);
        } else {
            console.error("Invalid account record:", AccountRecord.verify(account))
        }
    } catch (error) {
        console.error("Invernal server error:", error);
    }
}

export const GetAccountByFriendCode = async (friendCode, accountsTableName, docClient) => {
    try {
        const params = {
            TableName: accountsTableName,
            IndexName: "FriendCodeIndex", 
            KeyConditionExpression: "friendCode = :fCode",
            ExpressionAttributeValues: {
                ":fCode": friendCode,
            }
        };
        const command = new QueryCommand(params);
        const response = await docClient.send(command);
        return response?.Items?.[0] ?? null;
    } catch (error) {
        console.error("Invernal server error:", error);
    }
}