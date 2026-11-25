const { test, before, beforeEach, after } = require("node:test"),
  assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app"),
  { getFirestore, Timestamp } = require("firebase-admin/firestore"),
  { makeService } = require("../src/service"),
  D = require("../src/domain");
let app, db, svc, clock;
const owner = { uid: "owner" },
  alice = { uid: "alice" },
  bob = { uid: "bob" },
  admin = { uid: "admin", admin: true };
before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  app = initializeApp({ projectId: "demo-lost-found" }, "workflow");
  db = getFirestore(app);
  svc = makeService(db, { now: () => clock });
});
after(() => deleteApp(app));
beforeEach(async () => {
  for (const c of await db.listCollections()) {
    const all = await c.get();
    for (let n = 0; n < all.size; n += 400) {
      const b = db.batch();
      for (const d of all.docs.slice(n, n + 400)) b.delete(d.ref);
      await b.commit();
    }
  }
  clock = new Date("2026-11-21T04:00:00Z");
  for (const uid of ["owner", "alice", "bob", "admin"])
    await db
      .doc("privateProfiles/" + uid)
      .set({
        name: uid,
        email: uid + "@example.test",
        phone: "99112233",
        createdAt: Timestamp.fromDate(clock),
      });
});
const item = (id = "item", extra = {}) => ({
  id,
  type: "found",
  title: "Номын сангийн түлхүүр",
  description: "Хар оосортой түлхүүр олсон",
  category: "Түлхүүр",
  district: "Сүхбаатар",
  placeName: "ШУТИС номын сан",
  eventDate: "2026-11-20",
  secretDetail: "Далд улаан тэмдэгтэй",
  ...extra,
});
const create = (id = "item", extra = {}) =>
    svc.dispatch(owner, "createItem", item(id, extra)),
  claim = (a = alice, id = "c1", itemId = "item") =>
    svc.dispatch(a, "createClaim", {
      id,
      itemId,
      answer: "Оосор дотор улаан нууц тэмдэгтэй",
      proofPaths: [],
    }),
  err = (code) => (e) => e.code === code;
test("weighted matching follows 30/30/20/20 and ignores secrets", () => {
  assert.equal(D.score(item(), item()).score, 100);
  assert.equal(
    D.score(
      item(),
      item("x", {
        category: "Утас",
        district: "Налайх",
        placeName: "Хөдөө",
        title: "iPhone",
        eventDate: "2026-11-24",
      }),
    ).score,
    0,
  );
});
test("public create/search/edit/delete never expose item secrets", async () => {
  await create();
  assert.equal(
    (await svc.dispatch(null, "getItem", { id: "item" })).secretDetail,
    undefined,
  );
  assert.equal(
    (await svc.dispatch(null, "listItems", { query: "түлх" })).items.length,
    1,
  );
  await svc.dispatch(
    owner,
    "updateItem",
    item("item", { title: "Шинэ түлхүүр" }),
  );
  assert.equal((await db.doc("items/item").get()).data().title, "Шинэ түлхүүр");
  await svc.dispatch(owner, "deleteItem", { id: "item" });
  await assert.rejects(
    svc.dispatch(alice, "getItem", { id: "item" }),
    err("not-found"),
  );
});
test("duplicate concurrent claims create one request and one pending count", async () => {
  await create();
  const r = await Promise.allSettled([claim(), claim(alice, "c2")]);
  assert.equal(r.filter((x) => x.status === "fulfilled").length, 1);
  assert.equal((await db.doc("items/item").get()).data().pendingCount, 1);
});
test("concurrent verification produces exactly one winner", async () => {
  await create();
  await claim();
  await claim(bob, "c2");
  const r = await Promise.allSettled([
    svc.dispatch(owner, "decideClaim", { id: "c1", approve: true }),
    svc.dispatch(owner, "decideClaim", { id: "c2", approve: true }),
  ]);
  assert.equal(r.filter((x) => x.status === "fulfilled").length, 1);
  assert.equal(
    (await db.collection("claims").where("status", "==", "verified").get())
      .size,
    1,
  );
});
test("contacts are restricted to verified two parties", async () => {
  await create();
  await claim();
  assert.equal(
    (await svc.dispatch(alice, "getClaim", { id: "c1" })).contacts,
    undefined,
  );
  await svc.dispatch(owner, "decideClaim", { id: "c1", approve: true });
  assert.equal(
    (await svc.dispatch(alice, "getClaim", { id: "c1" })).contacts.owner.phone,
    "99112233",
  );
  assert.equal(
    (await svc.dispatch(admin, "getClaim", { id: "c1" })).contacts,
    undefined,
  );
  await assert.rejects(
    svc.dispatch(bob, "getClaim", { id: "c1" }),
    err("permission-denied"),
  );
});
test("self claim, lost claim, unauthorized edit and active deletion are blocked", async () => {
  await create();
  await assert.rejects(claim(owner), err("failed-precondition"));
  await create("lost", { type: "lost" });
  await assert.rejects(claim(alice, "lc", "lost"), err("failed-precondition"));
  await assert.rejects(
    svc.dispatch(alice, "updateItem", item()),
    err("permission-denied"),
  );
  await claim();
  await assert.rejects(
    svc.dispatch(owner, "deleteItem", { id: "item" }),
    err("failed-precondition"),
  );
});
test("withdraw reopens item and permits a later request", async () => {
  await create();
  await claim();
  await svc.dispatch(alice, "withdrawClaim", { id: "c1" });
  assert.equal((await db.doc("items/item").get()).data().status, "open");
  await claim(alice, "c2");
});
test("rejection needs reason and only claimant/admin can create/resolve appeal", async () => {
  await create();
  await claim();
  await assert.rejects(
    svc.dispatch(owner, "decideClaim", {
      id: "c1",
      approve: false,
      reason: "x",
    }),
    err("invalid-argument"),
  );
  await svc.dispatch(owner, "decideClaim", {
    id: "c1",
    approve: false,
    reason: "Нотолгоо хангалтгүй",
  });
  await assert.rejects(
    svc.dispatch(bob, "createDispute", {
      claimId: "c1",
      reason: "Дахин шалгах үндэслэлтэй байна",
    }),
    err("permission-denied"),
  );
  await svc.dispatch(alice, "createDispute", {
    claimId: "c1",
    reason: "Нотлох мэдээллийг дахин шалгана уу",
  });
  await assert.rejects(
    svc.dispatch(owner, "resolveDispute", {
      id: "c1",
      approve: true,
      note: "Нотолгоог дахин шалгалаа",
    }),
    err("permission-denied"),
  );
  await svc.dispatch(admin, "resolveDispute", {
    id: "c1",
    approve: true,
    note: "Нотлох мэдээлэл таарсан тул батлав",
  });
  assert.equal((await db.doc("claims/c1").get()).data().status, "verified");
  assert.ok(
    (
      await db
        .collection("auditLogs")
        .where("action", "==", "dispute.resolve")
        .get()
    ).size,
  );
});
test("admin appeal atomically replaces an incorrect unreturned winner", async () => {
  await create();
  await claim();
  await claim(bob, "c2");
  await svc.dispatch(owner, "decideClaim", { id: "c1", approve: true });
  await svc.dispatch(bob, "createDispute", {
    claimId: "c2",
    reason: "Жинхэнэ эзэмшлийн батлах нотолгоо",
  });
  await svc.dispatch(admin, "resolveDispute", {
    id: "c2",
    approve: true,
    note: "Нотолгоог шалгаад эзэмшигчийг залруулав",
  });
  assert.equal((await db.doc("items/item").get()).data().verifiedClaimId, "c2");
  assert.equal(
    (await svc.dispatch(alice, "getClaim", { id: "c1" })).contacts,
    undefined,
  );
  assert.equal(
    (await db.collection("claims").where("status", "==", "verified").get())
      .size,
    1,
  );
});
test("handover and returned follow a verified request, closed items reject claims", async () => {
  await create();
  await assert.rejects(
    svc.dispatch(owner, "markReturned", { id: "item" }),
    err("failed-precondition"),
  );
  await claim();
  await svc.dispatch(owner, "decideClaim", { id: "c1", approve: true });
  await svc.dispatch(owner, "scheduleHandover", {
    id: "c1",
    place: "ШУТИС номын сан",
    meetAt: "2026-11-22T04:00:00Z",
  });
  await svc.dispatch(owner, "markReturned", { id: "item" });
  assert.equal((await db.doc("items/item").get()).data().status, "returned");
  await assert.rejects(claim(bob, "c2"), err("failed-precondition"));
  await assert.rejects(
    svc.dispatch(owner, "updateItem", item()),
    err("failed-precondition"),
  );
});
test("notifications and bulk read never affect another recipient", async () => {
  await create();
  await claim();
  const n = (await svc.dispatch(owner, "notifications")).rows[0];
  await assert.rejects(
    svc.dispatch(bob, "markRead", { id: n.id }),
    err("permission-denied"),
  );
  await db
    .doc("notifications/other")
    .set({
      recipientId: "bob",
      isRead: false,
      createdAt: Timestamp.fromDate(clock),
    });
  await svc.dispatch(owner, "markAllRead");
  assert.equal(
    (await svc.dispatch(owner, "notifications", { unread: true })).rows.length,
    0,
  );
  assert.equal(
    (await db.doc("notifications/other").get()).data().isRead,
    false,
  );
});
test("matching notifications persist and are idempotent", async () => {
  await create();
  await svc.dispatch(alice, "createItem", item("lost", { type: "lost" }));
  await svc.matchNotifications("lost");
  await svc.matchNotifications("lost");
  assert.equal(
    (await db.collection("notifications").where("type", "==", "match").get())
      .size,
    2,
  );
  assert.equal(
    (await svc.dispatch(alice, "matches", { id: "lost" })).matches[0].score,
    100,
  );
});
test("30 days of inactivity excludes item and expires pending requests", async () => {
  await create();
  await claim();
  clock = new Date("2026-12-22T04:00:00Z");
  await assert.rejects(claim(bob, "c2"), err("failed-precondition"));
  await svc.expire();
  assert.equal((await db.doc("items/item").get()).data().status, "expired");
  assert.equal((await svc.dispatch(null, "listItems")).items.length, 0);
  assert.equal((await db.doc("claims/c1").get()).data().status, "rejected");
});
test("profile, moderation and statistics enforce authority", async () => {
  await svc.dispatch(alice, "updateProfile", {
    name: "Анар",
    phone: "88112233",
    admin: true,
  });
  assert.equal(
    (await db.doc("privateProfiles/alice").get()).data().admin,
    undefined,
  );
  await create();
  await assert.rejects(
    svc.dispatch(alice, "hideItem", {
      id: "item",
      reason: "Зохисгүй мэдээлэл",
    }),
    err("permission-denied"),
  );
  await svc.dispatch(admin, "hideItem", {
    id: "item",
    reason: "Зохисгүй мэдээлэл",
  });
  assert.equal((await svc.dispatch(null, "listItems")).items.length, 0);
  assert.equal((await svc.dispatch(admin, "adminStats")).privateProfiles, 4);
});
test("Ulaanbaatar calendar accepts today before UTC midnight", async () => {
  clock = new Date("2026-11-20T20:00:00Z");
  await create("today", { eventDate: "2026-11-21" });
  assert.ok((await db.doc("items/today").get()).exists);
});
test("admin report, audit search and hidden filter cover web controls", async () => {
  await create("found");
  await create("lost", { type: "lost" });
  await svc.dispatch(admin, "hideItem", {
    id: "found",
    reason: "Давхардсан зарыг шалгах",
  });
  const r = await svc.dispatch(admin, "adminReports", {
    from: "2026-11-20",
    to: "2026-11-21",
  });
  assert.equal(r.insights.totals["Зар"], 2);
  assert.equal(r.insights.itemStates.hidden, 1);
  assert.equal(
    (
      await svc.dispatch(admin, "adminAudit", {
        action: "item.hide",
        query: "admin",
      })
    ).rows.length,
    1,
  );
  assert.equal(
    (await svc.dispatch(admin, "listItems", { admin: true, status: "hidden" }))
      .items[0].id,
    "found",
  );
  await assert.rejects(
    svc.dispatch(alice, "adminAudit", {}),
    err("permission-denied"),
  );
});
