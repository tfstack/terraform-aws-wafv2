exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    // Parse the request from ALB event
    const path = event.path || '/';
    const method = event.httpMethod || 'GET';
    const headers = event.headers || {};

    console.log('Path:', path);
    console.log('Method:', method);

    // Default response headers
    const responseHeaders = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
    };

    // Handle different paths
    if (path === '/health') {
        console.log('Handling /health endpoint');
        return {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                environment: process.env.ENVIRONMENT || 'dev'
            })
        };
    }

    if (path === '/api/hello') {
        console.log('Handling /api/hello endpoint');
        return {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                message: 'Hello from Lambda!',
                timestamp: new Date().toISOString(),
                method: method,
                path: path
            })
        };
    }

    if (path === '/api/info') {
        console.log('Handling /api/info endpoint');
        return {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                service: 'Lambda ALB Example',
                version: '1.0.0',
                environment: process.env.ENVIRONMENT || 'dev',
                region: process.env.AWS_REGION,
                timestamp: new Date().toISOString()
            })
        };
    }

    // Default response for root path
    if (path === '/') {
        console.log('Handling root path /');
        return {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                message: 'Welcome to Lambda ALB Example',
                endpoints: [
                    '/health - Health check endpoint',
                    '/api/hello - Hello endpoint',
                    '/api/info - Service information'
                ],
                timestamp: new Date().toISOString()
            })
        };
    }

    // 404 for unknown paths
    console.log('Handling unknown path:', path);
    return {
        statusCode: 404,
        headers: responseHeaders,
        body: JSON.stringify({
            error: 'Not Found',
            message: `Path ${path} not found`,
            timestamp: new Date().toISOString()
        })
    };
};
