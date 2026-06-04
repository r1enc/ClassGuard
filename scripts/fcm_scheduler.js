// Initializes Firebase Admin SDK using GitHub Actions secrets.
const admin = require("firebase-admin");

const serviceAccount = JSON.parse(
  process.env.FIREBASE_SERVICE_ACCOUNT
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Calculates the target schedule time (current WIB time + 5 minutes).
function getCurrentWIBPlus5Minutes() {
  const now = new Date();

  const wib = new Date(
    now.toLocaleString("en-US", {
      timeZone: "Asia/Jakarta",
    })
  );

  wib.setMinutes(wib.getMinutes() + 5);

  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  return {
    day: days[wib.getDay()],
    startTime: `${String(wib.getHours()).padStart(2, "0")}:${String(
      wib.getMinutes()
    ).padStart(2, "0")}`,
  };
}

// Main scheduler process executed by GitHub Actions.
async function main() {
  console.log("Firebase Connected");

  // Determines which schedules should receive a warmup notification.
  const target = getCurrentWIBPlus5Minutes();

  console.log(
    `Looking for schedules on ${target.day} at ${target.startTime}`
  );

  // Retrieves active schedules that are about to start within the warmup window.
  const schedules = await db
    .collection("schedules")
    .where("isActive", "==", true)
    .where("day", "==", target.day)
    .where("startTime", "==", target.startTime)
    .get();

  console.log(`Found ${schedules.size} matching schedules`);

  for (const scheduleDoc of schedules.docs) {
    const schedule = scheduleDoc.data();

    // Retrieves the schedule owner's FCM token.
    const userDoc = await db
      .collection("users")
      .doc(schedule.userId)
      .get();

    if (!userDoc.exists) {
      console.log(`User not found: ${schedule.userId}`);
      continue;
    }

    const userData = userDoc.data();

    // Skip schedules whose owners do not have a registered FCM token.
    if (!userData.fcmToken) {
      console.log(`No FCM token for user: ${schedule.userId}`);
      continue;
    }

    // Sends a high-priority warmup notification to the target device.
    const message = {
      token: userData.fcmToken,
      data: {
        action: "WARMUP",
      },
      android: {
        priority: "high",
      },
    };

    try {
      // Logs successful warmup delivery for monitoring and debugging purposes.
      const response = await admin.messaging().send(message);

      console.log(
        `WARMUP sent to ${schedule.userId}: ${response}`
      );
    } catch (error) {
      console.error(
        `Failed sending to ${schedule.userId}`,
        error.message
      );
    }
  }
}
// Prevents the scheduler from terminating silently when an unexpected error occurs.
main().catch(console.error);