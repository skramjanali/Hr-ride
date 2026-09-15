const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 10000;

// ============================================================
// CASHFREE CONFIG
// ============================================================

const CASHFREE_ENV =
  process.env.CASHFREE_ENV || "sandbox";

const CASHFREE_CLIENT_ID =
  process.env.CASHFREE_CLIENT_ID;

const CASHFREE_CLIENT_SECRET =
  process.env.CASHFREE_CLIENT_SECRET;

const CASHFREE_API_VERSION =
  process.env.CASHFREE_API_VERSION ||
  "2025-01-01";

const PUBLIC_BASE_URL =
  process.env.PUBLIC_BASE_URL ||
  `http://localhost:${PORT}`;

// ============================================================
// OPENROUTESERVICE CONFIG
// ============================================================

const ORS_API_KEY =
  process.env.ORS_API_KEY;

const ORS_BASE_URL =
  "https://api.heigit.org";

// ============================================================
// CASHFREE BASE URL
// ============================================================

const CASHFREE_BASE_URL =
  CASHFREE_ENV === "production"
    ? "https://api.cashfree.com/pg"
    : "https://sandbox.cashfree.com/pg";

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(cors());

// ============================================================
// CASHFREE WEBHOOK
// IMPORTANT:
// This route MUST come before express.json()
// because Cashfree signature verification
// needs the original raw request body.
// ============================================================

app.post(
  "/api/webhooks/cashfree",
  express.raw({
    type: "application/json",
  }),
  (req, res) => {
    try {
      if (
        !CASHFREE_CLIENT_SECRET
      ) {
        return res.status(500).json({
          ok: false,
          error:
            "Cashfree secret is not configured.",
        });
      }

      const signature =
        req.headers[
          "x-webhook-signature"
        ];

      const timestamp =
        req.headers[
          "x-webhook-timestamp"
        ];

      if (
        !signature ||
        !timestamp
      ) {
        return res.status(400).json({
          ok: false,
          error:
            "Missing webhook signature.",
        });
      }

      const rawBody =
        Buffer.isBuffer(req.body)
          ? req.body.toString("utf8")
          : String(req.body || "");

      const signedPayload =
        `${timestamp}${rawBody}`;

      const expectedSignature =
        crypto
          .createHmac(
            "sha256",
            CASHFREE_CLIENT_SECRET
          )
          .update(signedPayload)
          .digest("base64");

      const receivedBuffer =
        Buffer.from(signature);

      const expectedBuffer =
        Buffer.from(
          expectedSignature
        );

      if (
        receivedBuffer.length !==
        expectedBuffer.length ||
        !crypto.timingSafeEqual(
          receivedBuffer,
          expectedBuffer
        )
      ) {
        console.error(
          "Invalid Cashfree webhook signature."
        );

        return res.status(401).json({
          ok: false,
          error:
            "Invalid webhook signature.",
        });
      }

      let payload;

      try {
        payload =
          JSON.parse(rawBody);
      } catch (error) {
        return res.status(400).json({
          ok: false,
          error:
            "Invalid webhook JSON.",
        });
      }

      console.log(
        "Cashfree webhook received:",
        JSON.stringify(
          payload,
          null,
          2
        )
      );

      const orderId =
        payload?.data?.order
          ?.order_id ||
        payload?.data?.order_id ||
        null;

      const orderStatus =
        payload?.data?.order
          ?.order_status ||
        payload?.data
          ?.order_status ||
        null;

      const paymentId =
        payload?.data?.payment
          ?.cf_payment_id ||
        payload?.data?.payment_id ||
        null;

      console.log(
        "Webhook order:",
        orderId
      );

      console.log(
        "Webhook status:",
        orderStatus
      );

      console.log(
        "Webhook payment:",
        paymentId
      );

      // --------------------------------------------------------
      // IMPORTANT
      // Firestore update can be added here later.
      //
      // Example:
      //
      // PAID
      // -> paymentStatus = "Paid"
      //
      // FAILED
      // -> paymentStatus = "Failed"
      //
      // --------------------------------------------------------

      return res.status(200).json({
        ok: true,
        received: true,
        orderId,
        orderStatus,
        paymentId,
      });
    } catch (error) {
      console.error(
        "Cashfree webhook error:",
        error
      );

      return res.status(500).json({
        ok: false,
        error:
          error.message ||
          "Webhook processing failed.",
      });
    }
  }
);

// ============================================================
// NORMAL JSON MIDDLEWARE
// ============================================================

app.use(
  express.json({
    limit: "1mb",
  })
);

// ============================================================
// CASHFREE CONFIG CHECK
// ============================================================

function requireCashfreeConfig() {
  if (
    !CASHFREE_CLIENT_ID ||
    !CASHFREE_CLIENT_SECRET
  ) {
    throw new Error(
      "Cashfree API credentials are not configured."
    );
  }
}

// ============================================================
// CASHFREE HEADERS
// ============================================================

function cashfreeHeaders(
  extra = {}
) {
  requireCashfreeConfig();

  return {
    "Content-Type":
      "application/json",

    Accept:
      "application/json",

    "x-api-version":
      CASHFREE_API_VERSION,

    "x-client-id":
      CASHFREE_CLIENT_ID,

    "x-client-secret":
      CASHFREE_CLIENT_SECRET,

    ...extra,
  };
}

// ============================================================
// ORDER ID
// ============================================================

function makeOrderId(
  bookingId
) {
  const safe =
    String(
      bookingId || "booking"
    )
      .replace(
        /[^a-zA-Z0-9_-]/g,
        ""
      )
      .slice(0, 30);

  return `hr_${safe}_${Date.now()}`;
}

// ============================================================
// HEALTH CHECK
// ============================================================

app.get(
  "/",
  (req, res) => {
    res.json({
      service:
        "HR RIDE Cashfree + Distance Backend",

      status:
        "ok",

      environment:
        CASHFREE_ENV,

      cashfreeApiVersion:
        CASHFREE_API_VERSION,

      orsConfigured:
        Boolean(
          ORS_API_KEY
        ),

      time:
        new Date().toISOString(),
    });
  }
);

// ============================================================
// SIMPLE API STATUS
// ============================================================

app.get(
  "/api/status",
  (req, res) => {
    res.json({
      success: true,
      service:
        "HR RIDE Backend",
      cashfree:
        Boolean(
          CASHFREE_CLIENT_ID &&
          CASHFREE_CLIENT_SECRET
        ),
      ors:
        Boolean(
          ORS_API_KEY
        ),
      environment:
        CASHFREE_ENV,
    });
  }
);

// ============================================================
// ORS GEOCODING
// ============================================================

async function geocodePlace(
  place
) {
  if (!ORS_API_KEY) {
    throw new Error(
      "ORS_API_KEY is not configured."
    );
  }

  const url =
    `${ORS_BASE_URL}` +
    `/pelias/v1/search` +
    `?text=${encodeURIComponent(
      place
    )}` +
    `&boundary.country=IND` +
    `&size=1`;

  console.log(
    "ORS geocoding:",
    place
  );

  const response =
    await fetch(url, {
      method: "GET",
      headers: {
        Authorization:
          ORS_API_KEY,

        Accept:
          "application/json",
      },
    });

  const responseText =
    await response.text();

  let data = null;

  try {
    data =
      JSON.parse(
        responseText
      );
  } catch (_) {
    data = null;
  }

  if (!response.ok) {
    console.error(
      "ORS geocoding HTTP error:",
      response.status,
      responseText
    );

    throw new Error(
      data?.error ||
        data?.message ||
        `Geocoding failed for "${place}". HTTP ${response.status}`
    );
  }

  if (
    !data ||
    !Array.isArray(
      data.features
    ) ||
    data.features.length === 0
  ) {
    throw new Error(
      `Location not found: ${place}`
    );
  }

  const feature =
    data.features[0];

  const coordinates =
    feature?.geometry
      ?.coordinates;

  if (
    !Array.isArray(
      coordinates
    ) ||
    coordinates.length < 2
  ) {
    throw new Error(
      `Invalid coordinates for: ${place}`
    );
  }

  const lon =
    Number(
      coordinates[0]
    );

  const lat =
    Number(
      coordinates[1]
    );

  if (
    !Number.isFinite(lon) ||
    !Number.isFinite(lat)
  ) {
    throw new Error(
      `Invalid coordinates for: ${place}`
    );
  }

  console.log(
    "Geocoded:",
    place,
    "=>",
    lon,
    lat
  );

  return [
    lon,
    lat,
  ];
}

// ============================================================
// ROUTE DISTANCE
// ============================================================

app.post(
  "/api/route-distance",
  async (req, res) => {
    try {
      const {
        pickup,
        drop,
      } = req.body || {};

      if (
        !pickup ||
        !String(
          pickup
        ).trim()
      ) {
        return res.status(400).json({
          success: false,
          error:
            "Pickup location is required.",
        });
      }

      if (
        !drop ||
        !String(
          drop
        ).trim()
      ) {
        return res.status(400).json({
          success: false,
          error:
            "Drop location is required.",
        });
      }

      const pickupText =
        String(
          pickup
        ).trim();

      const dropText =
        String(
          drop
        ).trim();

      if (
        pickupText.toLowerCase() ===
        dropText.toLowerCase()
      ) {
        return res.status(400).json({
          success: false,
          error:
            "Pickup and drop cannot be the same.",
        });
      }

      if (!ORS_API_KEY) {
        return res.status(500).json({
          success: false,
          error:
            "ORS_API_KEY is not configured.",
        });
      }

      // --------------------------------------------------------
      // GEOCODE PICKUP
      // --------------------------------------------------------

      const pickupCoords =
        await geocodePlace(
          pickupText
        );

      // --------------------------------------------------------
      // GEOCODE DROP
      // --------------------------------------------------------

      const dropCoords =
        await geocodePlace(
          dropText
        );

      console.log(
        "Routing:",
        pickupCoords,
        "=>",
        dropCoords
      );

      // --------------------------------------------------------
      // ORS DIRECTIONS
      // --------------------------------------------------------

      const routeUrl =
        `${ORS_BASE_URL}` +
        `/openrouteservice/v2/directions/driving-car`;

      const routeResponse =
        await fetch(
          routeUrl,
          {
            method: "POST",

            headers: {
              Authorization:
                ORS_API_KEY,

              "Content-Type":
                "application/json",

              Accept:
                "application/json",
            },

            body:
              JSON.stringify({
                coordinates: [
                  pickupCoords,
                  dropCoords,
                ],

                instructions:
                  false,

                units:
                  "m",
              }),
          }
        );

      const routeText =
        await routeResponse.text();

      let routeData = null;

      try {
        routeData =
          JSON.parse(
            routeText
          );
      } catch (_) {
        routeData = null;
      }

      if (
        !routeResponse.ok
      ) {
        console.error(
          "ORS route HTTP error:",
          routeResponse.status,
          routeText
        );

        throw new Error(
          routeData?.error ||
            routeData?.message ||
            `Route calculation failed. HTTP ${routeResponse.status}`
        );
      }

      if (!routeData) {
        throw new Error(
          "ORS returned invalid JSON."
        );
      }

      // --------------------------------------------------------
      // EXTRACT ROUTE
      // --------------------------------------------------------

      const feature =
        routeData
          ?.features?.[0];

      const properties =
        feature?.properties;

      const segment =
        properties
          ?.segments?.[0];

      const segmentDistance =
        segment?.distance;

      const summaryDistance =
        properties
          ?.summary?.distance;

      // Use segment distance first.
      // If unavailable, use summary distance.
      const routeDistance =
        typeof segmentDistance ===
        "number"
          ? segmentDistance
          : typeof summaryDistance ===
              "number"
            ? summaryDistance
            : null;

      if (
        routeDistance === null ||
        !Number.isFinite(
          routeDistance
        )
      ) {
        console.error(
          "Unexpected ORS route response:"
        );

        console.error(
          JSON.stringify(
            routeData,
            null,
            2
          )
        );

        throw new Error(
          "ORS returned no usable route distance."
        );
      }

      // --------------------------------------------------------
      // ORS DISTANCE = METERS
      // Convert to KM
      // --------------------------------------------------------

      const distanceKm =
        Math.round(
          (routeDistance /
            1000) *
            10
        ) / 10;

      // --------------------------------------------------------
      // DURATION
      // --------------------------------------------------------

      const durationSeconds =
        typeof segment?.duration ===
        "number"
          ? segment.duration
          : typeof properties
                ?.summary
                ?.duration ===
              "number"
            ? properties
                .summary.duration
            : null;

      const durationMinutes =
        typeof durationSeconds ===
        "number"
          ? Math.round(
              durationSeconds /
                60
            )
          : null;

      console.log(
        "Route success:",
        {
          pickup:
            pickupText,

          drop:
            dropText,

          distanceKm,

          durationMinutes,
        }
      );

      return res.json({
        success: true,

        pickup:
          pickupText,

        drop:
          dropText,

        distanceKm,

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
      requireCashfreeConfig();

      const {
        bookingId,
        amount,
        customerId,
        customerName,
        customerEmail,
        customerPhone,
        orderNote,
      } =
        req.body || {};

      // --------------------------------------------------------
      // VALIDATE AMOUNT
      // --------------------------------------------------------

      const orderAmount =
        Number(amount);

      if (
        !Number.isFinite(
          orderAmount
        ) ||
        orderAmount < 1
      ) {
        return res.status(400).json({
          success: false,
          error:
            "Valid payment amount is required. Minimum ₹1.",
        });
      }

      // --------------------------------------------------------
      // VALIDATE PHONE
      // --------------------------------------------------------

      const phone =
        String(
          customerPhone || ""
        )
          .replace(
            /\D/g,
            ""
          );

      if (
        phone.length < 10
      ) {
        return res.status(400).json({
          success: false,
          error:
            "Valid customer phone number is required.",
        });
      }

      // --------------------------------------------------------
      // CUSTOMER ID
      // --------------------------------------------------------

      const safeCustomerId =
        String(
          customerId ||
            bookingId ||
            `customer_${Date.now()}`
        )
          .replace(
            /[^a-zA-Z0-9_-]/g,
            ""
          )
          .slice(0, 50);

      // --------------------------------------------------------
      // ORDER ID
      // --------------------------------------------------------

      const orderId =
        makeOrderId(
          bookingId
        );

      // --------------------------------------------------------
      // RETURN URL
      // --------------------------------------------------------

      const returnUrl =
        `${PUBLIC_BASE_URL}/payment-return?order_id=${encodeURIComponent(
          orderId
        )}`;

      // --------------------------------------------------------
      // WEBHOOK URL
      // --------------------------------------------------------

      const webhookUrl =
        `${PUBLIC_BASE_URL}/api/webhooks/cashfree`;

      // --------------------------------------------------------
      // CASHFREE REQUEST
      // --------------------------------------------------------

      const payload = {
        order_id:
          orderId,

        order_amount:
          Number(
            orderAmount.toFixed(2)
          ),

        order_currency:
          "INR",

        customer_details: {
          customer_id:
            safeCustomerId,

          customer_name:
            customerName ||
            "HR RIDE Customer",

          customer_email:
            customerEmail ||
            "",

          customer_phone:
            phone,
        },

        order_meta: {
          return_url:
            returnUrl,

          notify_url:
            webhookUrl,
        },

        order_note:
          orderNote ||
          "HR RIDE Booking Advance",
      };

      console.log(
        "Creating Cashfree order:",
        {
          orderId,
          amount:
            payload.order_amount,
          customerId:
            safeCustomerId,
        }
      );

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

      const responseText =
        await response.text();

      let data = null;

      try {
        data =
          JSON.parse(
            responseText
          );
      } catch (_) {
        data = null;
      }

      if (!response.ok) {
        console.error(
          "Cashfree create order error:",
          response.status,
          responseText
        );

        return res.status(
          response.status
        ).json({
          success: false,

          error:
            data?.message ||
            data?.error_description ||
            data?.error ||
            responseText ||
            "Cashfree order creation failed.",
        });
      }

      console.log(
        "Cashfree order created:",
        {
          orderId:
            data?.order_id,

          paymentSessionId:
            Boolean(
              data?.payment_session_id
            ),
        }
      );

      return res.json({
        success: true,

        orderId:
          data?.order_id ||
          orderId,

        cfOrderId:
          data?.cf_order_id ||
          null,

        paymentSessionId:
          data?.payment_session_id ||
          null,

        orderAmount:
          data?.order_amount ||
          payload.order_amount,

        orderCurrency:
          data?.order_currency ||
          "INR",

        orderStatus:
          data?.order_status ||
          "ACTIVE",

        returnUrl,
      });
    } catch (error) {
      console.error(
        "Create order error:",
        error
      );

      return res.status(500).json({
        success: false,

        error:
          error.message ||
          "Unable to create Cashfree order.",
      });
    }
  }
);

// ============================================================
// CASHFREE GET ORDER STATUS
// ============================================================

app.get(
  "/api/order-status/:orderId",
  async (req, res) => {
    try {
      requireCashfreeConfig();

      const orderId =
        String(
          req.params.orderId ||
          ""
        ).trim();

      if (!orderId) {
        return res.status(400).json({
          success: false,
          error:
            "Order ID is required.",
        });
      }

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

      const responseText =
        await response.text();

      let data = null;

      try {
        data =
          JSON.parse(
            responseText
          );
      } catch (_) {
        data = null;
      }

      if (!response.ok) {
        console.error(
          "Cashfree order status error:",
          response.status,
          responseText
        );

        return res.status(
          response.status
        ).json({
          success: false,

          error:
            data?.message ||
            data?.error_description ||
            data?.error ||
            responseText ||
            "Unable to get order status.",
        });
      }

      return res.json({
        success: true,

        orderId:
          data?.order_id ||
          orderId,

        orderStatus:
          data?.order_status ||
          "UNKNOWN",

        orderAmount:
          data?.order_amount ||
          null,

        orderCurrency:
          data?.order_currency ||
          "INR",

        customerDetails:
          data?.customer_details ||
          null,

        createdAt:
          data?.created_at ||
          null,

        raw:
          data,
      });
    } catch (error) {
      console.error(
        "Order status error:",
        error
      );

      return res.status(500).json({
        success: false,

        error:
          error.message ||
          "Unable to get order status.",
      });
    }
  }
);

// ============================================================
// CASHFREE GET PAYMENTS
// ============================================================

app.get(
  "/api/order-payments/:orderId",
  async (req, res) => {
    try {
      requireCashfreeConfig();

      const orderId =
        String(
          req.params.orderId ||
          ""
        ).trim();

      if (!orderId) {
        return res.status(400).json({
          success: false,
          error:
            "Order ID is required.",
        });
      }

      const response =
        await fetch(
          `${CASHFREE_BASE_URL}/orders/${encodeURIComponent(
            orderId
          )}/payments`,
          {
            method: "GET",

            headers:
              cashfreeHeaders(),
          }
        );

      const responseText =
        await response.text();

      let data = null;

      try {
        data =
          JSON.parse(
            responseText
          );
      } catch (_) {
        data = null;
      }

      if (!response.ok) {
        return res.status(
          response.status
        ).json({
          success: false,

          error:
            data?.message ||
            data?.error ||
            responseText ||
            "Unable to get payment details.",
        });
      }

      return res.json({
        success: true,

        orderId,

        payments:
          Array.isArray(data)
            ? data
            : [],
      });
    } catch (error) {
      console.error(
        "Get payments error:",
        error
      );

      return res.status(500).json({
        success: false,

        error:
          error.message ||
          "Unable to get payment details.",
      });
    }
  }
);

// ============================================================
// PAYMENT RETURN PAGE
// ============================================================

app.get(
  "/payment-return",
  async (req, res) => {
    const orderId =
      String(
        req.query.order_id ||
        ""
      ).trim();

    if (!orderId) {
      return res
        .status(400)
        .send(`
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport"
              content="width=device-width,initial-scale=1">
            <title>HR RIDE Payment</title>
          </head>

          <body style="
            font-family:Arial;
            text-align:center;
            padding:40px;
          ">

            <h2>HR RIDE</h2>

            <p>
              Payment order ID missing.
            </p>

          </body>
          </html>
        `);
    }

    try {
      requireCashfreeConfig();

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

      const status =
        data?.order_status ||
        "UNKNOWN";

      const isPaid =
        status === "PAID";

      const title =
        isPaid
          ? "Payment Successful"
          : "Payment Status";

      const message =
        isPaid
          ? "Your HR RIDE booking advance has been received."
          : `Payment status: ${status}`;

      res
        .status(200)
        .send(`
          <!DOCTYPE html>

          <html>

          <head>

            <meta charset="UTF-8">

            <meta
              name="viewport"
              content="width=device-width,initial-scale=1"
            >

            <title>
              HR RIDE Payment
            </title>

          </head>

          <body style="
            margin:0;
            background:#f5f7fb;
            font-family:Arial,sans-serif;
          ">

            <div style="
              max-width:480px;
              margin:80px auto;
              background:white;
              border-radius:18px;
              padding:30px;
              text-align:center;
              box-shadow:
                0 8px 30px
                rgba(0,0,0,0.10);
            ">

              <h1 style="
                margin-bottom:10px;
              ">
                HR RIDE
              </h1>

              <h2>
                ${title}
              </h2>

              <p>
                ${message}
              </p>

              <p style="
                color:#777;
                font-size:13px;
              ">
                Order ID:
                ${orderId}
              </p>

              <p style="
                color:#777;
                font-size:13px;
              ">
                You can close this page
                and return to the HR RIDE app.
              </p>

            </div>

          </body>

          </html>
        `);
    } catch (error) {
      console.error(
        "Payment return error:",
        error
      );

      res
        .status(500)
        .send(`
          <!DOCTYPE html>

          <html>

          <head>
            <meta charset="UTF-8">
            <meta
              name="viewport"
              content="width=device-width,initial-scale=1"
            >
            <title>HR RIDE Payment</title>
          </head>

          <body style="
            font-family:Arial;
            text-align:center;
            padding:40px;
          ">

            <h2>
              HR RIDE
            </h2>

            <p>
              Unable to verify payment status.
            </p>

            <p>
              Order ID:
              ${orderId}
            </p>

          </body>

          </html>
        `);
    }
  }
);

// ============================================================
// 404 HANDLER
// ============================================================

app.use(
  (req, res) => {
    res.status(404).json({
      success: false,
      error:
        "API endpoint not found.",
      path:
        req.originalUrl,
    });
  }
);

// ============================================================
// GLOBAL ERROR HANDLER
// ============================================================

app.use(
  (
    error,
    req,
    res,
    next
  ) => {
    console.error(
      "Global server error:",
      error
    );

    if (res.headersSent) {
      return next(error);
    }

    res.status(500).json({
      success: false,

      error:
        error.message ||
        "Internal server error.",
    });
  }
);

// ============================================================
// START SERVER
// ============================================================

app.listen(
  PORT,
  () => {
    console.log(
      "================================================"
    );

    console.log(
      "HR RIDE Backend Started"
    );

    console.log(
      `Port: ${PORT}`
    );

    console.log(
      `Environment: ${CASHFREE_ENV}`
    );

    console.log(
      `Cashfree API: ${CASHFREE_API_VERSION}`
    );

    console.log(
      `Cashfree configured: ${
        Boolean(
          CASHFREE_CLIENT_ID &&
          CASHFREE_CLIENT_SECRET
        )
      }`
    );

    console.log(
      `ORS configured: ${
        Boolean(
          ORS_API_KEY
        )
      }`
    );

    console.log(
      `Public URL: ${PUBLIC_BASE_URL}`
    );

    console.log(
      "================================================"
    );
  }
);
