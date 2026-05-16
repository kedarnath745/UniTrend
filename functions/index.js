const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({ region: "asia-south1" }); // Mumbai — low latency for Indian users

const db = admin.firestore();
const messaging = admin.messaging();

// ── Helpers ──────────────────────────────────────────────────────────────────

async function getAllTokens() {
  const snap = await db.collection("fcm_tokens").get();
  return snap.docs.map((d) => d.data().token).filter(Boolean);
}

async function sendToAll(tokens, data) {
  if (tokens.length === 0) return;
  const staleTokens = [];

  // FCM sendEachForMulticast accepts up to 500 tokens per call.
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: batch,
      data,
      android: { priority: "high" },
    });

    // Collect stale/unregistered tokens for cleanup.
    response.responses.forEach((r, idx) => {
      if (
        !r.success &&
        (r.error?.code === "messaging/registration-token-not-registered" ||
          r.error?.code === "messaging/invalid-registration-token")
      ) {
        staleTokens.push(batch[idx]);
      }
    });
  }

  // Delete stale tokens in a batch.
  if (staleTokens.length > 0) {
    const batchWrite = db.batch();
    staleTokens.forEach((t) =>
      batchWrite.delete(db.collection("fcm_tokens").doc(t))
    );
    await batchWrite.commit();
  }
}

// ── Scheduled functions ───────────────────────────────────────────────────────

// Sends a silent wake-up signal every 3 hours so the app can run watchlist
// and velocity checks even when completely closed.
exports.sendTrendWakeup = onSchedule("every 3 hours", async () => {
  const tokens = await getAllTokens();
  await sendToAll(tokens, { type: "wakeup" });
});

// Sends the morning digest trigger at 8 AM IST (2:30 AM UTC).
exports.sendMorningDigest = onSchedule("30 2 * * *", async () => {
  const tokens = await getAllTokens();
  await sendToAll(tokens, { type: "morning_digest" });
});
