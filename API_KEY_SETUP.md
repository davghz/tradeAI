# CDP API Key Setup - ECDSA Format

## Correct API Key Format

The API Key MUST be in this exact format:
```
organizations/{org_id}/apiKeys/{key_id}
```

### Example:
```
organizations/12345678-1234-1234-1234-123456789012/apiKeys/87654321-4321-4321-4321-210987654321
```

## Where to Find These Values

### From Coinbase Developer Portal (https://portal.cdp.coinbase.com/):

1. **Organization ID (`org_id`)**:
   - Log into https://portal.cdp.coinbase.com/
   - Look at the URL or Organization settings
   - Example: `12345678-1234-1234-1234-123456789012`

2. **Key ID (`key_id`)**:
   - Go to API Keys section
   - Create new API Key (select ECDSA!)
   - The Key ID is shown in the list
   - Example: `87654321-4321-4321-4321-210987654321`

3. **Private Key**:
   - Downloaded when you create the API key
   - Format: ECDSA private key (P-256)
   - Either:
     - Base64 value from the downloaded JSON, or
     - PEM block (starts with `-----BEGIN EC PRIVATE KEY-----`)

## JSON File Format

Create `cdp_api_key.json`:
```json
{
  "api_key": "organizations/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/apiKeys/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "private_key": "-----BEGIN EC PRIVATE KEY-----\nMC4CAQAwBQYDK2VwBCIEIL...rest_of_key...\n-----END EC PRIVATE KEY-----"
}
```

Or base64-only:
```json
{
  "api_key": "organizations/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/apiKeys/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "private_key": "<BASE64_ED25519_PRIVATE_KEY>"
}
```

## Important Notes

1. **ECDSA is REQUIRED** - Do NOT use HMAC-SHA256 keys
2. **Full path required** - Just the key ID is not enough
3. **Private key is one-time** - If you lose it, create a new key
4. **Permissions needed**:
   - `view` - For reading account data
   - `trade` - For placing orders

## Common Errors

### ❌ INVALID:
```json
{
  "api_key": "my-api-key-123",
  "private_key": "abc123..."
}
```

### ❌ INVALID:
```json
{
  "api_key": "87654321-4321-4321-4321-210987654321",
  "private_key": "..."
}
```

### ✅ VALID:
```json
{
  "api_key": "organizations/12345678-1234-1234-1234-123456789012/apiKeys/87654321-4321-4321-4321-210987654321",
  "private_key": "-----BEGIN EC PRIVATE KEY-----\nMC4CAQAwBQYDK2VwBCIEILxJqhGm7Fyg2e0LV0B7j...\n-----END EC PRIVATE KEY-----"
}
```

## Steps to Get Credentials

1. Go to https://portal.cdp.coinbase.com/
2. Create/select your organization
3. Go to "API Keys" in left sidebar
4. Click "New API Key"
5. **IMPORTANT**: Select "ECDSA" as the signing algorithm
6. Enable permissions: `view` and `trade`
7. Click "Create"
8. **DOWNLOAD** the private key file immediately (you can't get it again!)
9. Copy the "Key ID" shown in the list
10. Construct the full API key:
    - Format: `organizations/{your-org-id}/apiKeys/{key-id}`

## Testing the Key

In the app:
1. Tap "⚙ Settings"
2. Enter the full `organizations/.../apiKeys/...` string
3. Paste the base64 private key or the full PEM block
4. Tap "Save"
5. Tap "🧪 Test API Connection"
6. Should show: "✅ Connection Successful!"

## Troubleshooting

**"Invalid API Key" error:**
- Make sure it starts with `organizations/`
- Make sure it contains `/apiKeys/`
- Check for extra spaces or newlines
- Verify the org ID and key ID are correct

**"Auth Failed":**
- Make sure you selected ECDSA (not HMAC-SHA256) when creating the key
- Verify the private key is complete (base64 or PEM)
- Check that the private key matches the API key

**"HTTP 401" error:**
- API key doesn't have `view` permission
- Key is revoked or expired
- ECDSA signature is incorrect
