const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const crypto = require('crypto');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DYNAMODB_TABLE;

// Hash IP + User Agent for privacy-friendly unique visitor tracking
function hashVisitor(ip, userAgent) {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  return crypto
    .createHash('sha256')
    .update(`${ip}-${userAgent}-${today}`)
    .digest('hex')
    .substring(0, 16);
}

// Get current date in YYYY-MM-DD format
function getDateKey() {
  return new Date().toISOString().split('T')[0];
}

// Track page view
async function trackPageView(data) {
  const dateKey = getDateKey();
  const timestamp = new Date().toISOString();
  
  // Increment daily page view counter
  await docClient.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      pk: 'STATS',
      sk: `DATE#${dateKey}`
    },
    UpdateExpression: 'ADD pageViews :inc SET #date = :date, updatedAt = :timestamp',
    ExpressionAttributeNames: {
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':inc': 1,
      ':date': dateKey,
      ':timestamp': timestamp
    }
  }));

  // Track unique visitor
  if (data.visitorHash) {
  try {
    await docClient.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        pk: `VISITOR#${dateKey}`,
        sk: data.visitorHash,
        date: dateKey,
        timestamp,
        page: data.page || '/',
        ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) // 90 days TTL
      },
      ConditionExpression: 'attribute_not_exists(pk)'
    }));

    // Only increment if new visitor (no error thrown)
    await docClient.send(new UpdateCommand({
      TableName: TABLE_NAME,
      Key: {
        pk: 'STATS',
        sk: `DATE#${dateKey}`
      },
      UpdateExpression: 'ADD uniqueVisitors :inc',
      ExpressionAttributeValues: {
        ':inc': 1
      }
    }));
  } catch (error) {
    // Ignore if visitor already exists (ConditionExpression failed)
    if (error.name !== 'ConditionalCheckFailedException') {
      throw error;
    }
  }
 }
}

// Track Quantum Fiber referral click
async function trackQuantumFiberClick(data) {
  const dateKey = getDateKey();
  const timestamp = new Date().toISOString();
  const clickId = crypto.randomBytes(8).toString('hex');

  // Store click event
  await docClient.send(new PutCommand({
    TableName: TABLE_NAME,
    Item: {
      pk: 'QUANTUM_FIBER',
      sk: `CLICK#${timestamp}#${clickId}`,
      date: dateKey,
      timestamp,
      visitorHash: data.visitorHash || 'unknown',
      page: data.page || '/',
      linkId: data.linkId || 'unknown',
      linkText: data.linkText || '',
      ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year TTL
    }
  }));

  // Increment daily Quantum Fiber click counter
  await docClient.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      pk: 'STATS',
      sk: `DATE#${dateKey}`
    },
    UpdateExpression: 'ADD quantumFiberClicks :inc',
    ExpressionAttributeValues: {
      ':inc': 1
    }
  }));

  // Increment all-time Quantum Fiber counter
  await docClient.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      pk: 'STATS',
      sk: 'ALL_TIME'
    },
    UpdateExpression: 'ADD quantumFiberClicks :inc SET updatedAt = :timestamp',
    ExpressionAttributeValues: {
      ':inc': 1,
      ':timestamp': timestamp
    }
  }));
}

// Track Amazon affiliate click
async function trackAmazonClick(data) {
  const dateKey = getDateKey();
  const timestamp = new Date().toISOString();
  const clickId = crypto.randomBytes(8).toString('hex');

  // Store click event
  await docClient.send(new PutCommand({
    TableName: TABLE_NAME,
    Item: {
      pk: 'AMAZON',
      sk: `CLICK#${timestamp}#${clickId}`,
      date: dateKey,
      timestamp,
      visitorHash: data.visitorHash || 'unknown',
      page: data.page || '/',
      linkText: data.linkText || '',
      ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year TTL
    }
  }));

  // Increment daily Amazon click counter
  await docClient.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      pk: 'STATS',
      sk: `DATE#${dateKey}`
    },
    UpdateExpression: 'ADD amazonClicks :inc',
    ExpressionAttributeValues: {
      ':inc': 1
    }
  }));

  // Increment all-time Amazon counter
  await docClient.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      pk: 'STATS',
      sk: 'ALL_TIME'
    },
    UpdateExpression: 'ADD amazonClicks :inc SET updatedAt = :timestamp',
    ExpressionAttributeValues: {
      ':inc': 1,
      ':timestamp': timestamp
    }
  }));
}

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  // CORS headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json'
  };

  // Handle OPTIONS request
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  try {
    const body = JSON.parse(event.body || '{}');
    const eventType = body.event;

    // Get visitor info
    const ip = event.requestContext?.identity?.sourceIp || 'unknown';
    const userAgent = event.requestContext?.identity?.userAgent || 'unknown';
    const visitorHash = hashVisitor(ip, userAgent);

    const data = {
      ...body,
      visitorHash
    };

    // Route to appropriate handler
    switch (eventType) {
      case 'pageView':
        await trackPageView(data);
        break;
      case 'quantumFiberClick':
        await trackQuantumFiberClick(data);
        break;
      case 'amazonClick':
        await trackAmazonClick(data);
        break;
      default:
        return {
          statusCode: 400,
          headers,
          body: JSON.stringify({ error: 'Invalid event type' })
        };
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ success: true })
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};
