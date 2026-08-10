// This function is to provide authentication for new TCP connections to our server.
// It will run once during TCP connection handshake using a client auth cookie
import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import protobuf from "protobufjs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GetGameRecord } from "shared/utilities.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pokerApiProto = await protobuf.load(path.join(__dirname, "shared/poker_api.proto"));
const GameRecord = pokerApiProto.lookupType("poker_api.GameRecord");
const GameStatus = pokerApiProto.lookupEnum("poker_api.GameStatus");
const JoinTokenRecord = pokerApiProto.lookupType("poker_api.JoinTokenRecord");

const REGION = "${region}";
const USER_POOL_ID = "${user_pool_id}";
const APP_CLIENT_ID = "${app_client_id}";

const GAMES_TABLE = "${games_table_name}";
const JOIN_TOKENS_TABLE = "${join_tokens_table_name}";

const JWKS_URL = `https://cognito-idp.$${REGION}.amazonaws.com/$${USER_POOL_ID}/.well-known/jwks.json`;

let cachedKeys = null;

async function getPublicKey(kid) {
    if (!cachedKeys) {
        const response = await fetch(JWKS_URL);
        const jwks = await response.json();
        cachedKeys = jwks.keys;
    }
    return cachedKeys.find(key => key.kid === kid);
}

// Helper to convert JWK to CryptoKey
async function importKey(jwk) {
    return await crypto.subtle.importKey(
        "jwk",
        jwk,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["verify"]
    );
}

exports.handler = async (event) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;

    // Grab authentication info from cookie
    let token = '';
    if (headers.cookie) {
        const authCookie = headers.cookie[0].value.split('; ').find(c => c.startsWith('poker_token='));
        if (authCookie) token = authCookie.split('=')[1];
    }

    if (!token) return { status: '401', body: 'Missing authorization' };
    
    try {
        const [headerB64, payloadB64, signatureB64] = token.split('.');
        const header = JSON.parse(atob(headerB64));
        const payload = JSON.parse(atob(payloadB64));

        // Basic claims validation
        if (payload.iss !== `https://cognito-idp.$${REGION}.amazonaws.com/$${USER_POOL_ID}`) throw new Error('Wrong Issuer');
        if (payload.exp < Math.floor(Date.now() / 1000)) throw new Error('Token Expired');
        if (payload.aud !== APP_CLIENT_ID && payload.client_id !== APP_CLIENT_ID) throw new Error('Wrong Audience');

        // Cryptographic Signature Verification
        const jwk = await getPublicKey(header.kid);
        if (!jwk) throw new Error('Key Not Found');
        const cryptoKey = await importKey(jwk);
        const data = new TextEncoder().encode(headerB64 + "." + payloadB64);
        const signature = Uint8Array.from(atob(signatureB64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
        const isValid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", cryptoKey, signature, data);

        if (!isValid) throw new Error('Invalid Signature');
        
        // Requestor is valid, continue

        const requestorAccountId = payload.sub;

        // Validate game privacy rules
        const querystring = request.querystring;
        const params = new URLSearchParams(querystring);
        const joinToken = params.get('join_token');
        const gameId = params.get("game_id");

        if (!gameId || !joinToken) {
            return {
                statusCode: 401,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: 'Unauthorized'
                    })
                )
            };
        }

        // Query the JoinTokens table to make sure that this joinToken is associated with this GameId for this player
        // and that it's not Expired. If everything comes back fine, return the request. Otherwise, reject connection
        const joinQueryResponse = await docClient.send(new QueryCommand({
            TableName: JOIN_TOKENS_TABLE,
            KeyConditionExpression: "accountId = :aId",
            ExpressionAttributeValues: {
                ":aId": requestorAccountId
            }
        }));

        const joinTokenItem = queryResponse.Items?.[0] ?? null;

        if (!joinTokenItem) {
            return {
                statusCode: 401,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: 'Unauthorized'
                    })
                )
            };
        }

        const joinTokenRecord = JoinTokenRecord.create(joinTokenItem);

        // Validate info against table record, reject if anything is invalid or expired
        if (joinTokenRecord.gameId != gameId ||
            joinTokenRecord.accountId != requestorAccountId ||
            joinTokenRecord.expirationTimeEpochMilliseconds <= Date.now() ||
            joinTokenRecord.joinToken != joinToken)
        {
            return {
                statusCode: 401,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: 'Unauthorized'
                    })
                )
            };
        }

        // Then, query games table to make sure game is still active. Do this after we confirmed that the user
        // has access to this game information, otherwise don't want to give away details that the gameId state
        var gameRecord = GameRecord.create(await GetGameRecord(gameId, GAMES_TABLE))
        
        if (gameRecord.gameStatus != GameRecord.STARTED) {
            return {
                statusCode: 404,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: 'Unauthorized'
                    })
                )
            };
        }

        // Success! Append the verified requestorAccountId directly to the CloudFront query string 
        // so our server code can read it and create player to playerId associations in game
        if (request.querystring) {
            request.querystring += `&verified_account_id=$${requestorAccountId}`;
        } else {
            request.querystring = `verified_account_id=$${requestorAccountId}`;
        }

        return request;

    } catch (err) {
        return {
            statusCode: 404,
            body: JSON.stringify(
                ErrorResponse.create({
                    message: 'Unauthorized'
                })
            )
        };
    }
};