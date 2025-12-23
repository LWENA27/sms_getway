# API Documentation

## Overview

SMS Gateway provides a REST API for external integrations and programmatic access to SMS functionality.

## Base URL

```
https://kzjgdeqfmxkmpmadtbpb.supabase.co
```

## Authentication

All API requests require authentication using an API key.

### API Key Authentication

Include your API key in the request header:

```http
Authorization: Bearer YOUR_API_KEY
```

### Obtaining an API Key

API keys can be created from the application settings:

1. Login to the app
2. Navigate to Settings
3. Click "Generate API Key"
4. Copy and store securely

## Endpoints

### Send SMS

Send an SMS message to a single recipient.

**Endpoint:** `POST /rest/v1/rpc/send_sms`

**Request Body:**
```json
{
  "recipient_phone": "+1234567890",
  "message": "Hello, this is a test message",
  "tenant_id": "uuid-here"
}
```

**Response:**
```json
{
  "success": true,
  "message_id": "uuid-here",
  "status": "pending"
}
```

**Error Response:**
```json
{
  "error": "Invalid phone number",
  "code": "INVALID_PHONE"
}
```

### Send Bulk SMS

Send SMS to multiple recipients.

**Endpoint:** `POST /rest/v1/rpc/send_bulk_sms`

**Request Body:**
```json
{
  "recipients": [
    "+1234567890",
    "+0987654321"
  ],
  "message": "Hello everyone!",
  "tenant_id": "uuid-here"
}
```

**Response:**
```json
{
  "success": true,
  "total": 2,
  "queued": 2,
  "failed": 0
}
```

### Get SMS Logs

Retrieve SMS sending history.

**Endpoint:** `GET /rest/v1/sms_gateway.sms_logs`

**Query Parameters:**
- `tenant_id` (required): Your tenant ID
- `limit`: Number of records (default: 50)
- `offset`: Pagination offset
- `status`: Filter by status (sent, failed, pending)

**Example:**
```http
GET /rest/v1/sms_gateway.sms_logs?tenant_id=uuid&limit=20&status=eq.sent
```

**Response:**
```json
[
  {
    "id": "uuid",
    "recipient_phone": "+1234567890",
    "message": "Test message",
    "status": "sent",
    "sent_at": "2025-12-23T10:00:00Z",
    "created_at": "2025-12-23T09:59:00Z"
  }
]
```

### Create Contact

Add a new contact.

**Endpoint:** `POST /rest/v1/sms_gateway.contacts`

**Request Body:**
```json
{
  "name": "John Doe",
  "phone_number": "+1234567890",
  "user_id": "uuid",
  "tenant_id": "uuid"
}
```

**Response:**
```json
{
  "id": "uuid",
  "name": "John Doe",
  "phone_number": "+1234567890",
  "created_at": "2025-12-23T10:00:00Z"
}
```

### Get Contacts

Retrieve all contacts.

**Endpoint:** `GET /rest/v1/sms_gateway.contacts`

**Query Parameters:**
- `tenant_id` (required): Your tenant ID
- `user_id`: Filter by user
- `limit`: Number of records
- `offset`: Pagination offset

**Example:**
```http
GET /rest/v1/sms_gateway.contacts?tenant_id=uuid&limit=50
```

**Response:**
```json
[
  {
    "id": "uuid",
    "name": "John Doe",
    "phone_number": "+1234567890",
    "created_at": "2025-12-23T10:00:00Z"
  }
]
```

### Create Group

Create a contact group.

**Endpoint:** `POST /rest/v1/sms_gateway.groups`

**Request Body:**
```json
{
  "name": "VIP Customers",
  "description": "Premium customers",
  "user_id": "uuid",
  "tenant_id": "uuid"
}
```

**Response:**
```json
{
  "id": "uuid",
  "name": "VIP Customers",
  "description": "Premium customers",
  "created_at": "2025-12-23T10:00:00Z"
}
```

## Rate Limiting

- **SMS per minute:** 30
- **SMS per day:** 500
- **API calls per minute:** 60

Exceeding limits returns:
```json
{
  "error": "Rate limit exceeded",
  "retry_after": 60
}
```

## Error Codes

| Code | Description |
|------|-------------|
| `INVALID_PHONE` | Phone number format invalid |
| `RATE_LIMIT_EXCEEDED` | Too many requests |
| `INSUFFICIENT_CREDITS` | Not enough SMS credits |
| `INVALID_TENANT` | Tenant ID not found |
| `UNAUTHORIZED` | Invalid API key |
| `MESSAGE_TOO_LONG` | Message exceeds 160 characters |

## SDKs & Examples

### cURL

```bash
curl -X POST https://kzjgdeqfmxkmpmadtbpb.supabase.co/rest/v1/rpc/send_sms \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient_phone": "+1234567890",
    "message": "Hello!",
    "tenant_id": "your-tenant-id"
  }'
```

### JavaScript

```javascript
const response = await fetch(
  'https://kzjgdeqfmxkmpmadtbpb.supabase.co/rest/v1/rpc/send_sms',
  {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer YOUR_API_KEY',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      recipient_phone: '+1234567890',
      message: 'Hello!',
      tenant_id: 'your-tenant-id'
    })
  }
);

const data = await response.json();
console.log(data);
```

### Python

```python
import requests

url = 'https://kzjgdeqfmxkmpmadtbpb.supabase.co/rest/v1/rpc/send_sms'
headers = {
    'Authorization': 'Bearer YOUR_API_KEY',
    'Content-Type': 'application/json'
}
payload = {
    'recipient_phone': '+1234567890',
    'message': 'Hello!',
    'tenant_id': 'your-tenant-id'
}

response = requests.post(url, json=payload, headers=headers)
print(response.json())
```

## Webhooks

Configure webhooks to receive delivery status updates.

### Webhook Events

- `sms.sent` - SMS successfully sent
- `sms.delivered` - SMS delivered to recipient
- `sms.failed` - SMS delivery failed

### Webhook Payload

```json
{
  "event": "sms.delivered",
  "message_id": "uuid",
  "phone": "+1234567890",
  "status": "delivered",
  "timestamp": "2025-12-23T10:00:00Z"
}
```

## Support

For API support:
- Email: api-support@lwenatech.com
- Documentation: https://docs.lwenatech.com
- Status Page: https://status.lwenatech.com
