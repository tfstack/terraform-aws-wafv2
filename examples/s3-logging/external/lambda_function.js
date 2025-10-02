exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    // Extract request information for logging
    const requestContext = event.requestContext;
    const httpMethod = requestContext.http.method;
    const path = requestContext.http.path;
    const queryString = requestContext.http.queryStringParameters || {};
    const headers = requestContext.http.headers || {};

    // Log request details (this will help demonstrate WAF logging)
    console.log(`Request: ${httpMethod} ${path}`);
    console.log('Query String:', JSON.stringify(queryString));
    console.log('Headers:', JSON.stringify(headers));

    // Simulate different responses based on path
    let responseBody;
    let statusCode = 200;

    switch (path) {
        case '/test-sql':
            // This path is designed to trigger SQL injection rules
            responseBody = {
                message: 'SQL injection test endpoint',
                query: queryString,
                timestamp: new Date().toISOString()
            };
            break;

        case '/test-bot':
            // This path is designed to trigger bot detection rules
            responseBody = {
                message: 'Bot detection test endpoint',
                userAgent: headers['user-agent'] || 'Unknown',
                timestamp: new Date().toISOString()
            };
            break;

        case '/test-rate-limit':
            // This path is designed to trigger rate limiting
            responseBody = {
                message: 'Rate limit test endpoint',
                clientIp: requestContext.http.sourceIp,
                timestamp: new Date().toISOString()
            };
            break;

        case '/health':
            responseBody = {
                status: 'healthy',
                timestamp: new Date().toISOString()
            };
            break;

        default:
            responseBody = {
                message: 'Welcome to WAF S3 Logging Demo',
                endpoints: [
                    '/test-sql - Test SQL injection detection',
                    '/test-bot - Test bot detection',
                    '/test-rate-limit - Test rate limiting',
                    '/health - Health check'
                ],
                timestamp: new Date().toISOString()
            };
    }

    const response = {
        statusCode: statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key'
        },
        body: JSON.stringify(responseBody)
    };

    console.log('Response:', JSON.stringify(response, null, 2));

    return response;
};
