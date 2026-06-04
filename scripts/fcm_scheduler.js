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

  const day = days[wib.getDay()];

  const hours = String(wib.getHours()).padStart(2, "0");
  const minutes = String(wib.getMinutes()).padStart(2, "0");

  return {
    day,
    startTime: `${hours}:${minutes}`,
  };
}

async function main() {
  console.log("Firebase Connected");

  const target = getCurrentWIBPlus5Minutes();

  console.log(
    `Looking for schedules on ${target.day} at ${target.startTime}`
  );

  const snapshot = await db
    .collection("schedules")
    .where("isActive", "==", true)
    .where("day", "==", target.day)
    .where("startTime", "==", target.startTime)
    .get();

  console.log(`Found ${snapshot.size} matching schedules`);

  snapshot.forEach((doc) => {
    const data = doc.data();

    console.log({
      id: doc.id,
      day: data.day,
      startTime: data.startTime,
      userId: data.userId,
    });
  });
}

main().catch(console.error);