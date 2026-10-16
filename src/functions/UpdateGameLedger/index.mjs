import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const ErrorResponse = pokerApiProto.lookupType("poker_api.ErrorResponse");

const GAMES_TABLE = process.env.GAMES_TABLE;


/**
 * Called when a player leaves the game or the user 
 * takes: gameId in path, accountId in body, chipsCount in body
 * Logic: upsert record based on gameId + accountId combined key, just upa
 */

export const handler = async (event) => {
    const gameId = event.pathParameters?.gameId;

}