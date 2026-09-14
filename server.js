const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 10000;

const CASHFREE_ENV = process.env.CASHFREE_ENV || "sandbox";
const CASHFREE_CLIENT_ID = process.env.CASHFREE_CLIENT_ID;
const CASHFREE_CLIENT_SECRET = process.env.CASHFREE_CLIENT_SECRET;
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || "2025-01-01";
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL;

const CASHFREE_BASE_URL =
  CASHFREE_ENV === "production"
    ? "https://api.cashfree.com/pg"
    : "https://sandbox.cashfree.com/pg";

app.use(cors());

function requireConfig() {
  if (!CASHFREE_CLIENT_ID || !CASHFREE_CLIENT_SECRET) {
    throw new Error("Cashfree API credentials are not configured.");
  }
}

function cashfreeHeaders(extra = {}) {
  requireConfig();
  return {
    "Content-Type": "application/json",
    "x-api-version": CASHFREE_API_VERSION,
    "x-client-id": CASHFREE_CLIENT_ID,
    "x-client-secret": CASHFREE_CLIENT_SECRET,
    ...extra,
  };
}

function makeOrderId(bookingId) {
  const safe = String(bookingId || "booking")
    .replace(/[^a-zA-Z0-9_-]/g, "")
    .slice(0, 30);
  return `hr_${safe}_${Date.now()}`;
}

// Webhook route must receive the raw body for signature verification.
app.post(
  "/api/webhooks/cashfree",
  express.raw({ type: "application/json" }),
  (req, res) => {
    try {
      requireConfig();

      const signature = req.headers["x-webhook-signature"];
      const timestamp = req.headers["x-webhook-timestamp"];

      if (!signature || !timestamp) {
        return res.status(400).json({ ok: false, error: "Missing webhook signature." });
      }

      const rawBody = req.body.toString("utf8");
      const signedPayload = `${timestamp}${rawBody}`;

      const expected = crypto
        .createHmac("sha256", CASHFREE_CLIENT_SECRET)
        .update(signedPayload)
        .digest("base64");

      const a = Buffer.from(String(signature));
      const b = Buffer.from(expected);

      if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
        return res.status(401).json({ ok: false, error: "Invalid webhook signature." });
      }

      // Webhook is authenticated. For production, connect this event to
      // your Firestore booking record using the order_id in the payload.
      const event = JSON.parse(rawBody);
      console.log("Verified Cashfree webhook:", JSON.stringify(event));

      return res.json({ ok: true });
    } catch (error) {
      console.error("Webhook error:", error);
      return res.status(500).json({ ok: false, error: "Webhook processing failed." });
    }
  }
);

app.use(express.json({ limit: "1mb" }));

app.get("/", (req, res) => {
  res.json({
    service: "HR RIDE Cashfree Backend",
    status: "ok",
  });
});

// Create a Cashfree order. The server calculates the 30% advance.
app.post("/api/create-order", async (req, res) => {
  try {
    const {
      bookingId,
      totalAmount,
      customerId,
      customerName,
      customerEmail,
      customerPhone,
    } = req.body || {};

    const total = Number(totalAmount);

    if (!Number.isFinite(total) || total <= 0) {
      return res.status(400).json({ error: "totalAmount must be a positive number." });
    }

    if (!customerPhone) {
      return res.status(400).json({ error: "customerPhone is required." });
    }

    if (!PUBLIC_BASE_URL) {
      return res.status(500).json({ error: "PUBLIC_BASE_URL is not configured." });
    }

    const advanceAmount = Math.round(total * 0.30 * 100) / 100;
    const balanceAmount = Math.round((total - advanceAmount) * 100) / 100;
    const orderId = makeOrderId(bookingId);

    const payload = {
      order_id: orderId,
      order_amount: advanceAmount,
      order_currency: "INR",
      customer_details: {
        customer_id: String(customerId || `hr_user_${Date.now()}`),
        customer_name: String(customerName || "HR RIDE Customer").slice(0, 100),
        customer_email: String(customerEmail || "customer@hrride.app").slice(0, 100),
        customer_phone: String(customerPhone).replace(/\s+/g, "").slice(-15),
      },
      order_meta: {
        return_url: `${PUBLIC_BASE_URL}/payment-return?order_id=${encodeURIComponent(orderId)}`,
        notify_url: `${PUBLIC_BASE_URL}/api/webhooks/cashfree`,
      },
      order_note: "HR RIDE booking advance (30%)",
      order_tags: {
        app: "HR_RIDE",
        booking_id: String(bookingId || ""),
        total_amount: total.toFixed(2),
        advance_amount: advanceAmount.toFixed(2),
        balance_amount: balanceAmount.toFixed(2),
      },
    };

    const response = await fetch(`${CASHFREE_BASE_URL}/orders`, {
      method: "POST",
      headers: cashfreeHeaders(),
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error("Cashfree create-order error:", response.status, data);
      return res.status(response.status).json({
        error: "Cashfree order creation failed.",
        details: data,
      });
    }

    return res.json({
      orderId: data.order_id,
      paymentSessionId: data.payment_session_id,
      totalAmount: total,
      advanceAmount,
      balanceAmount,
      currency: "INR",
    });
  } catch (error) {
    console.error("Create order error:", error);
    return res.status(500).json({ error: error.message || "Server error." });
  }
});

// Server-side order verification. Do not trust the Flutter callback alone.
app.get("/api/order-status/:orderId", async (req, res) => {
  try {
    const orderId = req.params.orderId;

    const response = await fetch(
      `${CASHFREE_BASE_URL}/orders/${encodeURIComponent(orderId)}`,
      {
        method: "GET",
        headers: cashfreeHeaders(),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json({
        error: "Cashfree order status lookup failed.",
        details: data,
      });
    }

    return res.json({
      orderId: data.order_id,
      orderStatus: data.order_status,
      orderAmount: data.order_amount,
      orderCurrency: data.order_currency,
      paymentStatus: data.order_status === "PAID" ? "PAID" : data.order_status,
    });
  } catch (error) {
    console.error("Order status error:", error);
    return res.status(500).json({ error: error.message || "Server error." });
  }
});

app.get("/payment-return", (req, res) => {
  res.send(`
    <html>
      <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="font-family:Arial;padding:30px">
        <h2>HR RIDE</h2>
        <p>Payment return received.</p>
        <p>You can return to the HR RIDE app.</p>
      </body>
    </html>
  `);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`HR RIDE backend listening on port ${PORT}`);
});
