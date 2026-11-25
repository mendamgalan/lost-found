const assert = require("node:assert/strict");
assert.ok(
  process.env.FIRESTORE_EMULATOR_HOST &&
    process.env.FIREBASE_AUTH_EMULATOR_HOST &&
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
  "Only emulator hosts allowed.",
);
process.env.GCLOUD_PROJECT = "demo-lost-found";
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: "demo-lost-found",
  storageBucket: "demo-lost-found.appspot.com",
});
const handler = require("../src/index").api,
  express = require("express"),
  { getFirestore, Timestamp } = require("firebase-admin/firestore"),
  { getAuth } = require("firebase-admin/auth"),
  { getStorage } = require("firebase-admin/storage"),
  { getApp, deleteApp } = require("firebase-admin/app");
const app = express();
app.use(express.json());
app.post("/api", handler);
let server, base;
const rpc = async (op, payload = {}, token) => {
  const r = await fetch(base, {
    method: "POST",
    signal: AbortSignal.timeout(20000),
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data: { op, payload } }),
  });
  return { status: r.status, body: await r.json() };
};
const identity = async (operation, email) => {
  const r = await fetch(
    `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:${operation}?key=demo-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: "Demo12345",
        returnSecureToken: true,
      }),
    },
  );
  const u = await r.json();
  assert.ok(u.idToken, JSON.stringify(u));
  return u;
};
(async () => {
  server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  base = `http://127.0.0.1:${server.address().port}/api`;
  const owner = await identity("signUp", `owner-${Date.now()}@example.test`),
    claimant = await identity("signUp", `claimant-${Date.now()}@example.test`),
    db = getFirestore();
  for (const u of [owner, claimant])
    await db
      .doc("privateProfiles/" + u.localId)
      .set({
        name: u === owner ? "Owner" : "Claimant",
        email: u.email,
        phone: u === owner ? "99112233" : "88112233",
        createdAt: Timestamp.now(),
      });
  let r = await rpc("adminStats", {}, owner.idToken);
  assert.equal(r.body.error.status, "PERMISSION_DENIED");
  const day = new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10);
  r = await rpc(
    "createItem",
    {
      id: "callable_item",
      type: "found",
      title: "Түлхүүр оллоо",
      description: "Хар оосортой түлхүүр",
      category: "Түлхүүр",
      district: "Сүхбаатар",
      placeName: "Номын сан",
      eventDate: day,
      secretDetail: "Далд улаан тэмдэг",
      ownerId: "spoofed",
      status: "verified",
    },
    owner.idToken,
  );
  assert.equal(r.status, 200, JSON.stringify(r));
  const i = (await db.doc("items/callable_item").get()).data();
  assert.equal(i.ownerId, owner.localId);
  assert.equal(i.status, "open");
  r = await rpc("getItem", { id: "callable_item" });
  assert.equal(r.body.result.secretDetail, undefined);
  assert.equal(r.body.result.item.title, "Түлхүүр оллоо");
  r = await rpc("createClaim", {
    id: "forged",
    itemId: "callable_item",
    uid: claimant.localId,
    answer: "Хуурамч UID илгээсэн хүсэлт",
  });
  assert.equal(r.body.error.status, "UNAUTHENTICATED");
  r = await rpc(
    "createClaim",
    {
      id: "callable_claim",
      itemId: "callable_item",
      answer: "Түлхүүрийн дотор далд улаан тэмдэгтэй",
      proofPaths: [],
    },
    claimant.idToken,
  );
  assert.equal(r.status, 200, JSON.stringify(r));
  r = await rpc("getClaim", { id: "callable_claim" }, claimant.idToken);
  assert.equal(r.body.result.contacts, undefined);
  r = await rpc(
    "decideClaim",
    { id: "callable_claim", approve: true },
    claimant.idToken,
  );
  assert.equal(r.body.error.status, "PERMISSION_DENIED");
  r = await rpc(
    "decideClaim",
    { id: "callable_claim", approve: true },
    owner.idToken,
  );
  assert.equal(r.status, 200, JSON.stringify(r));
  r = await rpc("getClaim", { id: "callable_claim" }, claimant.idToken);
  assert.equal(r.body.result.contacts.owner.phone, "99112233");
  r = await rpc(
    "scheduleHandover",
    {
      id: "callable_claim",
      place: "ШУТИС номын сан",
      meetAt: new Date(Date.now() + 3600000).toISOString(),
    },
    owner.idToken,
  );
  assert.equal(r.status, 200, JSON.stringify(r));
  r = await rpc("getClaim", { id: "callable_claim" }, claimant.idToken);
  assert.equal(typeof r.body.result.claim.handover.meetAt, "string");
  r = await rpc("markReturned", { id: "callable_item" }, owner.idToken);
  assert.equal(r.status, 200, JSON.stringify(r));
  r = await rpc(
    "createClaim",
    {
      id: "closed",
      itemId: "callable_item",
      answer: "Дахин нэхэмжлэх оролдлогын тайлбар",
    },
    claimant.idToken,
  );
  assert.equal(r.body.error.status, "FAILED_PRECONDITION");
  r = await rpc("notifications", {}, claimant.idToken);
  assert.ok(r.body.result.rows.some((n) => n.type === "item_returned"));
  console.log(
    "PASS: two real Auth users complete HTTP claim → verified contacts → handover → returned; closed claim and forged UID blocked.",
  );
  await getAuth().setCustomUserClaims(owner.localId, { admin: true });
  const refreshed = await identity("signInWithPassword", owner.email);
  r = await rpc("adminStats", {}, refreshed.idToken);
  assert.equal(r.status, 200, JSON.stringify(r));
  await db
    .doc("items/formula")
    .set({
      type: "found",
      title: "=FORMULA",
      category: "Түлхүүр",
      district: "Сүхбаатар",
      placeName: "Номын сан",
      eventDate: Timestamp.now(),
      status: "returned",
      returnedAt: Timestamp.now(),
      ownerId: owner.localId,
      isHidden: false,
      isDeleted: false,
      createdAt: Timestamp.now(),
    });
  for (const scope of ["items", "returned"]) {
    r = await rpc("adminReportExport", { scope }, refreshed.idToken);
    assert.equal(r.status, 200, JSON.stringify(r));
    assert.ok(r.body.result.path.startsWith("exports/" + owner.localId + "/"));
    const [csv] = await getStorage()
        .bucket()
        .file(r.body.result.path)
        .download(),
      text = csv.toString("utf8");
    assert.ok(text.includes("'=FORMULA"));
    assert.ok(!text.includes("Далд улаан тэмдэг"));
  }
  console.log(
    "PASS: real admin token, private CSV export, formula escaping and public secret exclusion.",
  );
})()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (server) await new Promise((resolve) => server.close(resolve));
    await getFirestore().terminate();
    await deleteApp(getApp());
  });
