const admin = require("firebase-admin");

const serviceAccount = JSON.parse(
  process.env.FIREBASE_SERVICE_ACCOUNT
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function main() {
  console.log("Firebase Connected");

  const snapshot = await db
    .collection("schedules")
    .where("isActive", "==", true)
    .get();

  console.log(`Found ${snapshot.size} active schedules`);

  snapshot.forEach((doc) => {
    const data = doc.data();

    console.log({
      id: doc.id,
      day: data.day,
      startTime: data.startTime,
      userId: data.userId,
      isActive: data.isActive,
    });
  });
}

main().catch(console.error);