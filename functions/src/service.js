const { Timestamp, FieldPath } = require("firebase-admin/firestore");
const D = require("./domain");
const catalog = require("./catalog.json");
function makeService(db, { now = () => new Date() } = {}) {
  const time = () => Timestamp.fromDate(now()),
    ref = (c, id) => db.collection(c).doc(D.id(id));
  const auth = (a) => {
    if (!a?.uid) D.fail("unauthenticated", "Нэвтэрнэ үү.");
    return a.uid;
  };
  const admin = (a) => {
    auth(a);
    if (a.admin !== true)
      D.fail("permission-denied", "Админы эрх шаардлагатай.");
  };
  const data = (s) => {
    if (!s.exists) D.fail("not-found", "Мэдээлэл олдсонгүй.");
    return { id: s.id, ...s.data() };
  };
  const publicItem = (i) =>
    Object.fromEntries(
      [
        "id",
        "ownerId",
        "type",
        "title",
        "description",
        "category",
        "district",
        "placeName",
        "eventDate",
        "createdAt",
        "updatedAt",
        "status",
        "isHidden",
        "imagePaths",
        "verifiedClaimId",
        "returnedAt",
      ]
        .filter((k) => i[k] !== undefined)
        .map((k) => [k, i[k]]),
    );
  const audit = (tx, actor, action, targetId, extra = {}) =>
    tx.set(db.collection("auditLogs").doc(), {
      actorId: actor,
      action,
      targetId,
      ...extra,
      createdAt: time(),
    });
  const notify = (tx, recipientId, type, title, body, refType, refId, key) =>
    tx.set(
      key ? ref("notifications", key) : db.collection("notifications").doc(),
      {
        recipientId,
        type,
        title,
        body,
        refType,
        refId,
        isRead: false,
        createdAt: time(),
      },
    );
  const lockRef = (c) => ref("claimLocks", D.lock(c.claimantId, c.itemId));
  const visible = (i) => {
    if (i.isHidden || i.isDeleted)
      D.fail("failed-precondition", "Зар нуугдсан эсвэл устсан.");
  };
  function input(p, uid, itemId) {
    if (!["lost", "found"].includes(p.type))
      D.fail("invalid-argument", "Зарын төрөл буруу.");
    const eventDate = D.text(p.eventDate, "Огноо", 10, 10);
    D.range({ from: eventDate });
    if (
      eventDate >
        new Date(now().getTime() + 8 * 3600000).toISOString().slice(0, 10) ||
      eventDate < "2000-01-01"
    )
      D.fail("invalid-argument", "Огноо буруу.");
    if (
      !catalog.categories.includes(p.category) ||
      !catalog.districts.includes(p.district)
    )
      D.fail("invalid-argument", "Ангилал эсвэл дүүрэг буруу.");
    const v = {
      type: p.type,
      title: D.text(p.title, "Нэр", 2, 120),
      description: D.text(p.description, "Тайлбар", 5, 2000),
      category: D.text(p.category, "Ангилал", 1, 80),
      district: D.text(p.district, "Дүүрэг", 1, 80),
      placeName: D.text(p.placeName, "Газрын нэр", 2, 120),
      eventDate: Timestamp.fromDate(new Date(eventDate)),
      imagePaths: D.media(p.imagePaths, uid, itemId, "items", 5),
    };
    v.searchTokens = D.tokens(v.title, v.description);
    return {
      fields: v,
      secretDetail: D.text(p.secretDetail, "Нууц онцлог", 3, 1000),
    };
  }
  async function createItem(a, p) {
    const uid = auth(a),
      itemId = D.id(p.id),
      v = input(p, uid, itemId);
    await db.runTransaction(async (tx) => {
      const [old, profile] = await Promise.all([
        tx.get(ref("items", itemId)),
        tx.get(ref("privateProfiles", uid)),
      ]);
      if (old.exists) D.fail("already-exists", "Зар аль хэдийн хадгалагдсан.");
      if (!profile.exists)
        D.fail("failed-precondition", "Профайлаа гүйцээнэ үү.");
      tx.create(ref("items", itemId), {
        ...v.fields,
        ownerId: uid,
        status: "open",
        isHidden: false,
        isDeleted: false,
        pendingCount: 0,
        disputeCount: 0,
        verifiedClaimId: null,
        createdAt: time(),
        updatedAt: time(),
      });
      tx.create(ref("itemSecrets", itemId), {
        ownerId: uid,
        secretDetail: v.secretDetail,
        createdAt: time(),
      });
      audit(tx, uid, "item.create", itemId);
    });
    return { id: itemId };
  }
  async function updateItem(a, p) {
    const uid = auth(a),
      v = input(p, uid, D.id(p.id));
    await db.runTransaction(async (tx) => {
      const i = data(await tx.get(ref("items", p.id)));
      if (i.ownerId !== uid)
        D.fail("permission-denied", "Зөвхөн өөрийн зарыг засна.");
      visible(i);
      if (
        !["open", "claimed"].includes(i.status) ||
        i.type !== p.type ||
        D.expired(i, now())
      )
        D.fail("failed-precondition", "Баталгаажаагүй идэвхтэй зарыг засна.");
      tx.update(ref("items", p.id), { ...v.fields, updatedAt: time() });
      tx.set(
        ref("itemSecrets", p.id),
        { ownerId: uid, secretDetail: v.secretDetail, updatedAt: time() },
        { merge: true },
      );
      audit(tx, uid, "item.update", p.id);
    });
    return { ok: true };
  }
  async function deleteItem(a, p) {
    const uid = auth(a);
    await db.runTransaction(async (tx) => {
      const i = data(await tx.get(ref("items", p.id))),
        claims = await tx.get(
          db
            .collection("claims")
            .where("itemId", "==", p.id)
            .where("status", "in", ["pending", "verified", "disputed"]),
        );
      if (i.ownerId !== uid)
        D.fail("permission-denied", "Өөрийн зарыг устгана.");
      if (
        !claims.empty ||
        ["verified", "returned"].includes(i.status) ||
        i.disputeCount > 0
      )
        D.fail(
          "failed-precondition",
          "Идэвхтэй нэхэмжлэл, хүлээлцсэн түүхтэй зарыг устгахгүй.",
        );
      tx.update(ref("items", p.id), {
        isHidden: true,
        isDeleted: true,
        updatedAt: time(),
      });
      audit(tx, uid, "item.delete", p.id);
    });
    return { ok: true };
  }
  async function getItem(a, p) {
    const i = data(await ref("items", p.id).get());
    if ((i.isHidden || i.isDeleted) && a?.uid !== i.ownerId && !a?.admin)
      D.fail("not-found", "Зар олдсонгүй.");
    const r = { item: publicItem(i) };
    if (a?.uid === i.ownerId || a?.admin === true)
      r.secretDetail =
        (await ref("itemSecrets", i.id).get()).data()?.secretDetail ?? "";
    return r;
  }
  async function listItems(a, p) {
    D.range(p);
    let q = db.collection("items");
    if (p.ownerOnly) q = q.where("ownerId", "==", auth(a));
    else if (p.admin) admin(a);
    else
      q = q
        .where("isHidden", "==", false)
        .where(
          "status",
          "in",
          p.status ? [p.status] : ["open", "claimed", "verified"],
        );
    if ((p.ownerOnly || p.admin) && p.status && p.status !== "hidden")
      q = q.where("status", "==", p.status);
    for (const k of ["type", "category", "district"])
      if (p[k]) q = q.where(k, "==", D.text(p[k], k, 1, 80));
    const terms = D.words(D.text(p.query ?? "", "Хайлт", 0, 160));
    if (terms.length) q = q.where("searchTokens", "array-contains", terms[0]);
    if (p.from)
      q = q.where("eventDate", ">=", Timestamp.fromDate(new Date(p.from)));
    if (p.to)
      q = q.where("eventDate", "<=", Timestamp.fromDate(new Date(p.to)));
    if (p.from || p.to) q = q.orderBy("eventDate", "desc");
    q = q.orderBy("createdAt", "desc").orderBy(FieldPath.documentId(), "desc");
    if (p.cursor) {
      const cur = await ref("items", p.cursor).get();
      if (cur.exists) q = q.startAfter(cur);
    }
    const limit = Math.min(50, Math.max(1, Number(p.limit) || 20));
    let rows = [],
      last = null,
      more = false,
      count = 0;
    while (rows.length < limit && count < 2000) {
      const batch = await q.limit(100).get();
      if (batch.empty) {
        more = false;
        break;
      }
      let used = 0;
      for (const doc of batch.docs) {
        last = doc;
        count++;
        used++;
        const i = { id: doc.id, ...doc.data() };
        if (
          i.isDeleted ||
          (p.status === "hidden" && !i.isHidden) ||
          (!p.ownerOnly && !p.admin && D.expired(i, now()))
        )
          continue;
        const ts = i.searchTokens ?? D.tokens(i.title, i.description);
        if (terms.every((w) => ts.includes(w))) rows.push(publicItem(i));
        if (rows.length >= limit) break;
      }
      more = used < batch.size || batch.size === 100;
      if (rows.length >= limit || batch.size < 100) break;
      q = q.startAfter(last);
    }
    return { items: rows, cursor: more ? last?.id : null, hasMore: more };
  }
  async function createClaim(a, p) {
    const uid = auth(a),
      claimId = D.id(p.id),
      answer = D.text(p.answer, "Нууц хариулт", 10, 500),
      contents = D.text(p.contents ?? "", "Нэмэлт тайлбар", 0, 300),
      proofPaths = D.media(p.proofPaths, uid, claimId, "claims", 3),
      lr = ref("claimLocks", D.lock(uid, p.itemId));
    await db.runTransaction(async (tx) => {
      const [is, ls, cs, profile] = await Promise.all([
        tx.get(ref("items", p.itemId)),
        tx.get(lr),
        tx.get(ref("claims", claimId)),
        tx.get(ref("privateProfiles", uid)),
      ]);
      const i = data(is);
      visible(i);
      if (
        i.type !== "found" ||
        i.ownerId === uid ||
        !["open", "claimed"].includes(i.status) ||
        D.expired(i, now()) ||
        i.verifiedClaimId
      )
        D.fail("failed-precondition", "Энэ зарыг нэхэмжлэх боломжгүй.");
      if (ls.data()?.active || cs.exists)
        D.fail("already-exists", "Идэвхтэй нэхэмжлэл байна.");
      if (!profile.exists)
        D.fail("failed-precondition", "Профайлаа гүйцээнэ үү.");
      if ((i.pendingCount ?? 0) >= 50)
        D.fail("resource-exhausted", "Олон нэхэмжлэл ирсэн байна.");
      tx.create(ref("claims", claimId), {
        itemId: i.id,
        itemTitle: i.title,
        ownerId: i.ownerId,
        claimantId: uid,
        answer,
        contents,
        proofPaths,
        status: "pending",
        createdAt: time(),
        updatedAt: time(),
      });
      tx.set(lr, { claimId, active: true });
      tx.update(is.ref, {
        pendingCount: (i.pendingCount ?? 0) + 1,
        status: "claimed",
        updatedAt: time(),
      });
      notify(
        tx,
        i.ownerId,
        "claim_received",
        "Шинэ нэхэмжлэл",
        i.title,
        "claim",
        claimId,
      );
      audit(tx, uid, "claim.create", claimId);
    });
    return { id: claimId };
  }
  async function getClaim(a, p) {
    auth(a);
    const c = data(await ref("claims", p.id).get());
    if (a.uid !== c.ownerId && a.uid !== c.claimantId && !a.admin)
      D.fail("permission-denied", "Нэхэмжлэлд хандах эрхгүй.");
    const i = data(await ref("items", c.itemId).get()),
      r = { claim: c, item: publicItem(i) };
    if (a.uid === c.ownerId || a.admin)
      r.secretDetail =
        (await ref("itemSecrets", i.id).get()).data()?.secretDetail ?? "";
    if (
      c.status === "verified" &&
      i.verifiedClaimId === c.id &&
      ["verified", "returned"].includes(i.status) &&
      !i.isHidden &&
      [c.ownerId, c.claimantId].includes(a.uid)
    ) {
      const pick = (s) => {
        const v = s.data() ?? {};
        return {
          name: v.name ?? "",
          email: v.email ?? "",
          phone: v.phone ?? "",
        };
      };
      r.contacts = {
        owner: pick(await ref("privateProfiles", c.ownerId).get()),
        claimant: pick(await ref("privateProfiles", c.claimantId).get()),
      };
    }
    return r;
  }
  function verify(tx, c, i, pending, actor) {
    tx.update(ref("claims", c.id), {
      status: "verified",
      decisionReason: "",
      updatedAt: time(),
    });
    tx.set(lockRef(c), { claimId: c.id, active: true });
    tx.update(ref("items", i.id), {
      status: "verified",
      verifiedClaimId: c.id,
      pendingCount: 0,
      updatedAt: time(),
    });
    for (const doc of pending.docs) {
      if (doc.id === c.id) continue;
      const x = { id: doc.id, ...doc.data() };
      tx.update(doc.ref, {
        status: "rejected",
        decisionReason: "Өөр нэхэмжлэл баталгаажсан.",
        updatedAt: time(),
      });
      tx.set(lockRef(x), { claimId: x.id, active: false });
      notify(
        tx,
        x.claimantId,
        "claim_rejected",
        "Нэхэмжлэл татгалзагдлаа",
        "Өөр эзэмшигч баталгаажсан.",
        "claim",
        x.id,
      );
    }
    for (const uid of [c.ownerId, c.claimantId])
      notify(
        tx,
        uid,
        "claim_verified",
        "Нэхэмжлэл баталгаажлаа",
        i.title,
        "claim",
        c.id,
      );
    audit(tx, actor, "claim.verify", c.id);
  }
  async function decide(a, p) {
    const uid = auth(a),
      reason = p.approve ? "" : D.text(p.reason, "Шалтгаан", 5, 300);
    await db.runTransaction(async (tx) => {
      const c = data(await tx.get(ref("claims", p.id))),
        i = data(await tx.get(ref("items", c.itemId))),
        pending = await tx.get(
          db
            .collection("claims")
            .where("itemId", "==", i.id)
            .where("status", "==", "pending"),
        );
      if (c.ownerId !== uid)
        D.fail("permission-denied", "Зар эзэмшигч шийдвэрлэнэ.");
      visible(i);
      if (
        c.status !== "pending" ||
        !["open", "claimed"].includes(i.status) ||
        i.verifiedClaimId ||
        D.expired(i, now())
      )
        D.fail("failed-precondition", "Энэ хүсэлтийг шийдвэрлэх боломжгүй.");
      if (p.approve) verify(tx, c, i, pending, uid);
      else {
        tx.update(ref("claims", c.id), {
          status: "rejected",
          decisionReason: reason,
          updatedAt: time(),
        });
        tx.set(lockRef(c), { claimId: c.id, active: false });
        tx.update(ref("items", i.id), {
          pendingCount: Math.max(0, pending.size - 1),
          status: pending.size > 1 ? "claimed" : "open",
          updatedAt: time(),
        });
        notify(
          tx,
          c.claimantId,
          "claim_rejected",
          "Нэхэмжлэл татгалзагдлаа",
          reason,
          "claim",
          c.id,
        );
        audit(tx, uid, "claim.reject", c.id, { reason });
      }
    });
    return { ok: true };
  }
  async function withdraw(a, p) {
    const uid = auth(a);
    await db.runTransaction(async (tx) => {
      const c = data(await tx.get(ref("claims", p.id))),
        i = data(await tx.get(ref("items", c.itemId)));
      if (c.claimantId !== uid)
        D.fail("permission-denied", "Өөрийн хүсэлтийг буцаана.");
      if (c.status !== "pending")
        D.fail(
          "failed-precondition",
          "Зөвхөн хүлээгдэж буй хүсэлтийг буцаана.",
        );
      const n = Math.max(0, (i.pendingCount ?? 1) - 1);
      tx.update(ref("claims", c.id), {
        status: "withdrawn",
        updatedAt: time(),
      });
      tx.set(lockRef(c), { claimId: c.id, active: false });
      tx.update(ref("items", i.id), {
        pendingCount: n,
        status: i.status === "claimed" ? (n ? "claimed" : "open") : i.status,
        updatedAt: time(),
      });
      notify(
        tx,
        c.ownerId,
        "claim_withdrawn",
        "Нэхэмжлэл буцаагдлаа",
        i.title,
        "claim",
        c.id,
      );
      audit(tx, uid, "claim.withdraw", c.id);
    });
    return { ok: true };
  }
  async function handover(a, p) {
    const uid = auth(a),
      place = D.text(p.place, "Уулзах газар", 3, 120),
      note = D.text(p.note ?? "", "Тайлбар", 0, 200),
      meetAt = new Date(p.meetAt);
    if (!Number.isFinite(meetAt.getTime()) || meetAt <= now())
      D.fail("invalid-argument", "Ирээдүйн цаг сонгоно уу.");
    await db.runTransaction(async (tx) => {
      const c = data(await tx.get(ref("claims", p.id))),
        i = data(await tx.get(ref("items", c.itemId)));
      if (c.ownerId !== uid)
        D.fail("permission-denied", "Зар эзэмшигч товлоно.");
      visible(i);
      if (
        c.status !== "verified" ||
        i.status !== "verified" ||
        i.verifiedClaimId !== c.id ||
        c.handover
      )
        D.fail("failed-precondition", "Уулзалт товлох боломжгүй.");
      tx.update(ref("claims", c.id), {
        handover: { place, note, meetAt: Timestamp.fromDate(meetAt) },
        updatedAt: time(),
      });
      notify(
        tx,
        c.claimantId,
        "handover",
        "Хүлээлцэх уулзалт товлогдлоо",
        place,
        "claim",
        c.id,
      );
      audit(tx, uid, "handover.schedule", c.id);
    });
    return { ok: true };
  }
  async function returned(a, p) {
    const uid = auth(a);
    await db.runTransaction(async (tx) => {
      const i = data(await tx.get(ref("items", p.id)));
      if (i.ownerId !== uid)
        D.fail("permission-denied", "Зар эзэмшигч тэмдэглэнэ.");
      visible(i);
      if (i.status !== "verified" || !i.verifiedClaimId)
        D.fail("failed-precondition", "Баталгаажсан нэхэмжлэл шаардлагатай.");
      const c = data(await tx.get(ref("claims", i.verifiedClaimId)));
      if (c.status !== "verified" || c.itemId !== i.id)
        D.fail("failed-precondition", "Нэхэмжлэл тохирохгүй.");
      tx.update(ref("items", i.id), {
        status: "returned",
        returnedAt: time(),
        updatedAt: time(),
      });
      for (const u of [uid, c.claimantId])
        notify(
          tx,
          u,
          "item_returned",
          "Эд зүйл буцаан олгогдлоо",
          i.title,
          "claim",
          c.id,
        );
      audit(tx, uid, "item.return", i.id);
    });
    return { ok: true };
  }
  async function dispute(a, p) {
    const uid = auth(a),
      reason = D.text(p.reason, "Маргааны үндэслэл", 10, 2000),
      proofPaths = D.media(p.proofPaths, uid, D.id(p.claimId), "claims", 3);
    await db.runTransaction(async (tx) => {
      const c = data(await tx.get(ref("claims", p.claimId))),
        i = data(await tx.get(ref("items", c.itemId))),
        old = await tx.get(ref("disputes", c.id));
      if (c.claimantId !== uid)
        D.fail("permission-denied", "Өөрийн хүсэлтэд маргана.");
      if (
        c.status !== "rejected" ||
        old.exists ||
        i.isDeleted ||
        i.status === "returned"
      )
        D.fail("failed-precondition", "Маргаан үүсгэх боломжгүй.");
      tx.create(ref("disputes", c.id), {
        claimId: c.id,
        itemId: i.id,
        itemTitle: i.title,
        ownerId: i.ownerId,
        openedBy: uid,
        reason,
        proofPaths,
        status: "open",
        createdAt: time(),
      });
      tx.update(ref("claims", c.id), { status: "disputed", updatedAt: time() });
      tx.set(lockRef(c), { claimId: c.id, active: true });
      tx.update(ref("items", i.id), {
        disputeCount: (i.disputeCount ?? 0) + 1,
        updatedAt: time(),
      });
      audit(tx, uid, "dispute.create", c.id);
    });
    return { id: p.claimId };
  }
  async function resolve(a, p) {
    admin(a);
    const note = D.text(p.note, "Шийдвэрийн үндэслэл", 10, 2000);
    await db.runTransaction(async (tx) => {
      const d = data(await tx.get(ref("disputes", p.id))),
        c = data(await tx.get(ref("claims", d.claimId))),
        i = data(await tx.get(ref("items", c.itemId))),
        pending = await tx.get(
          db
            .collection("claims")
            .where("itemId", "==", i.id)
            .where("status", "==", "pending"),
        ),
        previous =
          i.verifiedClaimId && i.verifiedClaimId !== c.id
            ? data(await tx.get(ref("claims", i.verifiedClaimId)))
            : null;
      if (d.status !== "open" || c.status !== "disputed")
        D.fail("failed-precondition", "Маргаан шийдвэрлэгдсэн.");
      if (p.approve) {
        visible(i);
        if (!["open", "claimed", "verified"].includes(i.status))
          D.fail("failed-precondition", "Хаагдсан зарт эзэмшигч солихгүй.");
        if (previous) {
          tx.update(ref("claims", previous.id), {
            status: "rejected",
            decisionReason: note,
            updatedAt: time(),
          });
          tx.set(lockRef(previous), { claimId: previous.id, active: false });
          notify(
            tx,
            previous.claimantId,
            "claim_rejected",
            "Баталгаажуулалт цуцлагдлаа",
            note,
            "claim",
            previous.id,
          );
          audit(tx, a.uid, "claim.revoke", previous.id, { note });
        }
        verify(tx, c, i, pending, a.uid);
      } else {
        tx.update(ref("claims", c.id), {
          status: "rejected",
          decisionReason: note,
          updatedAt: time(),
        });
        tx.set(lockRef(c), { claimId: c.id, active: false });
      }
      tx.update(ref("disputes", d.id), {
        status: "resolved",
        decision: p.approve ? "approve_claimant" : "uphold_rejection",
        note,
        resolvedBy: a.uid,
        resolvedAt: time(),
      });
      tx.update(ref("items", i.id), {
        disputeCount: Math.max(0, (i.disputeCount ?? 1) - 1),
        updatedAt: time(),
      });
      for (const u of [c.ownerId, c.claimantId])
        notify(
          tx,
          u,
          "dispute_resolved",
          "Маргаан шийдвэрлэгдлээ",
          note,
          "claim",
          c.id,
        );
      audit(tx, a.uid, "dispute.resolve", d.id, { note, approve: !!p.approve });
    });
    return { ok: true };
  }
  async function list(a, p, collection, field) {
    auth(a);
    let q = db.collection(collection);
    if (field) q = q.where(field, "==", a.uid);
    else admin(a);
    if (p.status) q = q.where("status", "==", p.status);
    if (collection === "notifications" && p.unread)
      q = q.where("isRead", "==", false);
    q = q.orderBy("createdAt", "desc");
    if (p.cursor) {
      const cur = await ref(collection, p.cursor).get();
      if (cur.exists) q = q.startAfter(cur);
    }
    const rows = await q.limit(30).get();
    return {
      rows: rows.docs.map(data),
      cursor: rows.size === 30 ? rows.docs.at(-1).id : null,
    };
  }
  async function matches(a, p) {
    auth(a);
    const source = data(await ref("items", p.id).get());
    if (source.ownerId !== a.uid && !a.admin)
      D.fail("permission-denied", "Өөрийн зарын тохирлыг харна.");
    visible(source);
    const candidates = await db
      .collection("items")
      .where("isHidden", "==", false)
      .where("type", "==", source.type === "lost" ? "found" : "lost")
      .where("status", "in", ["open", "claimed"])
      .get();
    const rows = candidates.docs
      .map(data)
      .filter((i) => !i.isDeleted && !D.expired(i, now()))
      .map((i) => ({ item: publicItem(i), ...D.score(source, i) }))
      .filter((i) => i.score > 0)
      .sort((a, b) => b.score - a.score || a.item.id.localeCompare(b.item.id));
    const start = p.cursor
      ? Math.max(0, rows.findIndex((r) => r.item.id === p.cursor) + 1)
      : 0;
    return {
      matches: rows.slice(start, start + 30),
      cursor: start + 30 < rows.length ? rows[start + 29].item.id : null,
    };
  }
  async function matchNotifications(itemId) {
    const source = await ref("items", itemId).get();
    if (!source.exists) return;
    const i = data(source);
    if (
      i.isHidden ||
      i.isDeleted ||
      !["open", "claimed"].includes(i.status) ||
      D.expired(i, now())
    )
      return;
    const all = await db
      .collection("items")
      .where("isHidden", "==", false)
      .where("type", "==", i.type === "lost" ? "found" : "lost")
      .where("status", "in", ["open", "claimed"])
      .get();
    const writes = [];
    for (const doc of all.docs) {
      const other = data(doc);
      if (
        other.ownerId === i.ownerId ||
        other.isDeleted ||
        D.expired(other, now()) ||
        D.score(i, other).score < 60
      )
        continue;
      for (const [target, source] of [
        [i, other],
        [other, i],
      ])
        writes.push({
          key: D.lock(...[i.id, other.id].sort(), target.ownerId),
          target,
          source,
        });
    }
    for (let offset = 0; offset < writes.length; offset += 400) {
      const part = writes.slice(offset, offset + 400),
        existing = await db.getAll(
          ...part.map((x) => ref("notifications", x.key)),
        ),
        b = db.batch();
      for (let n = 0; n < part.length; n++) {
        if (existing[n].exists) continue;
        const x = part[n];
        notify(
          b,
          x.target.ownerId,
          "match",
          "Тохирох шинэ зар",
          x.source.title,
          "item",
          x.source.id,
          x.key,
        );
      }
      await b.commit();
    }
  }
  async function expire() {
    const all = await db
      .collection("items")
      .where("status", "in", ["open", "claimed"])
      .where(
        "updatedAt",
        "<=",
        Timestamp.fromDate(new Date(now().getTime() - 30 * 86400000)),
      )
      .limit(100)
      .get();
    for (const doc of all.docs)
      await db.runTransaction(async (tx) => {
        const i = data(await tx.get(doc.ref)),
          pending = await tx.get(
            db
              .collection("claims")
              .where("itemId", "==", i.id)
              .where("status", "==", "pending"),
          );
        if (!D.expired(i, now())) return;
        tx.update(doc.ref, {
          status: "expired",
          pendingCount: 0,
          updatedAt: time(),
        });
        for (const x of pending.docs) {
          const c = data(x);
          tx.update(x.ref, {
            status: "rejected",
            decisionReason: "Зарын хугацаа дууссан.",
            updatedAt: time(),
          });
          tx.set(lockRef(c), { claimId: c.id, active: false });
          notify(
            tx,
            c.claimantId,
            "claim_rejected",
            "Зарын хугацаа дууслаа",
            i.title,
            "claim",
            c.id,
          );
        }
        notify(
          tx,
          i.ownerId,
          "expired",
          "Зарын хугацаа дууслаа",
          i.title,
          "item",
          i.id,
        );
        audit(tx, "system", "item.expire", i.id);
      });
    return { processed: all.size };
  }
  const ranged = (q, p, f) => {
    if (p.from)
      q = q.where(
        f,
        ">=",
        Timestamp.fromDate(new Date(p.from + "T00:00:00+08:00")),
      );
    if (p.to)
      q = q.where(
        f,
        "<",
        Timestamp.fromDate(
          new Date(new Date(p.to + "T00:00:00+08:00").getTime() + 86400000),
        ),
      );
    return q;
  };
  async function stats(a) {
    admin(a);
    const r = {};
    for (const c of ["items", "privateProfiles", "claims", "disputes"])
      r[c] = (
        await (
          c === "items"
            ? db.collection(c).where("isDeleted", "==", false)
            : db.collection(c)
        )
          .count()
          .get()
      ).data().count;
    for (const s of ["open", "claimed", "verified", "returned", "expired"])
      r[s] = (
        await db
          .collection("items")
          .where("status", "==", s)
          .where("isHidden", "==", false)
          .count()
          .get()
      ).data().count;
    r.openDisputes = (
      await db
        .collection("disputes")
        .where("status", "==", "open")
        .count()
        .get()
    ).data().count;
    return r;
  }
  async function users(a, p) {
    admin(a);
    const all = await db
        .collection("privateProfiles")
        .orderBy("createdAt", "desc")
        .get(),
      query = D.text(p.query ?? "", "Хайлт", 0, 160).toLowerCase();
    let rows = all.docs
      .map(data)
      .filter(
        (u) =>
          (!p.role || (u.role ?? "user") === p.role) &&
          `${u.name} ${u.email} ${u.phone} ${u.id}`
            .toLowerCase()
            .includes(query),
      );
    if (p.cursor)
      rows = rows.slice(
        Math.max(0, rows.findIndex((u) => u.id === p.cursor) + 1),
      );
    const page = rows.slice(0, 30);
    await Promise.all(
      page.map(async (u) => {
        u.itemCount = (
          await db
            .collection("items")
            .where("ownerId", "==", u.id)
            .where("isDeleted", "==", false)
            .count()
            .get()
        ).data().count;
        u.claimCount = (
          await db
            .collection("claims")
            .where("claimantId", "==", u.id)
            .count()
            .get()
        ).data().count;
      }),
    );
    return { rows: page, cursor: rows.length > 30 ? page.at(-1).id : null };
  }
  async function auditList(a, p) {
    admin(a);
    D.range(p);
    const [logs, profiles] = await Promise.all([
      ranged(db.collection("auditLogs"), p, "createdAt")
        .orderBy("createdAt", "desc")
        .get(),
      db.collection("privateProfiles").select("name").get(),
    ]);
    const names = Object.fromEntries(
        profiles.docs.map((d) => [d.id, d.data().name]),
      ),
      query = D.text(p.query ?? "", "Хайлт", 0, 160).toLowerCase();
    let rows = logs.docs
      .map(data)
      .map((v) => ({ ...v, actorName: names[v.actorId] ?? v.actorId }))
      .filter(
        (v) =>
          (!p.action || v.action === p.action) &&
          `${v.actorName} ${v.actorId} ${v.action} ${v.targetId}`
            .toLowerCase()
            .includes(query),
      );
    if (p.cursor)
      rows = rows.slice(
        Math.max(0, rows.findIndex((r) => r.id === p.cursor) + 1),
      );
    return {
      rows: rows.slice(0, 30),
      cursor: rows.length > 30 ? rows[29].id : null,
    };
  }
  async function reports(a, p) {
    admin(a);
    D.range(p);
    const [returned, items, claims, disputes] = await Promise.all([
      ranged(
        db.collection("items").where("status", "==", "returned"),
        p,
        "returnedAt",
      ).get(),
      ranged(db.collection("items"), p, "eventDate").get(),
      ranged(db.collection("claims"), p, "createdAt").get(),
      ranged(db.collection("disputes"), p, "createdAt").get(),
    ]);
    const summary = { "Нийт буцаан олголт": returned.size },
      insights = {
        totals: {
          Зар: items.docs.filter((d) => !d.data().isDeleted).length,
          Нэхэмжлэл: claims.size,
          "Нээлттэй маргаан": disputes.docs.filter(
            (d) => d.data().status === "open",
          ).length,
        },
        categories: {},
        itemStates: {},
        claimStates: {},
        trend: {},
      };
    const add = (o, k) => (o[k] = (o[k] ?? 0) + 1);
    for (const doc of returned.docs)
      add(
        summary,
        new Date(D.millis(doc.data().returnedAt) + 8 * 3600000)
          .toISOString()
          .slice(0, 7),
      );
    for (const doc of items.docs) {
      const i = doc.data();
      if (i.isDeleted) continue;
      add(insights.categories, i.category);
      add(insights.itemStates, i.isHidden ? "hidden" : i.status);
      add(
        insights.trend,
        new Date(D.millis(i.eventDate) + 8 * 3600000)
          .toISOString()
          .slice(0, 7) +
          " · " +
          i.type,
      );
    }
    for (const c of claims.docs) add(insights.claimStates, c.data().status);
    let rows = returned.docs
      .map(data)
      .sort((a, b) => D.millis(b.returnedAt) - D.millis(a.returnedAt));
    if (p.cursor)
      rows = rows.slice(
        Math.max(0, rows.findIndex((r) => r.id === p.cursor) + 1),
      );
    return {
      rows: rows.slice(0, 50).map(publicItem),
      cursor: rows.length > 50 ? rows[49].id : null,
      summary,
      insights,
    };
  }
  async function exportReport(a, p) {
    admin(a);
    D.range(p);
    const items = p.scope === "items";
    let q = db.collection("items");
    if (!items) q = q.where("status", "==", "returned");
    const docs = await ranged(q, p, items ? "eventDate" : "returnedAt").get(),
      cell = (v) =>
        '"' +
        String(v ?? "")
          .replace(/^[\s]*[=+@-]/, "'$&")
          .replaceAll('"', '""') +
        '"',
      rows = docs.docs
        .filter((d) => !d.data().isDeleted)
        .map((d) => {
          const i = d.data();
          return items
            ? [
                d.id,
                i.type,
                i.title,
                i.category,
                i.isHidden ? "hidden" : i.status,
                i.eventDate?.toDate().toISOString(),
                `${i.district} ${i.placeName}`,
              ]
            : [i.title, i.category, i.returnedAt.toDate().toISOString()];
        }),
      csv =
        "\uFEFF" +
        [
          items
            ? ["ID", "Төрөл", "Нэр", "Ангилал", "Төлөв", "Огноо", "Байршил"]
            : ["Нэр", "Ангилал", "Буцаасан огноо"],
          ...rows,
        ]
          .map((r) => r.map(cell).join(","))
          .join("\r\n"),
      path = `exports/${a.uid}/${db.collection("auditLogs").doc().id}.csv`;
    await require("firebase-admin/storage")
      .getStorage()
      .bucket()
      .file(path)
      .save(csv, {
        metadata: { contentType: "text/csv; charset=utf-8" },
        resumable: false,
      });
    return { path, count: rows.length };
  }
  async function dispatch(a, op, p = {}) {
    switch (op) {
      case "createItem":
        return createItem(a, p);
      case "updateItem":
        return updateItem(a, p);
      case "deleteItem":
        return deleteItem(a, p);
      case "getItem":
        return getItem(a, p);
      case "listItems":
        return listItems(a, p);
      case "createClaim":
        return createClaim(a, p);
      case "getClaim":
        return getClaim(a, p);
      case "decideClaim":
        return decide(a, p);
      case "withdrawClaim":
        return withdraw(a, p);
      case "scheduleHandover":
        return handover(a, p);
      case "markReturned":
        return returned(a, p);
      case "createDispute":
        return dispute(a, p);
      case "resolveDispute":
        return resolve(a, p);
      case "matches":
        return matches(a, p);
      case "myClaims":
        return list(a, p, "claims", "claimantId");
      case "incomingClaims":
        return list(a, p, "claims", "ownerId");
      case "notifications":
        return list(a, p, "notifications", "recipientId");
      case "adminDisputes":
        return list(a, p, "disputes");
      case "adminUsers":
        return users(a, p);
      case "adminAudit":
        return auditList(a, p);
      case "adminReports":
        return reports(a, p);
      case "adminReportExport":
        return exportReport(a, p);
      case "adminStats":
        return stats(a);
      case "getDispute": {
        admin(a);
        const d = data(await ref("disputes", p.id).get());
        return { dispute: d, ...(await getClaim(a, { id: d.claimId })) };
      }
      case "updateProfile": {
        const uid = auth(a),
          name = D.text(p.name, "Нэр", 1, 80),
          phone = D.text(p.phone, "Утас", 8, 8);
        if (!/^\d{8}$/.test(phone))
          D.fail("invalid-argument", "Утас 8 оронтой байна.");
        await ref("privateProfiles", uid).update({
          name,
          phone,
          updatedAt: time(),
        });
        return { ok: true };
      }
      case "hideItem": {
        admin(a);
        const reason = D.text(p.reason, "Үндэслэл", 5, 300);
        await db.runTransaction(async (tx) => {
          const i = data(await tx.get(ref("items", p.id)));
          if (i.isDeleted)
            D.fail("failed-precondition", "Устсан зарыг сэргээхгүй.");
          tx.update(ref("items", p.id), {
            isHidden: p.hidden !== false,
            updatedAt: time(),
          });
          audit(
            tx,
            a.uid,
            p.hidden === false ? "item.unhide" : "item.hide",
            p.id,
            { reason },
          );
        });
        return { ok: true };
      }
      case "markRead": {
        const uid = auth(a);
        await db.runTransaction(async (tx) => {
          const n = data(await tx.get(ref("notifications", p.id)));
          if (n.recipientId !== uid)
            D.fail("permission-denied", "Өөрийн мэдэгдлийг уншина.");
          tx.update(ref("notifications", p.id), { isRead: true });
        });
        return { ok: true };
      }
      case "markAllRead": {
        const uid = auth(a),
          all = await db
            .collection("notifications")
            .where("recipientId", "==", uid)
            .where("isRead", "==", false)
            .get();
        for (let n = 0; n < all.size; n += 400) {
          const b = db.batch();
          for (const d of all.docs.slice(n, n + 400))
            b.update(d.ref, { isRead: true });
          await b.commit();
        }
        return { updated: all.size };
      }
      case "registerDevice":
      case "unregisterDevice": {
        const uid = auth(a),
          token = D.text(p.token, "Төхөөрөмж", 20, 4096),
          r = ref("deviceTokens", D.lock(uid, token));
        if (op === "registerDevice")
          await r.set({ uid, token, updatedAt: time() });
        else await r.delete();
        return { ok: true };
      }
      default:
        D.fail("invalid-argument", "Үйлдэл олдсонгүй.");
    }
  }
  return { dispatch, expire, matchNotifications };
}
module.exports = { makeService };
