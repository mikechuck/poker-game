// This function is to provide authentication for new TCP connections to our server.
// It will run once during TCP connection handshake using a client auth cookie

const REGION = "${region}";
const USER_POOL_ID = "${user_pool_id}";
const APP_CLIENT_ID = "${app_client_id}";

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
        const gameId = params.get("game_id');

        if (!gameId || !joinToken) {
            return {
                statusCode: 400,
                body: JSON.stringify(
                    ErrorResponse.create({
                        message: "Missing parameters" 
                    })
                )
            };
        }

        // Query the JoinTokens table to make sure that this joinToken is associated with this GameId and that it's not Expired
        // If everything comes back fine, return the request. Otherwise, reject connection

        bool tokenIsValid = true;
        if (tokenIsValid) {
            // Append the verified accountId directly to the CloudFront query string so our server code can read it
            if (request.querystring) {
                request.querystring += `&verified_account_id=${accountId}`;
            } else {
                request.querystring = `verified_account_id=${accountId}`;
            }

            return request;
        } else {
            console.error('Auth Error:', err.message);
            return { status: '401', body: 'Unauthorized' };
        }
        
        // Append the verified accountId directly to the CloudFront query string so our server code can read it
        if (request.querystring) {
            request.querystring += `&verified_account_id=${accountId}`;
        } else {
            request.querystring = `verified_account_id=${accountId}`;
        }

        return request;

    } catch (err) {
        console.error('Auth Error:', err.message);
        return { status: '401', body: 'Unauthorized' };
    }
};