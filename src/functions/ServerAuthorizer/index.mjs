// This function is used to authenticate requests from the server coming through api gateway

export const handler = async (event) => {
    // API Gateway passes identity source parameters inside the primary headers map
    const incomingToken = event.headers['x-server-token'];
    const systemSecret = process.env.SERVER_SECRET_TOKEN;

    // Simple Boolean Evaluation Format (Payload 2.0 Feature)
    const isAuthorized = (incomingToken && incomingToken === systemSecret);

    return {
        "isAuthorized": isAuthorized
    };
}