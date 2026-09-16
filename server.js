const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const admin = require("firebase-admin");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 10000;

const CASHFREE_ENV =
  (process.env.CASHFREE_ENV || "sandbox").toLowerCase();

const CASHFREE_CLIENT_ID =
  process.env.CASHFREE_CLIENT_ID;

const CASHFREE_CLIENT_SECRET =
  process.env.CASHFREE_CLIENT_SECRET;

const CASHFREE_API_VERSION =
  process.env.CASHFREE_API_VERSION || "2025-01-01";

const PUBLIC_BASE_URL =
  process.env.PUBLIC_BASE_URL ||
  "https://hr-ride.onrender.com";

const ORS_API_KEY =
  process.env.ORS_API_KEY;

const CASHFREE_BASE_URL =
  CASHFREE_ENV === "production"
    ? "https://api.cashfree.com/pg"
    : "https://sandbox.cashfree.com/pg";

const ORS_BASE_URL =
  "https://api.heigit.org/openrouteservice/v2/directions/driving-car";


// ============================================================
// FIREBASE ADMIN / FIRESTORE
// ============================================================

let firestore = null;

try {
  if (!admin.apps.length) {

    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {

      admin.initializeApp({
        credential: admin.credential.cert(
          JSON.parse(
            process.env.FIREBASE_SERVICE_ACCOUNT_JSON
          )
        )
      });

    } else if (
      process.env.FIREBASE_PROJECT_ID &&
      process.env.FIREBASE_CLIENT_EMAIL &&
      process.env.FIREBASE_PRIVATE_KEY
    ) {

      admin.initializeApp({
        credential: admin.credential.cert({
          projectId:
            process.env.FIREBASE_PROJECT_ID,

          clientEmail:
            process.env.FIREBASE_CLIENT_EMAIL,

          privateKey:
            process.env.FIREBASE_PRIVATE_KEY
              .replace(/\\n/g, "\n")
        })
      });
    }
  }

  if (admin.apps.length) {
    firestore = admin.firestore();
  }

} catch (e) {

  console.error(
    "Firebase Admin init failed:",
    e.message
  );
}


// ============================================================
// MIDDLEWARE
// ============================================================

app.use(cors());


// ============================================================
// HELPERS
// ============================================================

function cashfreeRequired() {

  if (
    !CASHFREE_CLIENT_ID ||
    !CASHFREE_CLIENT_SECRET
  ) {
    throw new Error(
      "Cashfree credentials are not configured."
    );
  }
}


function safeOrderId(
  bookingId,
  type
) {

  const safe =
    String(
      bookingId || "booking"
    )
      .replace(
        /[^a-zA-Z0-9_-]/g,
        ""
      )
      .slice(0, 24);

  return (
    `hr_${safe}_${type}_${Date.now()}`
  );
}


function num(value) {

  const n = Number(value);

  return Number.isFinite(n)
    ? n
    : 0;
}


// ============================================================
// GEOCODING
// ============================================================

async function geocode(place) {

  const url =
    `https://nominatim.openstreetmap.org/search` +
    `?format=jsonv2` +
    `&limit=1` +
    `&q=${encodeURIComponent(place)}`;

  const response =
    await fetch(
      url,
      {
        headers: {
          "User-Agent":
            "HR-RIDE/1.0 contact: hr-ride"
        }
      }
    );

  if (!response.ok) {

    throw new Error(
      `Geocoding failed (${response.status}).`
    );
  }

  const data =
    await response.json();

  if (!data.length) {

    throw new Error(
      `Location not found: ${place}`
    );
  }

  return [
    Number(data[0].lon),
    Number(data[0].lat)
  ];
}


// ============================================================
// FIRESTORE PAYMENT UPDATE
// ============================================================

async function updateBookingPayment(
  bookingId,
  status,
  orderId,
  paymentType
) {

  if (
    !firestore ||
    !bookingId
  ) {
    return;
  }

  const ref =
    firestore
      .collection("bookings")
      .doc(String(bookingId));

  const snap =
    await ref.get();

  if (!snap.exists) {
    return;
  }

  const upperStatus =
    String(status)
      .toUpperCase();

  const paid =
    [
      "PAID",
      "SUCCESS",
      "SUCCESSFUL"
    ].includes(upperStatus);

  const failed =
    [
      "FAILED",
      "CANCELLED",
      "USER_DROPPED"
    ].includes(upperStatus);

  const now =
    admin.firestore.FieldValue
      .serverTimestamp();

  const type =
    String(
      paymentType || "advance"
    ).toLowerCase();

  const update = {

    lastPaymentOrderId:
      orderId,

    lastPaymentStatus:
      status,

    updatedAt:
      now
  };


  // ==========================================================
  // BALANCE PAYMENT
  // ==========================================================

  if (type === "balance") {

    update.balancePaymentStatus =
      paid
        ? "Paid"
        : failed
          ? "Failed"
          : "Pending";

    if (paid) {

      update.balancePaidAt =
        now;

      update.balancePaymentMethod =
        "Online";
    }

  }


  // ==========================================================
  // ADVANCE PAYMENT
  // ==========================================================

  else {

    update.paymentStatus =
      paid
        ? "Paid"
        : failed
          ? "Failed"
          : "Pending";

    update.advancePaymentStatus =
      paid
        ? "Paid"
        : failed
          ? "Failed"
          : "Pending";

    if (paid) {

      update.paidAt =
        now;

      update.advancePaymentMethod =
        "Online";

      update.status =
        "Confirmed";
    }
  }

  await ref.update(update);
}


// ============================================================
// CASHFREE WEBHOOK
// MUST BE BEFORE express.json()
// ============================================================

app.post(
  "/api/webhooks/cashfree",

  express.raw({
    type: "application/json"
  }),

  async (req, res) => {

    try {

      cashfreeRequired();

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

        return res
          .status(400)
          .json({
            ok: false,
            error:
              "Missing webhook signature."
          });
      }


      const raw =
        Buffer.isBuffer(req.body)
          ? req.body.toString("utf8")
          : String(req.body || "");


      const expected =
        crypto
          .createHmac(
            "sha256",
            CASHFREE_CLIENT_SECRET
          )
          .update(
            String(timestamp) + raw
          )
          .digest("base64");


      if (
        signature !== expected
      ) {

        return res
          .status(401)
          .json({
            ok: false,
            error:
              "Invalid webhook signature."
          });
      }


      const body =
        JSON.parse(raw);


      const orderId =
        body?.data?.order?.order_id ||
        body?.data?.order_id ||
        body?.order_id;


      const status =
        body?.data?.payment?.payment_status ||
        body?.data?.order?.order_status ||
        "UNKNOWN";


      const paymentType =
        body
          ?.data
          ?.order
          ?.order_tags
          ?.payment_type ||

        body
          ?.data
          ?.payment
          ?.payment_tags
          ?.payment_type ||

        "advance";


      const bookingId =
        body
          ?.data
          ?.order
          ?.order_tags
          ?.booking_id ||

        body
          ?.data
          ?.payment
          ?.payment_tags
          ?.booking_id;


      if (
        bookingId &&
        orderId
      ) {

        await updateBookingPayment(
          bookingId,
          status,
          orderId,
          paymentType
        );
      }


      return res.json({
        ok: true
      });

    } catch (e) {

      console.error(
        "Cashfree webhook error:",
        e
      );

      return res
        .status(500)
        .json({
          ok: false,
          error: e.message
        });
    }
  }
);


// ============================================================
// JSON MIDDLEWARE
// ============================================================

app.use(
  express.json({
    limit: "1mb"
  })
);


// ============================================================
// HOME / HEALTH CHECK
// ============================================================

app.get(
  "/",
  (req, res) => {

    res.json({

      service:
        "HR RIDE Backend",

      status:
        "ok",

      environment:
        CASHFREE_ENV,

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
        new Date().toISOString()
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

      success:
        true,

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
        CASHFREE_API_VERSION
    });
  }
);


// ============================================================
// ROUTE DISTANCE
// ============================================================

app.post(
  "/api/route-distance",

  async (req, res) => {

    try {

      const pickup =
        String(
          req.body?.pickup || ""
        ).trim();

      const drop =
        String(
          req.body?.drop || ""
        ).trim();


      if (
        !pickup ||
        !drop
      ) {

        return res
          .status(400)
          .json({

            success:
              false,

            error:
              "Pickup and drop are required."
          });
      }


      if (
        pickup.toLowerCase() ===
        drop.toLowerCase()
      ) {

        return res
          .status(400)
          .json({

            success:
              false,

            error:
              "Pickup and drop cannot be the same."
          });
      }


      if (!ORS_API_KEY) {

        return res
          .status(500)
          .json({

            success:
              false,

            error:
              "ORS_API_KEY is not configured."
          });
      }


      const [
        start,
        end
      ] =
        await Promise.all([
          geocode(pickup),
          geocode(drop)
        ]);


      const response =
        await fetch(
          ORS_BASE_URL,
          {

            method:
              "POST",

            headers: {

              Authorization:
                ORS_API_KEY,

              "Content-Type":
                "application/json"
            },

            body:
              JSON.stringify({

                coordinates:
                  [
                    start,
                    end
                  ],

                units:
                  "km"
              })
          }
        );


      if (!response.ok) {

        throw new Error(
          `Route service failed (${response.status}).`
        );
      }


      const data =
        await response.json();


      const summary =
        data
          ?.routes?.[0]
          ?.summary;


      if (!summary) {

        throw new Error(
          "No route found."
        );
      }


      return res.json({

        success:
          true,

        distanceKm:
          Number(
            summary.distance.toFixed(2)
          ),

        durationMinutes:
          Math.round(
            summary.duration / 60
          )
      });


    } catch (e) {

      console.error(
        "Route distance error:",
        e
      );

      return res
        .status(500)
        .json({

          success:
            false,

          error:
            e.message ||
            "Route calculation failed."
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

      cashfreeRequired();


      const {

        bookingId,

        customerId,

        customerName,

        customerEmail,

        customerPhone,

        orderNote,

        paymentType =
          "advance",

        returnUrl

      } = req.body || {};


      if (!bookingId) {

        return res
          .status(400)
          .json({

            success:
              false,

            error:
              "bookingId is required."
          });
      }


      let booking = null;


      if (firestore) {

        const snap =
          await firestore
            .collection("bookings")
            .doc(String(bookingId))
            .get();


        if (!snap.exists) {

          return res
            .status(404)
            .json({

              success:
                false,

              error:
                "Booking not found."
            });
        }


        booking =
          snap.data() || {};
      }


      const type =
        String(
          paymentType
        ).toLowerCase() ===
        "balance"

          ? "balance"

          : "advance";


      let amount =
        type === "balance"

          ? num(
              booking?.balanceAmount
            )

          : num(
              booking?.advanceAmount
            );


      if (!amount) {

        amount =
          num(
            req.body?.amount
          );
      }


      if (amount <= 0) {

        return res
          .status(400)
          .json({

            success:
              false,

            error:
              "Invalid payment amount."
          });
      }


      if (
        type === "balance" &&
        booking?.balancePaymentStatus ===
          "Paid"
      ) {

        return res
          .status(409)
          .json({

            success:
              false,

            error:
              "Balance is already paid."
          });
      }


      const orderId =
        safeOrderId(
          bookingId,
          type
        );


      const phone =
        String(
          customerPhone ||
          booking?.userPhone ||
          "9999999999"
        )
          .replace(
            /\D/g,
            ""
          )
          .slice(-10);


      const payload = {

        order_id:
          orderId,

        order_amount:
          Number(
            amount.toFixed(2)
          ),

        order_currency:
          "INR",


        customer_details: {

          customer_id:
            String(
              customerId ||
              booking?.userId ||
              bookingId
            ).slice(0, 50),

          customer_name:
            String(
              customerName ||
              booking?.userName ||
              "HR RIDE Customer"
            ).slice(0, 100),

          customer_email:
            String(
              customerEmail ||
              booking?.userEmail ||
              "customer@hrride.app"
            ).slice(0, 100),

          customer_phone:
            phone
        },


        order_meta: {

          return_url:
            returnUrl ||
            `${PUBLIC_BASE_URL}/payment-return?order_id=${encodeURIComponent(orderId)}`
        },


        order_note:
          String(
            orderNote ||
            `HR RIDE ${type} payment`
          ).slice(0, 200),


        order_tags: {

          booking_id:
            String(
              bookingId
            ),

          payment_type:
            type
        }
      };


      const response =
        await fetch(
          `${CASHFREE_BASE_URL}/orders`,
          {

            method:
              "POST",

            headers: {

              "Content-Type":
                "application/json",

              "x-client-id":
                CASHFREE_CLIENT_ID,

              "x-client-secret":
                CASHFREE_CLIENT_SECRET,

              "x-api-version":
                CASHFREE_API_VERSION
            },

            body:
              JSON.stringify(
                payload
              )
          }
        );


      const data =
        await response.json();


      if (!response.ok) {

        return res
          .status(response.status)
          .json({

            success:
              false,

            error:
              data?.message ||
              "Cashfree order creation failed.",

            details:
              data
          });
      }


      if (firestore) {

        await firestore
          .collection("bookings")
          .doc(String(bookingId))
          .set(

            {

              [
                type === "balance"
                  ? "balanceOrderId"
                  : "advanceOrderId"
              ]:
                orderId,


              [
                type === "balance"
                  ? "balancePaymentStatus"
                  : "advancePaymentStatus"
              ]:
                "Pending",


              updatedAt:
                admin.firestore.FieldValue
                  .serverTimestamp()

            },

            {
              merge:
                true
            }
          );
      }


      return res.json({

        success:
          true,

        orderId:

          orderId,

        paymentSessionId:
          data.payment_session_id,

        orderAmount:
          amount,

        paymentType:
          type
      });


    } catch (e) {

      console.error(
        "Create order error:",
        e
      );

      return res
        .status(500)
        .json({

          success:
            false,

          error:
            e.message ||
            "Unable to create Cashfree order."
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

      cashfreeRequired();


      const orderId =
        String(
          req.params.orderId ||
          ""
        ).trim();


      if (!orderId) {

        return res
          .status(400)
          .json({

            success:
              false,

            error:
              "Order ID is required."
          });
      }


      const response =
        await fetch(

          `${CASHFREE_BASE_URL}/orders/${encodeURIComponent(orderId)}`,

          {

            headers: {

              "x-client-id":
                CASHFREE_CLIENT_ID,

              "x-client-secret":
                CASHFREE_CLIENT_SECRET,

              "x-api-version":
                CASHFREE_API_VERSION
            }
          }
        );


      const data =
        await response.json();


      if (!response.ok) {

        return res
          .status(response.status)
          .json({

            success:
              false,

            error:
              data?.message ||
              "Cashfree status failed.",

            details:
              data
          });
      }


      const status =
        data?.order_status ||
        "UNKNOWN";


      if (
        firestore &&
        data?.order_tags?.booking_id
      ) {

        await updateBookingPayment(

          data.order_tags.booking_id,

          status,

          orderId,

          data.order_tags.payment_type ||
            "advance"
        );
      }


      return res.json({

        success:
          true,

        orderId:
          orderId,

        orderStatus:
          status,

        paymentSessionId:
          data?.payment_session_id,

        orderAmount:
          data?.order_amount,

        data:
          data
      });


    } catch (e) {

      console.error(
        "Order status error:",
        e
      );

      return res
        .status(500)
        .json({

          success:
            false,

          error:
            e.message ||
            "Unable to get order status."
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

      cashfreeRequired();


      const orderId =
        String(
          req.params.orderId ||
          ""
        ).trim();


      const response =
        await fetch(

          `${CASHFREE_BASE_URL}/orders/${encodeURIComponent(orderId)}/payments`,

          {

            headers: {

              "x-client-id":
                CASHFREE_CLIENT_ID,

              "x-client-secret":
                CASHFREE_CLIENT_SECRET,

              "x-api-version":
                CASHFREE_API_VERSION
            }
          }
        );


      const data =
        await response.json();


      if (!response.ok) {

        return res
          .status(response.status)
          .json({

            success:
              false,

            error:
              data?.message ||
              "Unable to get payment details.",

            details:
              data
          });
      }


      return res.json({

        success:
          true,

        orderId:
          orderId,

        payments:
          data
      });


    } catch (e) {

      console.error(
        "Get payments error:",
        e
      );

      return res
        .status(500)
        .json({

          success:
            false,

          error:
            e.message ||
            "Unable to get payment details."
        });
    }
  }
);


// ============================================================
// PAYMENT RETURN
// ============================================================

app.get(
  "/payment-return",

  (req, res) => {

    const orderId =
      String(
        req.query.order_id ||
        ""
      );


    const safeOrderId =
      orderId.replace(
        /[<>]/g,
        ""
      );


    res.send(`

<!doctype html>

<html>

<head>

<meta
  name="viewport"
  content="width=device-width,initial-scale=1"
>

<title>
HR RIDE Payment
</title>

</head>


<body
  style="
    font-family:Arial;
    text-align:center;
    padding:50px;
  "
>

<h2>
HR RIDE
</h2>

<p>
Payment process completed.
</p>

<p>
Order:
${safeOrderId}
</p>

<p>
You can return to the HR RIDE app.
</p>

</body>

</html>

`);
  }
);


// ============================================================
// ERROR HANDLER
// ============================================================

app.use(
  (err, req, res, next) => {

    console.error(
      "Unhandled error:",
      err
    );

    res
      .status(500)
      .json({

        success:
          false,

        error:
          "Internal server error."
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
      "========================================"
    );

    console.log(
      "HR RIDE Backend started"
    );

    console.log(
      `PORT: ${PORT}`
    );

    console.log(
      `CASHFREE_ENV: ${CASHFREE_ENV}`
    );

    console.log(
      `CASHFREE_CONFIGURED: ${
        Boolean(
          CASHFREE_CLIENT_ID &&
          CASHFREE_CLIENT_SECRET
        )
      }`
    );

    console.log(
      `ORS_CONFIGURED: ${
        Boolean(
          ORS_API_KEY
        )
      }`
    );

    console.log(
      `PUBLIC_BASE_URL: ${PUBLIC_BASE_URL}`
    );

    console.log(
      "========================================"
    );
  }
);
