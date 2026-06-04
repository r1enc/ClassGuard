const admin = require("firebase-admin");

const serviceAccount = JSON.parse(
  process.env.FIREBASE_SERVICE_ACCOUNT
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

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

async function main() {
  console.log("Firebase Connected");

  const target = {
  day: "Thu",
  startTime: "15:50",
};

  console.log(
    `Looking for schedules on ${target.day} at ${target.startTime}`
  );

  const schedules = await db
    .collection("schedules")
    .where("isActive", "==", true)
    .where("day", "==", target.day)
    .where("startTime", "==", target.startTime)
    .get();

  console.log(`Found ${schedules.size} matching schedules`);

  for (const scheduleDoc of schedules.docs) {
    const schedule = scheduleDoc.data();

    const userDoc = await db
      .collection("users")
      .doc(schedule.userId)
      .get();

    if (!userDoc.exists) {
      console.log(`User not found: ${schedule.userId}`);
      continue;
    }

    const userData = userDoc.data();

    if (!userData.fcmToken) {
      console.log(`No FCM token for user: ${schedule.userId}`);
      continue;
    }

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

main().catch(console.error);