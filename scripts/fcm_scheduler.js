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

  const snapshot = await db.collection("schedules").limit(1).get();

  console.log(`Found ${snapshot.size} schedule(s)`);
}

main().catch(console.error);