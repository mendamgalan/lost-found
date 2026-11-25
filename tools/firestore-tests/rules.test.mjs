import { before, beforeEach, after, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  serverTimestamp,
} from "firebase/firestore";
import { ref, uploadBytes, getBytes } from "firebase/storage";
let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-lost-found",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: readFileSync(
        new URL("../../firestore.rules", import.meta.url),
        "utf8",
      ),
    },
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: readFileSync(
        new URL("../../storage.rules", import.meta.url),
        "utf8",
      ),
    },
  });
});
after(() => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, value] of [
      ["items/item", { ownerId: "owner", isHidden: false, status: "open" }],
      ["itemSecrets/item", { ownerId: "owner", secretDetail: "Нууц тэмдэг" }],
      [
        "claims/c1",
        {
          ownerId: "owner",
          claimantId: "alice",
          itemId: "item",
          answer: "Нотолгоо",
        },
      ],
      [
        "privateProfiles/owner",
        { name: "Анар", email: "owner@example.test", phone: "99112233" },
      ],
      ["notifications/n1", { recipientId: "owner", isRead: false }],
    ])
      await setDoc(doc(db, path), value);
  });
});
const ctx = (uid, claims = {}) => env.authenticatedContext(uid, claims),
  db = (uid) => ctx(uid).firestore(),
  admin = () => ctx("admin", { admin: true }),
  jpeg = new Uint8Array([255, 216, 255, 0]);
test("only owner/admin read item secrets", async () => {
  await assertSucceeds(getDoc(doc(db("owner"), "itemSecrets/item")));
  await assertFails(getDoc(doc(db("alice"), "itemSecrets/item")));
  await assertSucceeds(getDoc(doc(admin().firestore(), "itemSecrets/item")));
});
test("claim proof and profile reads are participant scoped", async () => {
  await assertSucceeds(getDoc(doc(db("alice"), "claims/c1")));
  await assertFails(getDoc(doc(db("bob"), "claims/c1")));
  await assertSucceeds(getDoc(doc(db("owner"), "privateProfiles/owner")));
  await assertFails(getDoc(doc(db("alice"), "privateProfiles/owner")));
});
test("all business changes require trusted functions, including audit", async () => {
  await assertFails(
    updateDoc(doc(db("owner"), "items/item"), { status: "returned" }),
  );
  await assertFails(
    setDoc(doc(db("alice"), "claims/new"), {
      itemId: "item",
      claimantId: "alice",
      ownerId: "owner",
      status: "verified",
    }),
  );
  await assertFails(
    setDoc(doc(admin().firestore(), "auditLogs/forged"), {
      actorId: "admin",
      action: "claim.verify",
    }),
  );
});
test("profile create cannot self-assign admin", async () => {
  const a = ctx("new", { email: "new@example.test" }).firestore(),
    value = {
      name: "Шинэ",
      phone: "99112233",
      email: "new@example.test",
      consentVersion: "mvp-v1",
      consentAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    };
  await assertFails(
    setDoc(doc(a, "privateProfiles/new"), { ...value, role: "admin" }),
  );
  await assertSucceeds(setDoc(doc(a, "privateProfiles/new"), value));
  await assertFails(
    updateDoc(doc(a, "privateProfiles/new"), { role: "admin" }),
  );
});
test("notifications are private to their recipient", async () => {
  await assertSucceeds(getDoc(doc(db("owner"), "notifications/n1")));
  await assertFails(getDoc(doc(db("alice"), "notifications/n1")));
  await assertFails(
    updateDoc(doc(db("owner"), "notifications/n1"), { isRead: true }),
  );
});
test("guest browses visible items while moderation restricts hidden ones", async () => {
  await assertSucceeds(
    getDoc(doc(env.unauthenticatedContext().firestore(), "items/item")),
  );
  await env.withSecurityRulesDisabled((c) =>
    updateDoc(doc(c.firestore(), "items/item"), { isHidden: true }),
  );
  await assertFails(getDoc(doc(db("alice"), "items/item")));
  await assertSucceeds(getDoc(doc(db("owner"), "items/item")));
});
test("private proof upload and read enforce UID and participant", async () => {
  const path = "claims/alice/c1/private.jpg";
  await assertSucceeds(
    uploadBytes(ref(ctx("alice").storage(), path), jpeg, {
      contentType: "image/jpeg",
    }),
  );
  await assertFails(
    uploadBytes(ref(ctx("bob").storage(), "claims/alice/c1/forged.jpg"), jpeg, {
      contentType: "image/jpeg",
    }),
  );
  await assertSucceeds(getBytes(ref(ctx("owner").storage(), path)));
  await assertSucceeds(getBytes(ref(ctx("alice").storage(), path)));
  await assertFails(getBytes(ref(ctx("bob").storage(), path)));
  await assertSucceeds(getBytes(ref(admin().storage(), path)));
});
test("Storage rejects non-images and images at or above 5MB", async () => {
  await assertFails(
    uploadBytes(
      ref(ctx("owner").storage(), "items/owner/item/text.jpg"),
      jpeg,
      { contentType: "text/plain" },
    ),
  );
  await assertFails(
    uploadBytes(
      ref(ctx("owner").storage(), "items/owner/item/large.png"),
      new Uint8Array(5 * 1024 * 1024),
      { contentType: "image/png" },
    ),
  );
});
test("public photo access follows item moderation", async () => {
  const path = "items/owner/item/photo.jpg";
  await assertSucceeds(
    uploadBytes(ref(ctx("owner").storage(), path), jpeg, {
      contentType: "image/jpeg",
    }),
  );
  await assertSucceeds(
    getBytes(ref(env.unauthenticatedContext().storage(), path)),
  );
  await env.withSecurityRulesDisabled((c) =>
    updateDoc(doc(c.firestore(), "items/item"), { isHidden: true }),
  );
  await assertFails(
    getBytes(ref(env.unauthenticatedContext().storage(), path)),
  );
  await assertSucceeds(getBytes(ref(ctx("owner").storage(), path)));
});
test("CSV export is readable only by its owning admin", async () => {
  const path = "exports/admin/report.csv";
  await env.withSecurityRulesDisabled((c) =>
    uploadBytes(ref(c.storage(), path), new Uint8Array([65]), {
      contentType: "text/csv",
    }),
  );
  await assertSucceeds(getBytes(ref(admin().storage(), path)));
  await assertFails(
    getBytes(ref(ctx("other-admin", { admin: true }).storage(), path)),
  );
  await assertFails(getBytes(ref(ctx("alice").storage(), path)));
  await assertFails(
    uploadBytes(ref(admin().storage(), "exports/admin/forged.csv"), jpeg, {
      contentType: "text/csv",
    }),
  );
});
