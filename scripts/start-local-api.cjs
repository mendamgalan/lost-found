// TCP-only fallback when a sandbox blocks the Functions emulator Unix socket.
const req = require("node:module").createRequire(
  require("node:path").resolve(__dirname, "../functions/package.json"),
);
if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  !process.env.FIREBASE_STORAGE_EMULATOR_HOST
)
  throw Error(
    "Start Auth/Firestore/Storage emulators and set local hosts first.",
  );
process.env.GCLOUD_PROJECT = "demo-lost-found";
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: "demo-lost-found",
  storageBucket: "demo-lost-found.appspot.com",
});
const { api } = require("../functions/src/index"),
  express = req("express"),
  { getFirestore } = req("firebase-admin/firestore"),
  { makeService } = require("../functions/src/service");
const db = getFirestore(),
  svc = makeService(db),
  app = express();
app.use(express.json());
app.post("/demo-lost-found/asia-east1/api", api);
app.listen(5001, "0.0.0.0", () =>
  console.log("Demo-only API ready on port 5001."),
);
const fingerprints = new Map();
db.collection("items").onSnapshot((s) => {
  for (const d of s.docs) {
    const i = d.data(),
      key = JSON.stringify([
        i.title,
        i.description,
        i.category,
        i.district,
        i.placeName,
        i.eventDate,
      ]);
    if (fingerprints.get(d.id) === key) continue;
    fingerprints.set(d.id, key);
    svc.matchNotifications(d.id).catch(console.error);
  }
});
setInterval(() => svc.expire().catch(console.error), 3600000);
