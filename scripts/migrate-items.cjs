const req = require("node:module").createRequire(
  require("node:path").resolve(__dirname, "../functions/package.json"),
);
const { initializeApp } = req("firebase-admin/app"),
  { getFirestore, Timestamp } = req("firebase-admin/firestore"),
  { tokens } = require("../functions/src/domain");
(async () => {
  const p = process.argv.indexOf("--project");
  if (p < 0)
    throw Error(
      "Usage: node scripts/migrate-items.cjs --project PROJECT [--apply]",
    );
  initializeApp({ projectId: process.argv[p + 1] });
  const db = getFirestore(),
    items = await db.collection("items").get(),
    claims = await db.collection("claims").get();
  for (const doc of items.docs) {
    const i = doc.data(),
      cs = claims.docs.filter((c) => c.data().itemId === doc.id),
      v = {
        searchTokens: tokens(i.title, i.description),
        updatedAt: i.updatedAt ?? i.createdAt ?? Timestamp.now(),
        imagePaths: i.imagePaths ?? [],
        isDeleted: i.isDeleted ?? false,
        pendingCount: cs.filter((c) => c.data().status === "pending").length,
        disputeCount: cs.filter((c) => c.data().status === "disputed").length,
        verifiedClaimId:
          cs.find((c) => c.data().status === "verified")?.id ?? null,
      };
    if (process.argv.includes("--apply")) await doc.ref.update(v);
  }
  console.log(
    items.size +
      " items " +
      (process.argv.includes("--apply") ? "migrated" : "inspected (dry run)"),
  );
})().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
