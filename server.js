const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
require("dotenv").config();

const app = express();

const PORT =
  process.env.PORT || 10000;

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
// MUST BE BEFORE express.json()
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
          : String(
              req.body || ""
            );

      const signedPayload =
        `${timestamp}${rawBody}`;

      const expectedSignature =
        crypto
          .createHmac(
            "sha256",
            CASHFREE_CLIENT_SECRET
          )
          .update(
            signedPayload
          )
          .digest("base64");

      const receivedBuffer =
        Buffer.from(
          String(signature)
        );

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
          JSON.parse(
            rawBody
          );
      } catch (error) {
        return res.status(400).json({
          ok: false,
          error:
            "Invalid webhook JSON.",
        });
      }

      console.log(
        "================================================"
      );

      console.log(
        "CASHFREE WEBHOOK RECEIVED"
      );

      console.log(
        JSON.stringify(
          payload,
          null,
          2
        )
      );

      console.log(
        "================================================"
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
        "Webhook Order ID:",
        orderId
      );

      console.log(
        "Webhook Order Status:",
        orderStatus
      );

      console.log(
        "Webhook Payment ID:",
        paymentId
      );

      // --------------------------------------------------------
      // Firestore update can be connected later.
      //
      // PAID   -> paymentStatus = Paid
      // FAILED -> paymentStatus = Failed
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

  return (
    `hr_${safe}_${Date.now()}`
  );
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

      cashfreeConfigured:
        Boolean(
          CASHFREE_CLIENT_ID &&
          CASHFREE_CLIENT_SECRET
        ),

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
// API STATUS
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

      apiVersion:
        CASHFREE_API_VERSION,
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
    "================================================"
  );

  console.log(
    "ORS GEOCODING:"
  );

  console.log(
    place
  );

  const response =
    await fetch(
      url,
      {
        method: "GET",

        headers: {
          Authorization:
            ORS_API_KEY,

          Accept:
            "application/json",
        },
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
      "ORS GEOCODING ERROR:",
      response.status
    );

    console.error(
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

  const longitude =
    Number(
      coordinates[0]
    );

  const latitude =
    Number(
      coordinates[1]
    );

  if (
    !Number.isFinite(
      longitude
    ) ||
    !Number.isFinite(
      latitude
    )
  ) {
    throw new Error(
      `Invalid coordinates for: ${place}`
    );
  }

  console.log(
    "Location:",
    place
  );

  console.log(
    "Longitude:",
    longitude
  );

  console.log(
    "Latitude:",
    latitude
  );

  console.log(
    "================================================"
  );

  return [
    longitude,
    latitude,
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

      // --------------------------------------------------------
      // VALIDATION
      // --------------------------------------------------------

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
        "================================================"
      );

      console.log(
        "ORS ROUTING"
      );

      console.log(
        "Pickup:",
        pickupCoords
      );

      console.log(
        "Drop:",
        dropCoords
      );

      // --------------------------------------------------------
      // CURRENT ORS DIRECTIONS ENDPOINT
      // --------------------------------------------------------

      const routeUrl =
        `${ORS_BASE_URL}` +
        `/openrouteservice/v2/directions/driving-car`;

      // --------------------------------------------------------
      // ROUTE REQUEST
      // --------------------------------------------------------

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

      // --------------------------------------------------------
      // ORS HTTP ERROR
      // --------------------------------------------------------

      if (
        !routeResponse.ok
      ) {
        console.error(
          "================================================"
        );

        console.error(
          "ORS ROUTE HTTP ERROR"
        );

        console.error(
          "Status:",
          routeResponse.status
        );

        console.error(
          routeText
        );

        console.error(
          "================================================"
        );

        throw new Error(
          routeData?.error?.message ||
            routeData?.message ||
            routeData?.error ||
            `Route calculation failed. HTTP ${routeResponse.status}`
        );
      }

      if (!routeData) {
        throw new Error(
          "ORS returned invalid JSON."
        );
      }

      // ========================================================
      // ROBUST ORS RESPONSE PARSER
      // ========================================================

      const feature =
        routeData?.features?.[0] ||
        null;

      const properties =
        feature?.properties ||
        routeData?.properties ||
        {};

      const segment =
        properties?.segments?.[0] ||
        null;

      // --------------------------------------------------------
      // POSSIBLE DISTANCE LOCATIONS
      // --------------------------------------------------------

      const segmentDistance =
        segment?.distance;

      const summaryDistance =
        properties
          ?.summary?.distance;

      const directDistance =
        routeData?.distance;

      const featureDistance =
        feature?.distance;

      // Some ORS JSON responses can return
      // a "routes" array instead of GeoJSON.
      const routeObject =
        routeData?.routes?.[0] ||
        null;

      const routeSummaryDistance =
        routeObject
          ?.summary?.distance;

      const routeSegmentDistance =
        routeObject
          ?.segments?.[0]
          ?.distance;

      // --------------------------------------------------------
      // SELECT DISTANCE
      // --------------------------------------------------------

      let routeDistance = null;

      if (
        typeof segmentDistance ===
        "number"
      ) {
        routeDistance =
          segmentDistance;
      } else if (
        typeof summaryDistance ===
        "number"
      ) {
        routeDistance =
          summaryDistance;
      } else if (
        typeof routeSegmentDistance ===
        "number"
      ) {
        routeDistance =
          routeSegmentDistance;
      } else if (
        typeof routeSummaryDistance ===
        "number"
      ) {
        routeDistance =
          routeSummaryDistance;
      } else if (
        typeof directDistance ===
        "number"
      ) {
        routeDistance =
          directDistance;
      } else if (
        typeof featureDistance ===
        "number"
      ) {
        routeDistance =
          featureDistance;
      }

      // --------------------------------------------------------
      // NO DISTANCE FOUND
      // --------------------------------------------------------

      if (
        routeDistance === null ||
        !Number.isFinite(
          routeDistance
        )
      ) {
        console.error(
          "================================================"
        );

        console.error(
          "ORS DISTANCE NOT FOUND"
        );

        console.error(
          JSON.stringify(
            routeData,
            null,
            2
          )
        );

        console.error(
          "================================================"
        );

        throw new Error(
          "ORS returned no usable route distance."
        );
      }

      // ========================================================
      // DISTANCE UNIT
      // ========================================================
      //
      // We requested units = "m",
      // so distance is meters.
      //
      // ========================================================

      const distanceKm =
        Math.round(
          (routeDistance /
            1000) *
            10
        ) / 10;

      // ========================================================
      // DURATION
      // ========================================================

      const segmentDuration =
        segment?.duration;

      const summaryDuration =
        properties
          ?.summary?.duration;

      const routeDuration =
        routeObject
          ?.summary?.duration;

      const routeSegmentDuration =
        routeObject
          ?.segments?.[0]
          ?.duration;

      let durationSeconds =
        null;

      if (
        typeof segmentDuration ===
        "number"
      ) {
        durationSeconds =
          segmentDuration;
      } else if (
        typeof summaryDuration ===
        "number"
      ) {
        durationSeconds =
          summaryDuration;
      } else if (
        typeof routeSegmentDuration ===
        "number"
      ) {
        durationSeconds =
          routeSegmentDuration;
      } else if (
        typeof routeDuration ===
        "number"
      ) {
        durationSeconds =
          routeDuration;
      }

      const durationMinutes =
        typeof durationSeconds ===
        "number"
          ? Math.round(
              durationSeconds /
                60
            )
          : null;

      // ========================================================
      // SUCCESS LOG
      // ========================================================

      console.log(
        "================================================"
      );

      console.log(
        "ORS ROUTE SUCCESS"
      );

      console.log(
        "Pickup:",
        pickupText
      );

      console.log(
        "Drop:",
        dropText
      );

      console.log(
        "Distance:",
        distanceKm,
        "KM"
      );

      console.log(
        "Duration:",
        durationMinutes,
        "minutes"
      );

      console.log(
        "================================================"
      );

      return res.json({
        success: true,

        pickup:
          pickupText,

        drop:
          dropText,

        distanceKm:

          distanceKm,

        durationMinutes:

          durationMinutes,
      });
    } catch (error) {
      console.error(
        "================================================"
      );

      console.error(
        "ROUTE DISTANCE ERROR"
      );

      console.error(
        error
      );

      console.error(
        "================================================"
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
      // AMOUNT
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
      // PHONE
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
      // EMAIL
      // --------------------------------------------------------

      const safeEmail =
        String(
          customerEmail || ""
        ).trim();

      // Cashfree customer email can be supplied
      // when available.
      const finalCustomerEmail =
        safeEmail ||
        `${safeCustomerId}@hrride.app`;

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
        `${PUBLIC_BASE_URL}` +
        `/payment-return` +
        `?order_id=` +
        encodeURIComponent(
          orderId
        );

      // --------------------------------------------------------
      // WEBHOOK URL
      // --------------------------------------------------------

      const webhookUrl =
        `${PUBLIC_BASE_URL}` +
        `/api/webhooks/cashfree`;

      // --------------------------------------------------------
      // CASHFREE PAYLOAD
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
            finalCustomerEmail,

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
        "================================================"
      );

      console.log(
        "CREATING CASHFREE ORDER"
      );

      console.log(
        "Order ID:",
        orderId
      );

      console.log(
        "Amount:",
        payload.order_amount
      );

      console.log(
        "Customer:",
        safeCustomerId
      );

      console.log(
        "================================================"
      );

      // --------------------------------------------------------
      // CASHFREE API
      // --------------------------------------------------------

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

      if (
        !response.ok
      ) {
        console.error(
          "Cashfree create order error:"
        );

        console.error(
          response.status
        );

        console.error(
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
        "Cashfree order created:"
      );

      console.log(
        "Order ID:",
        data?.order_id
      );

      console.log(
        "Payment Session:",
        Boolean(
          data?.payment_session_id
        )
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

        returnUrl:
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
// CASHFREE ORDER STATUS
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

      if (
        !response.ok
      ) {
        console.error(
          "Cashfree status error:",
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
// CASHFREE ORDER PAYMENTS
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

      if (
        !response.ok
      ) {
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

        orderId:

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
// PAYMENT RETURN
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
<meta
  name="viewport"
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
Payment order ID is missing.
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

      if (
        !response.ok
      ) {
        throw new Error(
          data?.message ||
            data?.error ||
            "Unable to verify payment."
        );
      }

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

      return res.status(200).send(`
<!DOCTYPE html>

<html>

<head>

<meta charset="UTF-8">

<meta
  name="viewport"
  content="width=device-width,initial-scale=1">

<title>
HR RIDE Payment
</title>

</head>

<body style="
margin:0;
background:#f4f6f9;
font-family:Arial,sans-serif;
">

<div style="
max-width:480px;
margin:70px auto;
background:white;
border-radius:20px;
padding:30px;
text-align:center;
box-shadow:
0 8px 30px
rgba(0,0,0,0.10);
">

<h1>
HR RIDE
</h1>

<h2>
${title}
</h2>

<p>
${message}
</p>

<p style="
font-size:13px;
color:#777;
word-break:break-all;
">

Order ID:
${orderId}

</p>

<p style="
font-size:13px;
color:#777;
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

      return res
        .status(500)
        .send(`
<!DOCTYPE html>

<html>

<head>

<meta charset="UTF-8">

<meta
  name="viewport"
  content="width=device-width,initial-scale=1">

<title>
HR RIDE Payment
</title>

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
// 404
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
      "GLOBAL SERVER ERROR:",
      error
    );

    if (
      res.headersSent
    ) {
      return next(error);
    }

    return res.status(500).json({
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
      "HR RIDE BACKEND STARTED"
    );

    console.log(
      `PORT: ${PORT}`
    );

    console.log(
      `ENVIRONMENT: ${CASHFREE_ENV}`
    );

    console.log(
      `CASHFREE API VERSION: ${CASHFREE_API_VERSION}`
    );

    console.log(
      `CASHFREE CONFIGURED: ${
        Boolean(
          CASHFREE_CLIENT_ID &&
          CASHFREE_CLIENT_SECRET
        )
      }`
    );

    console.log(
      `ORS CONFIGURED: ${
        Boolean(
          ORS_API_KEY
        )
      }`
    );

    console.log(
      `PUBLIC BASE URL: ${PUBLIC_BASE_URL}`
    );

    console.log(
      "================================================"
    );
  }
);
