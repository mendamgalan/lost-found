# Оллоо — Lost & Found Mobile 1.1

Монгол хэлтэй Flutter Android апп. Firebase Authentication, Firestore, Storage, Cloud Functions, Messaging ашиглана. `Mobile-biydaalt.pdf`-ийн FR-01–FR-47 болон GitLab вэб reference-ийн хэрэглэгч/админ урсгалыг үндэслэн өргөтгөв.

## Debian + Android Emulator дээр ажиллуулах

**Тусдаа APK татах шаардлагагүй.** Flutter `run` команд өөрөө debug хувилбарыг бүтээж Android emulator-т суулгана; `r` hot reload, `R` hot restart, `q` гарах.

Шалгасан Flutter SDK: **3.50.1 / Dart 3.14.0**. Сервер: **Node 22+**, Firebase emulator: **JDK 21**. Android build-д бүрэн JDK/compiler, Android SDK 36, plugin-үүдийн SDK 34/35, NDK 28.2.13676358, CMake 3.22.1 хэрэгтэй; SDK Manager-аас шаардсан багцыг суулгана.

```bash
flutter doctor
flutter emulators
# Pixel_10 хараахан асаагүй бол:
flutter emulators --launch Pixel_10
flutter devices
# Төслийн хавтсаас, emulator-5554 device ашиглан:
bash scripts/run-emulator.sh emulator-5554
```

Script нь npm dependency суулгаж, Firebase-ийн **локал demo** Auth/Firestore/Storage/Functions emulators эхлүүлээд demo хэрэглэгч/зар үүсгэн Flutter-ийг ажиллуулна. Бодит Firebase өгөгдөлд хүрэхгүй. Шаардлагатай port: 8080, 9099, 9199, 5001. Эдгээр портод өөр emulator ажиллаж байвал эхлээд түүнийг зогсооно. Серверийн лог `.emulator-data/session.log`; локал өгөгдөл `.emulator-data/`-д экспортлогдоно.

| Demo данс | Үүрэг | Нууц үг |
|---|---|---|
| demo-owner@example.test | Олсон зарын эзэн | Demo12345 |
| demo-claimant@example.test | Гээсэн хүн | Demo12345 |
| demo-admin@example.test | Админ | Demo12345 |

Эдгээр данс зөвхөн `demo-lost-found` локал emulator-д үүснэ.

### Хоёр terminal ашиглах хувилбар

```bash
# Terminal 1
npm --prefix functions ci
npm --prefix tools/firestore-tests ci
node scripts/emulator-cli.cjs emulators:start \
  --only auth,firestore,storage,functions --project demo-lost-found
```

```bash
# Terminal 2
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/seed-demo.cjs
flutter pub get
flutter run -d emulator-5554 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=EMULATOR_HOST=10.0.2.2
```

`10.0.2.2` нь Android emulator-оос Debian host-ийн loopback серверт хандах хаяг. Бодит утас ашиглавал LAN хаяг болон emulator binding-аа өөрөөр тохируулна.

## Хэрэгжсэн боломж

- Бүртгэл/нэвтрэлт/имэйлээр нууц үг сэргээх, профайл болон одоогийн нууц үгээр дахин баталгаажуулж нууц үг солих, зочин зар үзэх.
- Lost/Found зар, 5 хүртэл зураг, тусгаарласан нууц онцлог, засах, идэвхтэй claim-гүй зарыг устгах.
- Бүх сангийн сервер query: нэр/тайлбарын үгийн эхлэлээр 3+ тэмдэгттэй хайлт, төрөл/ангилал/дүүрэг/огноо/төлөвийн шүүлтүүр, cursor pagination.
- 30/30/20/20 оноотой matching, буурах эрэмбэ, ≥60 оноотой шинэ тохирлын мэдэгдэл.
- Claim, хувийн хариулт/нотлох зураг, ирсэн/илгээсэн жагсаалт, зөвшөөрөх/шалтгаантай татгалзах, буцаан татах, давхар идэвхтэй/verified хамгаалалт.
- Баталгаажсан хоёр талын контакт, хүлээлцэх цаг/газар, returned төлөв, татгалзлын маргаан, админы эцсийн шийдвэр.
- Админ зар нуух/ил гаргах, хэрэглэгчийн хайлт/үүрэг, статистик/ангилал/төлөв/сарын задаргаа, огнооны тайлан, бүтэн CSV export/share, аудитын хайлт/шүүлтүүр.
- Хувийн мэдэгдэл, unread/bulk read, FCM холболт, 30 хоног хөдөлгөөнгүй open/claimed зарыг хугацаа дуусгах scheduled function.

Доод navigation: **Хайх / Миний зар / Хүсэлт / Мэдэгдэл / Профайл**. Таб руу ороход серверийн мэдээллийг шинэчилнэ. Admin нь зөвхөн Firebase Auth custom claim; client-ийн profile.role эрх олгохгүй.

## Бодит Firebase

Одоогийн client тохиргоо `lost-found-e1221` рүү заана. Шинэ backend/rules/indexes-ийг алсын project-д байршуулаагүй. Flag-гүй `flutter run` ашиглахын өмнө [deployment.md](docs/deployment.md)-ийг гүйцээнэ. Шинэ функцийг байршуулалгүй client дангаараа бүрэн ажиллахгүй.

## Шалгалт ба заавар

- [47 шаардлагын хэрэгжилт](docs/requirements-matrix.md)
- [Вэб хувилбартай нийцэл](docs/web-parity.md)
- [Хэрэглэгч/админы гарын авлага](docs/user-guide.md)
- [Firebase deployment/migration](docs/deployment.md)
- [Шалгалт ба гаргах бэлтгэлийн бодит төлөв](docs/release-readiness.md)
- [Шалгалтын лог](docs/validation/README.md)

```bash
flutter analyze
flutter test
node scripts/emulator-cli.cjs emulators:exec \
  --only firestore,storage --project demo-lost-found \
  'npm --prefix tools/firestore-tests test && npm --prefix functions test'
node scripts/emulator-cli.cjs emulators:exec \
  --only auth,firestore,storage --project demo-lost-found \
  'node functions/test/callable.integration.cjs && node scripts/seed-demo.cjs'
```

[Figma — өмнөх 10 дэлгэц](https://www.figma.com/design/uyfC70n0tp5iMqeJPYglmS?node-id=4-2670). Claim/admin зэрэг нэмэлт дэлгэцүүд кодод бий; Figma Starter quota-аас шалтгаалан тэдгээрийг зураглалд нэмж оруулаагүй. UI preview нь `docs/design/previews/`-д байгаа бодит Flutter renderer-ийн жишээ өгөгдөлтэй дүрслэл.
