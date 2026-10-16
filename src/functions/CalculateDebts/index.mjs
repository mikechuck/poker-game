import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;

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

    const gameRecordObject = GameRecord.toObject(gameRecord, { 
        enums: Number 
    });

    return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(gameRecordObject)
    };
};