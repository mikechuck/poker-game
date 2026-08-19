// This function provides authentication for new TCP connections to our server.
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "./shared/utilities.mjs";

const REGION = "${region}";
const USER_POOL_ID = "${user_pool_id}";
const APP_CLIENT_ID = "${app_client_id}";

const GAMES_TABLE = "${games_table_name}";
const JOIN_TOKENS_TABLE = "${join_tokens_table_name}";

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({
    region: "us-east-1"
}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const GameStatus = pokerApiProto.lookupEnum("poker_api.GameStatus");
const JoinTokenRecord = pokerApiProto.lookupType("poker_api.JoinTokenRecord");

const JWKS_URL = `https://cognito-idp.$${REGION}.amazonaws.com/$${USER_POOL_ID}/.well-known/jwks.json`;

// Top-level JWKS Pre-fetch
const jwksPromise = fetch(JWKS_URL).then(res => res.json()).catch(() => null);
let cachedKeys = null;
const importedCryptoKeys = new Map(); // Cache WebCrypto imported keys by kid

const UnauthorizedError = {
    status: "401",
    statusDescription: "Unauthorized",
    headers: {
        "content-type": [{ key: "Content-Type", value: "application/json" }]
    },
    body: JSON.stringify({ message: "Unauthorized" })
};

// Safe Base64URL decoder
function decodeBase64Url(str) {
    const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
    return atob(base64);
}

async function getPublicKey(kid) {
    if (!cachedKeys) {
        const jwks = await jwksPromise;
        if (jwks) cachedKeys = jwks.keys;
    }
    if (!cachedKeys) {
        const response = await fetch(JWKS_URL);
        const jwks = await response.json();
        cachedKeys = jwks.keys;
    }
    return cachedKeys.find(key => key.kid === kid);
}

// Cached CryptoKey importer
async function getImportedKey(jwk) {
    if (importedCryptoKeys.has(jwk.kid)) {
        return importedCryptoKeys.get(jwk.kid);
    }

    const cryptoKey = await crypto.subtle.importKey(
        "jwk",
        jwk,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["verify"]
    );

    importedCryptoKeys.set(jwk.kid, cryptoKey);
    return cryptoKey;
}

export const handler = async (event) => {
    try {
        const request = event.Records[0].cf.request;
        const headers = request.headers;

        // Extract cookie
        let authToken = '';
        if (headers.cookie) {
            const authCookie = headers.cookie[0].value.split('; ').find(c => c.startsWith('poker_token='));
            if (authCookie) authToken = authCookie.split('=')[1];
        }

        if (!authToken) return UnauthorizedError;
        
        const [headerB64, payloadB64, signatureB64] = authToken.split('.');
        if (!headerB64 || !payloadB64 || !signatureB64) return UnauthorizedError;

        // Safe Base64Url parsing
        const header = JSON.parse(decodeBase64Url(headerB64));
        const payload = JSON.parse(decodeBase64Url(payloadB64));

        // Basic claims validation
        if (payload.iss !== `https://cognito-idp.$${REGION}.amazonaws.com/$${USER_POOL_ID}`) return UnauthorizedError;
        if (payload.exp < Math.floor(Date.now() / 1000)) return UnauthorizedError;
        if (payload.aud !== APP_CLIENT_ID && payload.client_id !== APP_CLIENT_ID) return UnauthorizedError;

        // Cryptographic Signature Verification using Cached CryptoKey
        const jwk = await getPublicKey(header.kid);
        if (!jwk) return UnauthorizedError;
        
        const cryptoKey = await getImportedKey(jwk);
        const data = new TextEncoder().encode(headerB64 + "." + payloadB64);
        
        // Decode signature using Uint8Array
        const sigString = decodeBase64Url(signatureB64);
        const signature = Uint8Array.from(sigString, c => c.charCodeAt(0));
        
        const isValid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", cryptoKey, signature, data);
        if (!isValid) return UnauthorizedError;
        
        const requestorAccountId = payload.sub;

        // Parse query parameters
        const params = new URLSearchParams(request.querystring || "");
        const joinToken = params.get("joinToken");
        const gameId = params.get("gameId");

        if (!gameId || !joinToken) return UnauthorizedError;

        // Query JoinTokens table matching accounId
        // Query JoinTokens table using Partition Key
        const joinQueryResponse = await docClient.send(new QueryCommand({
            TableName: JOIN_TOKENS_TABLE,
            KeyConditionExpression: "accountId = :aId",
            ExpressionAttributeValues: {
                ":aId": requestorAccountId
            },
            ConsistentRead: true // Guarantees we see writes made a millisecond ago
        }));

        // Find the item matching this specific joinToken out of any tokens for this account
        const joinTokenItem = joinQueryResponse.Items?.find(item => item.joinToken === joinToken);
        if (!joinTokenItem) return UnauthorizedError;

        const joinTokenRecord = JoinTokenRecord.create(joinTokenItem);

        // Validate table record bounds
        if (joinTokenRecord.gameId !== gameId || 
            joinTokenRecord.accountId !== requestorAccountId ||
            joinTokenRecord.expirationTimeEpochMilliseconds <= Date.now()) {
            return UnauthorizedError;
        }

        // Query games table to verify game is ACTIVE
        const rawGameRecord = await GetGameRecord(gameId, GAMES_TABLE);
        if (!rawGameRecord) return UnauthorizedError;

        const gameRecord = GameRecord.create(rawGameRecord);
        if (gameRecord.gameStatus !== GameStatus.values.ACTIVE) {
            return UnauthorizedError;
        }

        // Append verified_account_id to query string
        if (request.querystring) {
            request.querystring += `&verified_account_id=$${requestorAccountId}`;
        } else {
            request.querystring = `verified_account_id=$${requestorAccountId}`;
        }

        return request;
    } catch (error) {
        console.error("Auth validation failed:", error);
        return UnauthorizedError;
    }
};