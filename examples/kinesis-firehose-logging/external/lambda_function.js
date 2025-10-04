exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        body: JSON.stringify({
            message: 'Hello from WAF Kinesis Firehose Test API!',
            timestamp: new Date().toISOString(),
            path: event.path,
            method: event.httpMethod,
            queryStringParameters: event.queryStringParameters,
            headers: event.headers
        })
    };

    return response;
};
