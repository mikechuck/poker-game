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

    console.log("headers:", headers)

    // 1. Get Token from Header or Cookie
    let token = '';
    if (headers.cookie) {
        console.log("found cookie");
        const authCookie = headers.cookie[0].value.split('; ').find(c => c.startsWith('poker_token='));
        console.log("authCookie value:", authCookie);
        if (authCookie) token = authCookie.split('=')[1];
    }

    console.log("TEST token:");

    if (!token) return { status: '401', body: 'Missing authorization' };

    console.log("token valid");
    
    try {
        const [headerB64, payloadB64, signatureB64] = token.split('.');
        const header = JSON.parse(atob(headerB64));
        const payload = JSON.parse(atob(payloadB64));

        console.log("decoded all values");

        // 2. Basic Claims Validation
        if (payload.iss !== `https://cognito-idp.$${REGION}.amazonaws.com/$${USER_POOL_ID}`) throw new Error('Wrong Issuer');
        if (payload.exp < Math.floor(Date.now() / 1000)) throw new Error('Token Expired');
        // If using ID tokens, check 'aud'. If Access tokens, check 'client_id'.
        if (payload.aud !== APP_CLIENT_ID && payload.client_id !== APP_CLIENT_ID) throw new Error('Wrong Audience');

        console.log("valid claim!");

        // 3. Cryptographic Signature Verification
        const jwk = await getPublicKey(header.kid);
        if (!jwk) throw new Error('Key Not Found');

        const cryptoKey = await importKey(jwk);
        const data = new TextEncoder().encode(headerB64 + "." + payloadB64);
        const signature = Uint8Array.from(atob(signatureB64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));

        const isValid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", cryptoKey, signature, data);

        console.log("isValid");

        if (isValid) return request;
        throw new Error('Invalid Signature');

    } catch (err) {
        console.error('Auth Error:', err.message);
        return { status: '401', body: 'Unauthorized' };
    }
};