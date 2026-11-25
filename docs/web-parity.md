# Вэб хувилбартай нийцэл

Reference: https://gitlab.com/b242270008/lost-and-found-mern.git ; өмнө уншсан commit 5468227a988628068c7d09d748073bb904f4a007. Вэб нь React MockStore/in-memory Express mock auth/data ашигладаг. Мобайл нь PDF-д заасан Firebase stack дээр жинхэнэ trusted backend ашиглана. Хоёр өгөгдлийн сан автоматаар синк болохгүй.

| Вэб урсгал | Мобайл |
|---|---|
| Auth/reset/profile/password | FirebaseAuth, profile edit, reauthentication-тай password change |
| Lost/Found CRUD, secret, photos | Callable API, itemSecrets, Storage Rules |
| Search/category/location/date | Server query + cursor + filters |
| Matching | Ижил 30/30/20/20 жин, Unicode words, буурах эрэмбэ |
| Claims/proofs/incoming/sent | Хувийн хариулт/зураг, хоёр tab |
| Verify/reject/withdraw | Trusted atomic transactions, owner/state guard |
| Verified contacts/handover/returned | Хоёр талын контактын хэсэг, цаг/газар, verified → returned |
| Dispute/admin decision | Админ нотолгоо/тайлбар/эцсийн шийдвэр, аудит |
| Notifications | Persisted read/unread, unread filter, bulk read, FCM холболт |
| Admin items/users | Moderation, status filter, role/search/counts |
| Reports/CSV/audit | Хугацаа/ангилал/төлөв/сарын задаргаа, бүх зар/буцаалтын CSV, audit search/action filter |
| Expiration | Өдөр тутмын Firebase scheduled function |

Mock user ID/header нь эрхийн баталгаа биш. Firebase Auth admin custom claim серверт шалгагдана. PDF-ийн нөхцөлөөр verified/returned болон идэвхтэй claim-тэй зарт хууль бус засвар/устгал хийхийг сервер хаана. Чат нь reference-ийн үндсэн урсгал/PDF-ийн 47 FR-д тусдаа шаардсан функц биш; verified contacts/handover хэрэгжсэн.
