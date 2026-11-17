import { describe, it, mock } from "node:test";
import assert from "node:assert/strict";
import { createHandler } from "../src/handler.mjs";
import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBDocumentClient, GetCommand, QueryCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const dynamoClientMock = mockClient(DynamoDBDocumentClient);

const gamesTableName = "Games"
const defaultGameRecord = {
    gameId: "ABCDEFG",
    hostAccountId: "b50b618c-4929-48fb-92b3-20f2697bf6ad",
    hostName: "testUser1234567",
    gameStatus: 1, // active
    createTimeEpochMilliseconds: Date.now(),
    endTimeEpochMilliseconds: Date.now(),
    port: "1234",
    blindChips: 50,
    buyInChips: 1000,
    buyInCash: 20,
    handsPlayed: 2,
    gamePrivacy: 0,
    connectedPlayers: [] 
}

describe("CalculateDebts Lambd Handler", () => {
    it("calculates the correct debts based on game ledgers", async () => {
        // to mock:
        // get game record that's active
        dynamoClientMock
            .on(QueryCommand, {
                TableName: gamesTableName
            })
            .resolves({
                Items: [defaultGameRecord]
            })
        // get list of game ledgers, with custom chip values etc
        // create debt records
    })
})