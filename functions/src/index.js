const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentWritten,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { makeService } = require("./service");
const { DomainError, lock } = require("./domain");
initializeApp();
const db = getFirestore(),
  service = makeService(db);
const encode = (v) =>
  v?.toDate
    ? v.toDate().toISOString()
    : Array.isArray(v)
      ? v.map(encode)
      : v && typeof v === "object"
        ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)]))
        : v;
exports.api = onCall(
  { region: "asia-east1", timeoutSeconds: 120, maxInstances: 10 },
  async (req) => {
    try {
      return encode(
        await service.dispatch(
          req.auth
            ? { uid: req.auth.uid, admin: req.auth.token.admin === true }
            : null,
          req.data?.op,
          req.data?.payload ?? {},
        ),
      );
    } catch (e) {
      if (e instanceof DomainError) throw new HttpsError(e.code, e.message);
      console.error(e);
      throw new HttpsError(
        "internal",
        "Үйлдлийг гүйцэтгэж чадсангүй. Дахин оролдоно уу.",
      );
    }
  },
);
exports.matchNewItems = onDocumentWritten(
  {
    document: "items/{id}",
    region: "asia-east1",
    timeoutSeconds: 540,
    memory: "1GiB",
    retry: true,
  },
  async (event) => {
    const before = event.data?.before.data(),
      after = event.data?.after.data();
    if (!after) return;
    if (
      before &&
      ["title", "description", "category", "district", "placeName"].every(
        (k) => before[k] === after[k],
      ) &&
      before.eventDate?.toMillis() === after.eventDate?.toMillis()
    )
      return;
    await service.matchNotifications(event.params.id);
  },
);
exports.expireIdleItems = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Ulaanbaatar",
    region: "asia-east1",
    timeoutSeconds: 540,
  },
  async () => {
    for (let p = 0; p < 100; p++) {
      if ((await service.expire()).processed < 100) break;
    }
  },
);
exports.pushNotifications = onDocumentCreated(
  { document: "notifications/{id}", region: "asia-east1" },
  async (e) => {
    const n = e.data?.data();
    if (!n) return;
    const all = await db
      .collection("deviceTokens")
      .where("uid", "==", n.recipientId)
      .get();
    for (let offset = 0; offset < all.size; offset += 500) {
      const page = all.docs.slice(offset, offset + 500),
        r = await getMessaging().sendEachForMulticast({
          tokens: page.map((d) => d.data().token),
          notification: {
            title: "Оллоо",
            body: "Шинэ мэдэгдэл ирлээ. Аппаа нээнэ үү.",
          },
          data: {
            refType: n.refType,
            refId: n.refId,
            notificationId: e.params.id,
          },
        });
      await Promise.all(
        r.responses.map((x, i) =>
          !x.success &&
          [
            "messaging/invalid-registration-token",
            "messaging/registration-token-not-registered",
          ].includes(x.error?.code)
            ? page[i].ref.delete()
            : Promise.resolve(),
        ),
      );
    }
  },
);
