const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 10000;

// =============================
// CASHFREE CONFIG
// =============================
const CASHFREE_ENV = process.env.CASHFREE_ENV || "sandbox";
const CASHFREE_CLIENT_ID = process.env.CASHFREE_CLIENT_ID;
const CASHFREE_CLIENT_SECRET = process.env.CASHFREE_CLIENT_SECRET;
const CASHFREE_API_VERSION =
  process.env.CASHFREE_API_VERSION || "2025-01-01";

const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL;

// =============================
// OPENROUTESERVICE CONFIG
// =============================
const ORS_API_KEY = process.env.ORS_API_KEY;

const ORS_BASE_URL = "https://api.heigit.org";

// =============================
// CASHFREE BASE URL
// =============================
const CASHFREE_BASE_URL =
  CASHFREE_ENV === "production"
    ? "https://api.cashfree.com/pg"
    : "https://sandbox.cashfree.com/pg";

// =============================
// MIDDLEWARE
// =============================
app.use(cors());

// =============================
// CASHFREE CONFIG CHECK
// =============================
function requireConfig() {
  if (!CASHFREE_CLIENT_ID || !CASHFREE_CLIENT_SECRET) {
    throw new Error(
      "Cashfree API credentials are not configured."
    );
  }
}

// =============================
// CASHFREE HEADERS
// =============================
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

// =============================
// ORDER ID
// =============================
function makeOrderId(bookingId) {
  const safe = String(bookingId || "booking")
    .replace(/[^a-zA-Z0-9_-]/g, "")
    .slice(0, 30);

  return `hr_${safe}_${Date.now()}`;
}

// ============================================================
// CASHFREE WEBHOOK
// ============================================================

app.post(
  "/api/webhooks/cashfree",
  express.raw({ type: "application/json" }),
  (req, res) => {
    try {
      requireConfig();

      const signature =
        req.headers["x-webhook-signature"];

      const timestamp =
        req.headers["x-webhook-timestamp"];

      if (!signature || !timestamp) {
        return res.status(400).json({
          ok: false,
          error: "Missing webhook signature.",
        });
      }

      const rawBody = req.body.toString("utf8");

      const signedPayload =
        `${timestamp}${rawBody}`;

      const expected = crypto
        .createHmac(
          "sha256",
          CASHFREE_CLIENT_SECRET
        )
        .update(signedPayload)
        .digest("base64");

      const a = Buffer.from(String(signature));
      const b = Buffer.from(expected);

      if (
        a.length !== b.length ||
        !crypto.timingSafeEqual(a, b)
      ) {
        return res.status(401).json({
          ok: false,
          error: "Invalid webhook signature.",
        });
      }

      const event = JSON.parse(rawBody);

      console.log(
        "Verified Cashfree webhook:",
        JSON.stringify(event)
      );

      return res.json({
        ok: true,
      });
    } catch (error) {
      console.error(
        "Webhook error:",
        error
      );

      return res.status(500).json({
        ok: false,
        error: "Webhook processing failed.",
      });
    }
  }
);

// ============================================================
// JSON BODY
// ============================================================

app.use(
  express.json({
    limit: "1mb",
  })
);

// ============================================================
// HEALTH CHECK
// ============================================================

app.get("/", (req, res) => {
  res.json({
    service: "HR RIDE Cashfree + Distance Backend",
    status: "ok",
  });
});

// ============================================================
// AUTO PICKUP → DROP DISTANCE
// ============================================================

app.post(
  "/api/route-distance",
  async (req, res) => {
    try {
      const {
        pickup,
        drop,
      } = req.body || {};

      // -------------------------
      // Validate locations
      // -------------------------

      if (!pickup || !drop) {
        return res.status(400).json({
          success: false,
          error:
            "Pickup and drop are required.",
        });
      }

      // -------------------------
      // Check ORS API key
      // -------------------------

      if (!ORS_API_KEY) {
        return res.status(500).json({
          success: false,
          error:
            "ORS_API_KEY is not configured.",
        });
      }

      // ======================================================
      // GEOCODING FUNCTION
      // ======================================================

      async function geocode(place) {
        const url =
          `${ORS_BASE_URL}/pelias/v1/search` +
          `?text=${encodeURIComponent(place)}` +
          `&boundary.country=IND` +
          `&size=1`;

        const response = await fetch(
          url,
          {
            method: "GET",
            headers: {
              Authorization: ORS_API_KEY,
            },
          }
        );

        const data =
          await response.json();

        if (!response.ok) {
          throw new Error(
            data.error ||
              data.message ||
              `Geocoding failed for ${place}.`
          );
        }

        if (
          !data.features ||
          data.features.length === 0
        ) {
          throw new Error(
            `Location not found: ${place}`
          );
        }

        const coordinates =
          data.features[0].geometry
            .coordinates;

        if (
          !Array.isArray(coordinates) ||
          coordinates.length < 2
        ) {
          throw new Error(
            `Invalid coordinates for ${place}`
          );
        }

        return coordinates;
      }

      // ======================================================
      // FIND PICKUP COORDINATES
      // ======================================================

      const pickupCoords =
        await geocode(pickup);

      // ======================================================
      // FIND DROP COORDINATES
      // ======================================================

      const dropCoords =
        await geocode(drop);

      // ======================================================
      // CALCULATE DRIVING ROUTE
      // ======================================================

      const routeResponse =
        await fetch(
          `${ORS_BASE_URL}/openrouteservice/v2/directions/driving-car`,
          {
            method: "POST",

            headers: {
              Authorization: ORS_API_KEY,
              "Content-Type":
                "application/json",
            },

            body: JSON.stringify({
              coordinates: [
                pickupCoords,
                dropCoords,
              ],

              instructions: false,
            }),
          }
        );

      const routeData =
        await routeResponse.json();

      if (!routeResponse.ok) {
        throw new Error(
          routeData.error ||
            routeData.message ||
            "Route calculation failed."
        );
      }

      // ======================================================
      // ROUTE SEGMENT
      // ======================================================

      const segment =
        routeData.features?.[0]
          ?.properties?.segments?.[0];

      if (
        !segment ||
        typeof segment.distance !==
          "number"
      ) {
        throw new Error(
          "Distance could not be calculated."
        );
      }

      // ======================================================
      // DISTANCE KM
      // ======================================================

      const distanceKm =
        Math.round(
          (segment.distance / 1000) * 10
        ) / 10;

      // ======================================================
      // TRAVEL TIME
      // ======================================================

      const durationMinutes =
        typeof segment.duration ===
        "number"
          ? Math.round(
              segment.duration / 60
            )
          : null;

      // ======================================================
      // RESPONSE
      // ======================================================

      return res.json({
        success: true,

        pickup: pickup,

        drop: drop,

        distanceKm: distanceKm,

        durationMinutes:
          durationMinutes,
      });
    } catch (error) {
      console.error(
        "Route distance error:",
        error
      );

      return res.status(500).json({
        success: false,
        error:
          error.message ||
          "Route calculation failed.",
      });
    }
  }
);

// ============================================================
// CASHFREE CREATE ORDER
// ============================================================

app.post(
  "/api/create-order",
  async (req, res) => {
    try {
      const {
        bookingId,
        totalAmount,
        customerId,
        customerName,
        customerEmail,
        customerPhone,
      } = req.body || {};

      const total =
        Number(totalAmount);

      if (
        !Number.isFinite(total) ||
        total <= 0
      ) {
        return res.status(400).json({
          error:
            "totalAmount must be a positive number.",
        });
      }

      if (!customerPhone) {
        return res.status(400).json({
          error:
            "customerPhone is required.",
        });
      }

      if (!PUBLIC_BASE_URL) {
        return res.status(500).json({
          error:
            "PUBLIC_BASE_URL is not configured.",
        });
      }

      // -------------------------
      // 30% advance
      // -------------------------

      const advanceAmount =
        Math.round(
          total * 0.30 * 100
        ) / 100;

      // -------------------------
      // 70% balance
      // -------------------------

      const balanceAmount =
        Math.round(
          (total - advanceAmount) *
            100
        ) / 100;

      // -------------------------
      // Order ID
      // -------------------------

      const orderId =
        makeOrderId(bookingId);

      // ======================================================
      // CASHFREE PAYLOAD
      // ======================================================

      const payload = {
        order_id: orderId,

        order_amount:
          advanceAmount,

        order_currency: "INR",

        customer_details: {
          customer_id: String(
            customerId ||
              `hr_user_${Date.now()}`
          ),

          customer_name: String(
            customerName ||
              "HR RIDE Customer"
          ).slice(0, 100),

          customer_email: String(
            customerEmail ||
              "customer@hrride.app"
          ).slice(0, 100),

          customer_phone:
            String(customerPhone)
              .replace(/\s+/g, "")
              .slice(-15),
        },

        order_meta: {
          return_url:
            `${PUBLIC_BASE_URL}/payment-return?order_id=${encodeURIComponent(
              orderId
            )}`,

          notify_url:
            `${PUBLIC_BASE_URL}/api/webhooks/cashfree`,
        },

        order_note:
          "HR RIDE booking advance (30%)",

        order_tags: {
          app: "HR_RIDE",

          booking_id:
            String(
              bookingId || ""
            ),

          total_amount:
            total.toFixed(2),

          advance_amount:
            advanceAmount.toFixed(2),

          balance_amount:
            balanceAmount.toFixed(2),
        },
      };

      // ======================================================
      // CREATE CASHFREE ORDER
      // ======================================================

      const response =
        await fetch(
          `${CASHFREE_BASE_URL}/orders`,
          {
            method: "POST",

            headers:
              cashfreeHeaders(),

            body:
              JSON.stringify(
                payload
              ),
          }
        );

      const data =
        await response.json();

      if (!response.ok) {
        console.error(
          "Cashfree create-order error:",
          response.status,
          data
        );

        return res
          .status(response.status)
          .json({
            error:
              "Cashfree order creation failed.",

            details: data,
          });
      }

      return res.json({
        orderId:
          data.order_id,

        paymentSessionId:
          data.payment_session_id,

        totalAmount:
          total,

        advanceAmount:
          advanceAmount,

        balanceAmount:
          balanceAmount,

        currency:
          "INR",
      });
    } catch (error) {
      console.error(
        "Create order error:",
        error
      );

      return res.status(500).json({
        error:
          error.message ||
          "Server error.",
      });
    }
  }
);

// ============================================================
// CASHFREE ORDER STATUS
// ============================================================

app.get(
  "/api/order-status/:orderId",
  async (req, res) => {
    try {
      const orderId =
        req.params.orderId;

      const response =
        await fetch(
          `${CASHFREE_BASE_URL}/orders/${encodeURIComponent(
            orderId
          )}`,
          {
            method: "GET",

            headers:
              cashfreeHeaders(),
          }
        );

      const data =
        await response.json();

      if (!response.ok) {
        return res
          .status(response.status)
          .json({
            error:
              "Cashfree order status lookup failed.",

            details: data,
          });
      }

      return res.json({
        orderId:
          data.order_id,

        orderStatus:
          data.order_status,

        orderAmount:
          data.order_amount,

        orderCurrency:
          data.order_currency,

        paymentStatus:
          data.order_status ===
          "PAID"
            ? "PAID"
            : data.order_status,
      });
    } catch (error) {
      console.error(
        "Order status error:",
        error
      );

      return res.status(500).json({
        error:
          error.message ||
          "Server error.",
      });
    }
  }
);

// ============================================================
// CASHFREE PAYMENT RETURN
// ============================================================

app.get(
  "/payment-return",
  (req, res) => {
    res.send(`
      <html>
        <head>
          <meta
            name="viewport"
            content="width=device-width, initial-scale=1"
          >
        </head>

        <body
          style="
            font-family:Arial;
            padding:30px;
            text-align:center;
          "
        >
          <h2>HR RIDE</h2>

          <p>
            Payment return received.
          </p>

          <p>
            You can return to the
            HR RIDE app.
          </p>
        </body>
      </html>
    `);
  }
);

// ============================================================
// START SERVER
// ============================================================

app.listen(
  PORT,
  "0.0.0.0",
  () => {
    console.log(
      `HR RIDE backend listening on port ${PORT}`
    );

    console.log(
      `Cashfree environment: ${CASHFREE_ENV}`
    );

    console.log(
      `ORS configured: ${
        ORS_API_KEY ? "YES" : "NO"
      }`
    );
  }
);
