# HR RIDE - Cashfree Backend

This backend is designed for the HR RIDE Flutter app.

## What it does

- Creates a Cashfree order for the 30% booking advance.
- Calculates 30% advance and 70% balance on the server.
- Returns `orderId` and `paymentSessionId` to the Flutter app.
- Provides server-side order-status verification.
- Receives and verifies Cashfree webhook signatures.
- Keeps the Cashfree Secret Key on the server only.

## Important

Never put `CASHFREE_CLIENT_SECRET` in Flutter or GitHub.

## Render settings

Build Command:
```text
npm install
```

Start Command:
```text
node server.js
```

Environment Variables:
```text
CASHFREE_ENV=sandbox
CASHFREE_CLIENT_ID=<your App ID>
CASHFREE_CLIENT_SECRET=<your Secret Key>
CASHFREE_API_VERSION=2025-01-01
PUBLIC_BASE_URL=<your Render service URL>
```

Start with `sandbox` while testing. Switch to `production` only when the integration is ready for live payments.

## API

### POST /api/create-order

Example JSON:
```json
{
  "bookingId": "BOOKING123",
  "totalAmount": 5000,
  "customerId": "firebase_uid",
  "customerName": "HR RIDE Customer",
  "customerEmail": "customer@example.com",
  "customerPhone": "9000000000"
}
```

Response includes:
- orderId
- paymentSessionId
- totalAmount
- advanceAmount
- balanceAmount

### GET /api/order-status/:orderId

Use this after the Flutter Cashfree callback. A payment should only be treated as successful after server-side verification reports `PAID`.

## Cashfree flow

Flutter -> HR RIDE backend -> Cashfree Create Order
Flutter <- paymentSessionId <- HR RIDE backend
Flutter -> Cashfree checkout
Flutter -> HR RIDE backend -> Cashfree Get Order
Backend accepts success only when Cashfree reports `PAID`.
