# PDF-ийн 47 функционал шаардлага

Эх сурвалж: хэрэглэгчийн Mobile-biydaalt.pdf, 6-р хэсэг. W = functions/test/workflow.test.cjs; R = tools/firestore-tests/rules.test.mjs; I = functions/test/callable.integration.cjs; UI = test/. Эдгээр нь 47 тусдаа end-to-end acceptance тест гэсэн үг биш.

| ID | Функц | Кодын хэрэгжилт | Нотолгоо |
|---|---|---|---|
| FR-01 | Нэр, имэйл, нууц үгээр бүртгэх | AuthPage + ProfileGate; FirebaseAuth/privateProfiles | UI validation, R profile |
| FR-02 | Нэвтрэх | AuthPage/FirebaseAuth | UI, I JWT |
| FR-03 | Имэйлээр сэргээх | AuthPage.sendPasswordResetEmail | UI; real email acceptance үлдсэн |
| FR-04 | Профайл харах/засах | ProfilePage, account.profileForm, updateProfile | W, R |
| FR-05 | Lost зар | CreateItemPage, createItem | UI, W |
| FR-06 | Lost зураг | MediaPicker, Storage | R |
| FR-07 | Lost нууц шинж | itemSecrets тусдаа document | R, I |
| FR-08 | Lost засах | CreateItemPage(item), updateItem | W |
| FR-09 | Found зар | createItem | W, I |
| FR-10 | Found зураг | MediaPicker, StorageImage | R |
| FR-11 | Found нууц шинж | itemSecrets | R, I |
| FR-12 | Баталгаажаагүй Found засах | updateItem owner/state guard | W |
| FR-13 | Claim-гүй өөрийн зар устгах | deleteItem soft-delete | W |
| FR-14 | Идэвхтэй жагсаалт | ItemsPage/listItems | W, R |
| FR-15 | Нэр/тайлбарын хайлт | Unicode searchTokens, indexed server query | W |
| FR-16 | Ангилал | Server category filter | W, UI |
| FR-17 | Байршил | Дүүргийн server filter | W, UI |
| FR-18 | Огнооны хүрээ | Date range picker + listItems | W |
| FR-19 | Нийтийн дэлгэрэнгүй | ItemDetailPage/getItem whitelist | W, I |
| FR-20 | Жинлэсэн matching | domain.score 30/30/20/20 | W |
| FR-21 | Оноогоор эрэмбэ | MatchesPage/matches | W |
| FR-22 | Шинэ тохирлын мэдэгдэл | matchNewItems/matchNotifications | W idempotency; cloud trigger acceptance үлдсэн |
| FR-23 | Found claim | claimForm/createClaim | UI, W, I |
| FR-24 | Нууц хариулт | claim.answer, participant guard | W, R |
| FR-25 | Нотлох зураг | private claims Storage paths | R |
| FR-26 | Давхар идэвхтэй claim хориг | Transaction + deterministic claimLocks | W race |
| FR-27 | Ирсэн/илгээсэн | ClaimsPage хоёр tab | UI pagination, W |
| FR-28 | Нотолгоо шалгах | ClaimDetailPage/getClaim | W, R |
| FR-29 | Зөвшөөрөх | decideClaim/verify | W, I |
| FR-30 | Шалтгаантай татгалзах | ActionForm/decideClaim | W |
| FR-31 | Claim төлөв | pending/verified/rejected/withdrawn/disputed | W |
| FR-32 | Нэг хүчинтэй verified | Item winner + atomic transaction | W simultaneous verify |
| FR-33 | Returned дээр claim хориг | createClaim state guard | W, I |
| FR-34 | Баталгаажсан хоёр талын контакт | getClaim contacts whitelist | W, I |
| FR-35 | Хүлээлцээд returned | HandoverForm/markReturned | UI, W, I |
| FR-36 | Татгалзлын маргаан | claimForm dispute/createDispute | W |
| FR-37 | Админ нотолгоо шалгах | AdminDisputePage/getDispute | W, R |
| FR-38 | Эцсийн шийдвэр | resolveDispute, atomic winner replacement | W |
| FR-39 | Зар нуух/ил гаргах | Admin ItemsPage/hideItem | W, R photo moderation |
| FR-40 | 30 хоног | expireIdleItems/expire | W controlled clock |
| FR-41 | Claim мэдэгдэл | createClaim notification | W |
| FR-42 | Verified мэдэгдэл | verify хоёр талд | W, I |
| FR-43 | Rejected мэдэгдэл | decideClaim notification | W |
| FR-44 | Returned мэдэгдэл | markReturned notification | W, I |
| FR-45 | Жагсаалт/уншсан төлөв | NotificationsPage, markRead/markAllRead | W recipient protection, R |
| FR-46 | Админ тайлан | stats/reports/exportReport, AdminReportsPage | W, I, R private CSV |
| FR-47 | Actor/time/action аудит | auditLogs server transaction, adminAudit | W, R client write deny |

Хайлт нь 3+ тэмдэгттэй үгийн эхлэлээр нэр/тайлбарт, олон үг AND нөхцөлөөр ажиллана. Дурын substring/typo/stemming хайлт биш. Server query + cursor ашигладаг тул зөвхөн утсанд татсан хуудсаар хязгаарлагдахгүй. Matching list >0 оноо, шинэ match notification ≥60 оноо.

PDF-ийн 50,000 зар, хайлт <2с, matching <3с, MTBF 720ц/MTTR 2ц нь зорилтот үзүүлэлтүүд; энэ ажлаар load/operations хэмжилтээр батлаагүй.
