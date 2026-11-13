import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";
import { DynamoDBDocumentClient, QueryCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const DebtRecord = pokerApiProto.lookupType("poker_api.DebtRecord")
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;
const GAMES_LEDGER_TABLE = process.env.GAMES_LEDGER_TABLE;
const DEBTS_TABLE = process.env.DEBTS_TABLE;

export const handler = async (event) => {
    const gameId = event.pathParameters?.gameId;

    if (!gameId) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Missing gameId parameter" 
                })
            )
        };
    }

    const gameRecord = await GetGameRecord(gameId, GAMES_TABLE);
    
    if (gameRecord == null) {
        return {
            statusCode: 400,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: "Invalid gameId" 
                })
            )
        };
    }

    // Get all GameLedger records for this game
    const gameLedgersQueryResponse = await docClient.send(new QueryCommand({
        TableName: GAMES_LEDGER_TABLE,
        KeyConditionExpression: "gameId = :gId",
        ExpressionAttributeValues: {
            ":gId": gameId
        },
        ConsistentRead: true
    }));

    if (!gameLedgersQueryResponse.Items?.length == 0) {
        return {
            statusCode: 200,
            body: "No debts to create for this game"
        };
    }
    
    var gameLedgers = gameLedgersQueryResponse.Items;
    gameLedgers.sort((a, b) => b["cashOutChips"] - a["cashOutChips"])
    // var lowestToHighestLedgers = [...gameLedgers].sort((a, b) => a["cashOutChips"] - b["cashOutChips"])

    while (gameLedgers.length > 0) {
        var highestChipsLedger = gameLedgers.shift(); // Pops out the first item in the array
        var creditorChips = highestChipsLedger.cashOutChips;
        var creditorAccountId = highestChipsLedger.accountId
        var debtorTotalChips = 0;

        for (let i = gameLedgers.length - 1; i >= 0; i--) {

            var debtorLedger = gameLedgers[i];
            var debtorAccountId = debtorLedger.accountId;
            var debtorChipsOwed = debtorLedger.buyInChips - debtorLedger.cashOutChips; // total amount of chips the player owes
            var creditorChipsLeftToCalc = creditorChips - debtorTotalChips;

            if (debtorChipsOwed == creditorChipsLeftToCalc) {
                gameLedgers.splice(i, 1);

                try {
                    await createDebtRecordForPlayers(
                        creditorAccountId,
                        debtorAccountId,
                        debtorChipsOwed,
                        gameId
                    )
                } catch (error) {
                    console.error(`Internal server error. Failed to create debt between creditor ${creditorAccountId} and debtor ${debtorAccountId} for debt amount ${debtorChipsOwed}`, error);
                }
                break;
            } else if (debtorChipsOwed < creditorChipsLeftToCalc) {
                gameLedgers.splice(i, 1);
                debtorTotalChips += debtorChipsOwed

                try {
                    await createDebtRecordForPlayers(
                        creditorAccountId,
                        debtorAccountId,
                        debtorChipsOwed,
                        gameId
                    )
                } catch (error) {
                    console.error(`Internal server error. Failed to create debt between creditor ${creditorAccountId} and debtor ${debtorAccountId} for debt amount ${debtorChipsOwed}`, error);
                }
            } else {
                debtorLedger.cashOutChips += creditorChipsLeftToCalc
                
                try {
                    await createDebtRecordForPlayers(
                        creditorAccountId,
                        debtorAccountId,
                        creditorChipsLeftToCalc,
                        gameId
                    )
                } catch (error) {
                    console.error(`Internal server error. Failed to create debt between creditor ${creditorAccountId} and debtor ${debtorAccountId} for debt amount ${debtorChipsOwed}`, error);
                }
            }
        }
    }

    return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" }
    };
};


const createDebtRecordForPlayers = async (creditorAccountId, debtorAccountId, debtAmount, gameId) => {
    const debtRecord = DebtRecord.toObject(
        DebtRecord.create({
            debitorAccountId: debtorAccountId,
            creditorAccountId: creditorAccountId,
            debtAmount: debtAmount,
            isDebtorSettled: false,
            isCreditorSettled: false,
            gameId: gameId,
            creationDateEpochMilliseconds: Date.now()
        }), {
        enums: Number,
        defaults: true
    });

    await docClient.send(
        new PutCommand({
            TableName: DEBTS_TABLE,
            Item: debtRecord
        })
    );
}