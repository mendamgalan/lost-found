const { createHash } = require("node:crypto");
class DomainError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const fail = (code, message) => {
  throw new DomainError(code, message);
};
const text = (v, label, min = 1, max = 2000) => {
  if (typeof v !== "string" || v.trim().length < min || v.trim().length > max)
    fail("invalid-argument", `${label}: ${min}–${max} тэмдэгт оруулна уу.`);
  return v.trim();
};
const id = (v) => {
  v = text(v, "Дугаар", 1, 150);
  if (!/^[\w-]+$/.test(v)) fail("invalid-argument", "Дугаарын формат буруу.");
  return v;
};
const words = (v) =>
  (
    String(v ?? "")
      .toLowerCase()
      .match(/[\p{L}\p{N}]+/gu) ?? []
  ).filter((v) => v.length >= 3);
const tokens = (...v) => [
  ...new Set(
    v
      .flatMap(words)
      .flatMap((w) => [
        w,
        ...Array.from(
          { length: Math.max(0, Math.min(w.length, 30) - 2) },
          (_, i) => w.slice(0, i + 3),
        ),
      ]),
  ),
];
const millis = (v) => (v?.toMillis ? v.toMillis() : new Date(v).getTime());
const shares = (a, b) => {
  const s = new Set(words(b));
  return words(a).some((w) => s.has(w));
};
function score(a, b) {
  const breakdown = {
    category: a.category === b.category ? 30 : 0,
    location: shares(
      `${a.district} ${a.placeName}`,
      `${b.district} ${b.placeName}`,
    )
      ? 30
      : 0,
    date:
      Math.abs(millis(a.eventDate) - millis(b.eventDate)) <= 3 * 86400000
        ? 20
        : 0,
    keyword: shares(a.title, b.title) ? 20 : 0,
  };
  return {
    score: Object.values(breakdown).reduce((a, b) => a + b, 0),
    breakdown,
  };
}
const lock = (...v) =>
  createHash("sha256").update(JSON.stringify(v)).digest("hex");
const expired = (i, now = new Date()) =>
  ["open", "claimed"].includes(i.status) &&
  millis(i.updatedAt ?? i.createdAt) <= now.getTime() - 30 * 86400000;
function range(p) {
  for (const k of ["from", "to"])
    if (
      p[k] &&
      (!/^\d{4}-\d{2}-\d{2}$/.test(p[k]) ||
        !Number.isFinite(new Date(p[k]).getTime()) ||
        new Date(p[k]).toISOString().slice(0, 10) !== p[k])
    )
      fail("invalid-argument", "Огнооны формат буруу.");
  if (p.from && p.to && p.from > p.to)
    fail("invalid-argument", "Огнооны дараалал буруу.");
}
function media(v, uid, doc, kind, max) {
  if (v == null) return [];
  if (!Array.isArray(v) || v.length > max || new Set(v).size !== v.length)
    fail("invalid-argument", "Зургийн тоо буруу.");
  const prefix = `${kind}/${uid}/${doc}/`;
  for (const path of v)
    if (
      typeof path !== "string" ||
      !path.startsWith(prefix) ||
      !/^[-\w]+\.(jpg|png)$/.test(path.slice(prefix.length))
    )
      fail("permission-denied", "Зөвхөн өөрийн зураг хавсаргана.");
  return v;
}
module.exports = {
  DomainError,
  fail,
  text,
  id,
  words,
  tokens,
  millis,
  score,
  lock,
  expired,
  range,
  media,
};
