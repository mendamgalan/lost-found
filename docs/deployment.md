# Firebase байршуулалт ба хуучин өгөгдөл

Локал emulator эхлүүлэхэд production deployment хэрэггүй. Бодит үйлчилгээ ашиглахын өмнө project owner дараах тохиргоог хийнэ. Энэ ажлаар алсын Firebase/GitHub/GitLab руу өөрчлөлт хийгээгүй.

1. Email/Password Auth, Firestore, Storage идэвхжүүлнэ. Cloud Functions/scheduled triggers-д шаардлагатай billing plan/API/эрхийг project owner тохируулна.
2. FlutterFire-аар Android app-аа зөв project-той холбоно: `lib/firebase_options.dart`, `android/app/google-services.json`. Client/Functions region нь `asia-east1`.
3. CLI login/project эрхээ шалгаад rules/indexes/functions байршуулна:

```bash
npm --prefix functions ci
npm --prefix tools/firestore-tests ci
firebase login
firebase projects:list
firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project YOUR_PROJECT_ID
```

Firebase CLI binary нь `tools/firestore-tests/node_modules/.bin/firebase`. Storage Rules-ийн Firestore cross-service permission-ийн Console/CLI зааврыг гүйцээнэ. Composite indexes Enabled болсныг шалгана. Шинэ Rules нь хуучин client-ийн бизнесийн шууд write-ийг хориглодог тул backend болон шинэ client-ийг нэг rollout-аар гаргана.

## Өмнөх MVP зарын migration

Backup/export авна. Script нь trusted ADC credential-тай серверийн орчинд ажиллана. Credential/key/password-ийг git/ZIP-д оруулахгүй.

```bash
# Унших dry run:
node scripts/migrate-items.cjs --project YOUR_PROJECT_ID
# Backup ба dry run үр дүнгээ шалгасны дараа:
node scripts/migrate-items.cjs --project YOUR_PROJECT_ID --apply
```

searchTokens, updatedAt, imagePaths, isDeleted, pendingCount, disputeCount, verifiedClaimId нэмнэ. Хуучин returned зарын түүхэнд зохиомол claim үүсгэхгүй. Вэбийн mock өгөгдлийг автоматаар импортлохгүй.

## Админ эрх

```bash
node scripts/set-admin.cjs --project YOUR_PROJECT_ID --uid USER_UID
node scripts/set-admin.cjs --project YOUR_PROJECT_ID --uid USER_UID --revoke
```

Trusted ADC эрх хэрэгтэй; хэрэглэгч гарч дахин нэвтрэн шинэ token авна. profile.role client талд өөрчлөх нь эрх үүсгэхгүй.

## Төхөөрөмж ба production шалгалт

Хоёр данс + админаар [user-guide.md](user-guide.md)-ийн acceptance урсгалыг бодит staging project/device дээр гүйцэтгэнэ. Камер, permission, interrupted upload/retry, reset email, нууц үг солих reauthentication, FCM foreground/background/terminated/deeplink, CSV share, back/keyboard, том текст/TalkBack-ийг шалгана. Cloud Scheduler/Eventarc/FCM delivery-г local unit/emulator tests батлахгүй.

`expireIdleItems` өдөр бүр 30 хоног хөдөлгөөнгүй open/claimed зарыг expired болгоно. `matchNewItems` шинэ/зассан зарын тохирлыг үүсгэнэ. Console logs, trigger, scheduler, индексийн төлөвийг шалгана.

Release build нь android/key.properties шаарддаг; debug signing fallback ашиглахгүй. storeFile, storePassword, keyAlias, keyPassword талбаруудыг private keystore-той тохируулна. Debug emulator-д key.properties хэрэггүй.

Release signing keystore, launcher/Store assets, Play Console/privacy/data safety, support contact, monitoring/backup/billing alerts болон retention policy-г owner тохируулна. Одоогийн ажил нь emulator эх кодын хүргэлт; APK/Store publishing хүсээгүй. Public гаргахын өмнө App Check, rate limits/abuse budget, load/operations хэмжилтийг бодит project дээр үнэлж хэрэгжүүлнэ.

Устгал нь audit хадгалсан soft-delete. Upload хийсэн ч нийтлээгүй orphan зураг, экспорт CSV-ийн lifecycle cleanup/хадгалалтын хугацааг тохируулна. Account hard-delete үйлчилгээ энэ scope-д ороогүй.

## Unix socket хориглосон sandbox

Debian дээр энгийн Functions emulator ашиглана. Тусгай sandbox Functions worker-ийн Unix socket-ийг хаавал зөвхөн Auth/Firestore/Storage emulators эхлүүлээд өөр terminal-д:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 node scripts/start-local-api.cjs
```

Энэ нь жинхэнэ onCall handler-ийг зөвхөн demo project-д TCP дээр ажиллуулдаг development fallback; production server биш. Автомат HTTP integration тест ижил handler + Auth emulator-ийн бодит JWT ашиглана.
