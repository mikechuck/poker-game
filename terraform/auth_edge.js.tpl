// No requires! We use the global 'crypto' object
const JWT_SECRET = "${jwt_secret}";

// Helper to convert string to ArrayBuffer
const enc = new TextEncoder();

async function verifyJwt(token, secret) {
    const parts = token.split('.');
    if (parts.length !== 3) return false;

    const [headerB64, payloadB64, signatureB64] = parts;
    
    // Create the signature message
    const message = enc.encode(headerB64 + "." + payloadB64);
    
    // Import the secret key
    const key = await crypto.subtle.importKey(
        "raw",
        enc.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["verify"]
    );

    // Decode signature from Base64Url
    const signature = Uint8Array.from(atob(signatureB64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));

    // Verify
    return await crypto.subtle.verify("HMAC", key, signature, message);
}

exports.handler = async (event) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;

    let token = '';
    // Check Authorization Header
    if (headers.authorization) {
        token = headers.authorization[0].value.replace('Bearer ', '');
    } 
    // Check Cookie Header
    else if (headers.cookie) {
        const cookies = headers.cookie[0].value.split('; ');
        const authCookie = cookies.find(c => c.startsWith('poker_token='));
        if (authCookie) token = authCookie.split('=')[1];
    }

    if (!token) {
        return { status: '401', statusDescription: 'Unauthorized', body: 'Missing Token' };
    }

    const isValid = await verifyJwt(token, JWT_SECRET);

    if (isValid) {
        return request; // Let the request through to EC2
    } else {
        return {
            status: '401',
            statusDescription: 'Unauthorized',
            body: 'Access Denied: Invalid Signature'
        };
    }
};