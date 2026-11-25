const req = require("node:module").createRequire(
  require("node:path").resolve(__dirname, "../functions/package.json"),
);
const { initializeApp } = req("firebase-admin/app"),
  { getAuth } = req("firebase-admin/auth"),
  { getFirestore } = req("firebase-admin/firestore");
(async () => {
  const p = process.argv.indexOf("--project"),
    u = process.argv.indexOf("--uid");
  if (p < 0 || u < 0)
    throw Error(
      "Usage: node scripts/set-admin.cjs --project PROJECT --uid UID [--revoke]",
    );
  initializeApp({ projectId: process.argv[p + 1] });
  const uid = process.argv[u + 1],
    user = await getAuth().getUser(uid),
    admin = !process.argv.includes("--revoke");
  await getAuth().setCustomUserClaims(uid, { ...user.customClaims, admin });
  await getFirestore()
    .doc("privateProfiles/" + uid)
    .set({ role: admin ? "admin" : "user" }, { merge: true });
  console.log("Role updated; sign in again to refresh token.");
})().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
