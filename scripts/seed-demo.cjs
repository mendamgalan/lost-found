const req = require("node:module").createRequire(
  require("node:path").resolve(__dirname, "../functions/package.json"),
);
if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST
)
  throw Error(
    "Auth/Firestore emulators required; production seeding disabled.",
  );
const { initializeApp } = req("firebase-admin/app"),
  { getAuth } = req("firebase-admin/auth"),
  { getFirestore, Timestamp } = req("firebase-admin/firestore"),
  { makeService } = require("../functions/src/service");
(async () => {
  initializeApp({ projectId: "demo-lost-found" });
  const db = getFirestore(),
    auth = getAuth(),
    svc = makeService(db);
  for (const [uid, name, admin] of [
    ["demo-owner", "Олсон хүн", false],
    ["demo-claimant", "Гээсэн хүн", false],
    ["demo-admin", "Админ", true],
  ]) {
    try {
      await auth.createUser({
        uid,
        email: uid + "@example.test",
        password: "Demo12345",
        emailVerified: true,
      });
    } catch (e) {
      if (
        !["auth/uid-already-exists", "auth/email-already-exists"].includes(
          e.code,
        )
      )
        throw e;
    }
    await auth.setCustomUserClaims(uid, { admin });
    await db
      .doc("privateProfiles/" + uid)
      .set({
        name,
        email: uid + "@example.test",
        phone: "99112233",
        role: admin ? "admin" : "user",
        consentVersion: "mvp-v1",
        consentAt: Timestamp.now(),
        createdAt: Timestamp.now(),
      });
  }
  for (const [id, uid, type] of [
    ["demo-found", "demo-owner", "found"],
    ["demo-lost", "demo-claimant", "lost"],
  ])
    if (!(await db.doc("items/" + id).get()).exists)
      await svc.dispatch({ uid }, "createItem", {
        id,
        type,
        title: "Хар оосортой түлхүүр",
        description: "ШУТИС номын сангийн үүдний түлхүүр",
        category: "Түлхүүр",
        district: "Сүхбаатар",
        placeName: "ШУТИС номын сан",
        eventDate: new Date(Date.now() + 8 * 3600000)
          .toISOString()
          .slice(0, 10),
        secretDetail: "Оосор дотор улаан тэмдэгтэй",
      });
  await svc.matchNotifications("demo-found");
  console.log(
    "Demo accounts ready: demo-owner@example.test / demo-claimant@example.test / demo-admin@example.test; password Demo12345",
  );
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
