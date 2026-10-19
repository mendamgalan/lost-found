# Олсон • Гээсэн — хөгжүүлэгчийн гарын авлага

Гээсэн болон олсон эд зүйлийн зар нийтлэх, эзэмшигчийн нэхэмжлэлийг шалгах, эд зүйлийг буцаан хүлээлцэхэд зориулсан Android апп.

- **Repository:** https://github.com/mendamgalan/lost-found
- **Технологи:** Flutter / Dart, Firebase Authentication, Cloud Firestore.
- **Зорилго:** Mobile Programming хичээлийн бие даалтын MVP, Android APK.
- **Баримтын суурь:** 2026-10-19-нд шалгасан `main`, commit `e6ddaa9b2f6e9e8173f5125100a1f5ae7e19d383`.

> Доорх “хийгдсэн” гэдэг нь кодод хэрэгжсэн гэсэн утгатай. Энэ README бэлтгэх үед Android build, Firebase-ийн бодит орчин болон Rules deployment-ийг ажиллуулж баталгаажуулаагүй. “Төлөвлөсөн” хэсгийг бэлэн боломж гэж үзэхгүй.

## 1. Систем хэрхэн ажиллах вэ?

### Одоо ажиллах урсгал

1. Хэрэглэгч email, нууц үгээр бүртгүүлэх эсвэл нэвтэрнэ.
2. Нэр, 8 оронтой утас, мэдээлэл ашиглах зөвшөөрлөө оруулж профайлаа гүйцээнэ.
3. “Гээсэн” эсвэл “Олсон” зар үүсгэнэ. Зар нь ангилал, тайлбар, огноо, дүүрэг, газрын нэртэй.
4. Эд зүйлийн бусдад харагдахгүй онцлогийг тусдаа нууц мэдээлэл болгон хадгална.
5. Нэвтэрсэн хэрэглэгчид нуугдаагүй заруудыг жагсаалтаар харж, төрлөөр шүүж, дэлгэрэнгүйг нээнэ.

### Эцсийн MVP-д нэмэх урсгал

1. Эд зүйлээ таньсан хэрэглэгч олсон зар дээр “Миний эд зүйл” нэхэмжлэл буюу claim илгээнэ.
2. Олсон хүн нотолгоог шалгаж, зөвшөөрөх эсвэл татгалзана.
3. Claim баталгаажсаны дараа зөвхөн тухайн хоёр талд email, утас харагдана.
4. Хоёр тал хүлээлцсэнээ баталгаажуулсны дараа зар `returned` болно.
5. Маргаан гарвал админ шийдвэрлэнэ. Энгийн claim бүрийг админ батлахгүй.

**Нэршлийн анхаарах зүйл:** `items.ownerId` нь зар нийтэлсэн хэрэглэгчийн UID. Олсон зарын хувьд энэ нь эд зүйлийн жинхэнэ эзэмшигч биш, олсон хүний UID байна. `verified` нь claim баталгаажсан төлөв; email verification-тай адил биш.

## 2. Одоогийн хэрэгжилт ба хүрээ

| Боломж | Төлөв |
| --- | --- |
| Email/password бүртгэл, нэвтрэлт, гарах | Кодод хэрэгжсэн |
| Хувийн профайл болон зөвшөөрөл хадгалах | Кодод хэрэгжсэн |
| Lost/Found зар үүсгэх | Кодод хэрэгжсэн |
| Зар + нууц онцлогийг atomic batch-аар хадгалах | Кодод хэрэгжсэн |
| Бүгд / Гээсэн / Олсон шүүлтүүр | Кодод хэрэгжсэн |
| Шинээс хуучин руу эрэмбэлэх, 20-оор хуудаслах | Кодод хэрэгжсэн; index шаардлагатай |
| Зарын дэлгэрэнгүй харах | Кодод хэрэгжсэн |
| Claim илгээх, шалгах, батлах | Хийгдээгүй |
| Баталгаажсан хоёр талд холбоо барих мэдээлэл үзүүлэх | Хийгдээгүй |
| Хүлээлцэлт, маргаан, админ ажиллагаа | Хийгдээгүй |
| Апп доторх мэдэгдэл | Хийгдээгүй |
| Автомат тестүүд | Шалгасан commit-д test хавтас байхгүй |

MVP-д байршлыг дүүрэг + газрын нэрээр оруулна. GPS/газрын зураг, байгууллагын тусдаа бүртгэл, зураг байршуулалт, чат, апп хаалттай үед ирэх push notification-ийг эхний ээлжид хийхгүй. Өөрийн сервер ажиллуулах шаардлагагүй; Firebase ашиглана. Төлбөртэй үйлчилгээ нэмэхээс өмнө төслийн эзэнтэй тохиролцоно.

## 3. Кодын бүтэц

| Файл | Үүрэг |
| --- | --- |
| `lib/main.dart` | Firebase эхлүүлэх, нэвтрэлтийн төлөвөөр Auth/Profile дэлгэц сонгох |
| `lib/auth/auth_page.dart` | Бүртгэл, нэвтрэх форм, validation, Auth алдааны мэдээлэл |
| `lib/profile/profile_page.dart` | Профайл үүсгэх/унших, зөвшөөрөл, гарах, зарын хэсэгт шилжих |
| `lib/items/item.dart` | Зарын model, Firestore хөрвүүлэлт |
| `lib/items/item_repository.dart` | Зар үүсгэх шалгалт болон batch write |
| `lib/items/create_item_page.dart` | Зар нэмэх форм |
| `lib/items/items_page.dart` | Шүүлтүүр, refresh, cursor pagination |
| `lib/items/item_detail_page.dart` | Зарын document stream, дэлгэрэнгүй мэдээлэл |
| `lib/firebase_options.dart` | FlutterFire-ийн Firebase client тохиргоо |
| `android/app/google-services.json` | Android Firebase client тохиргоо |
| `firestore.rules` | Өгөгдөлд хандах эрх, сервер талын validation |
| `firebase.json` | Firebase deployment болон FlutterFire тохиргоо |
| `pubspec.yaml`, `pubspec.lock` | Dependency шаардлага болон түгжсэн хувилбарууд |

Одоогоор UI-ийн төлөвийг `StatefulWidget`/`setState`, өгөгдлийн урсгалыг `StreamBuilder` ашиглан удирддаг. Auth, Profile, жагсаалтын уншилтууд Firebase SDK-г шууд ашигладаг; зар үүсгэх нь repository-д тусгаарлагдсан. Шинэ боломж нэмэхдээ UI болон өгөгдөл өөрчлөх ажиллагааг тусгаарлахыг баримтална.

## 4. Хөгжүүлэлтийн орчин бэлтгэх

### Шаардлага

- Git, Flutter SDK, Android Studio болон Android SDK.
- `pubspec.yaml` дахь Dart шаардлага: `^3.13.2`. Үүнд тохирох Dart агуулсан Flutter SDK ашиглана.
- Android emulator эсвэл USB debugging асаасан Android утас.
- Firebase тохируулах/Rules байршуулбал Firebase CLI, Node.js-ийн CLI-д нийцэх хувилбар, Firebase project-ийн зохих эрх.

Android-ийн compile/target SDK, NDK нь Flutter-ийн утгыг дагаж байна. Java/Kotlin compile target нь 17; ашиглах JDK-г `flutter doctor -v` болон тухайн Gradle/AGP нийцлээр шалгана.

### Repository татаж ажиллуулах

```powershell
git clone https://github.com/mendamgalan/lost-found.git
cd lost-found
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter devices
flutter run
```

Энэ repository нь Android platform файлуудтай бүтэн Flutter төсөл. Дахин `flutter create` хийж файлуудаа хуулж нэгтгэх шаардлагагүй. Dependency-г шалтгаангүйгээр бүхэлд нь upgrade хийхгүй; `pubspec.lock`-ийг хадгална.

### Firebase холболт

Одоогийн client тохиргоо `lost-found-e1221` project руу заана. Хамтын project ашиглавал эзнээс нь шаардлагатай эрх авна. Тусдаа хөгжүүлэлтийн project ашиглах нь бодит өгөгдөлд нөлөөлөхгүй туршихад тохиромжтой.

Шинэ project тохируулах бол:

1. Firebase Console-д project үүсгэнэ.
2. Authentication → Email/Password нэвтрэлтийг идэвхжүүлнэ. Password policy-г формын 8 тэмдэгтийн доод шаардлагатай нийцүүлнэ.
3. Cloud Firestore database үүсгэнэ.
4. Төслийн үндсэн хавтсанд дараах командуудыг ажиллуулна:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
dart pub global run flutterfire_cli:flutterfire configure --platforms=android
```

Сонгосон Firebase project, `lib/firebase_options.dart`, `android/app/google-services.json`, `firebase.json` хоорондоо таарч байх ёстой. Android application ID: `mn.mendamgalan.lost_found`.

Rules байрлуулахдаа `<PROJECT_ID>`-г зөв project ID-аар солино:

```powershell
firebase deploy --only firestore:rules --project <PROJECT_ID>
```

Энэ команд алсын орчны дүрмийг өөрчилнө. Хамтын project дээр ажиллахдаа diff-ээ хянаж, зөв project сонгосноо шалгана. Repository-д rules байгаа нь Firebase дээр байршуулсан гэсэн баталгаа биш.

### Жагсаалтад хэрэгтэй indexes

Одоогийн query: `isHidden == false`, сонголтоор `type == lost/found`, дараа нь `createdAt DESC`.

| Collection | Query scope | Fields |
| --- | --- | --- |
| `items` | Collection | `isHidden ASC`, `createdAt DESC` |
| `items` | Collection | `isHidden ASC`, `type ASC`, `createdAt DESC` |

Эдгээрийг Firestore Console-ийн Indexes хэсэгт үүсгэж, бэлэн болтол хүлээнэ. Index шаардсан алдааны холбоос байвал түүгээр query-д яг таарах index үүсгэж болно.

**Repository-ийн дутуу зүйл:** шалгасан commit-д `firestore.indexes.json` байхгүй, `firebase.json` нь зөвхөн rules-ийг зааж байна. Index-үүдийг файл болгож version control-д оруулах, `firebase.json`-д холбоход дараагийн хөгжүүлэгч анхаарна. Үүний дараа `firebase deploy --only firestore:indexes --project <PROJECT_ID>` ашиглаж болно.

## 5. Өгөгдлийн бүтэц ба эрх

### Одоо байгаа collections

| Document | Fields | Одоогийн хандалт |
| --- | --- | --- |
| `privateProfiles/{uid}` | `name`, `phone`, `email`, `consentVersion`, `consentAt`, `createdAt` | Зөвхөн өөрийн профайл үүсгэх, унших |
| `items/{itemId}` | `ownerId`, `type`, `title`, `category`, `description`, `eventDate`, `district`, `placeName`, `status`, `isHidden`, `createdAt` | Нэвтэрсэн хүн нуугдаагүй зар уншина; нийтлэгч өөрийн нуугдсан document-ийг rules-ийн түвшинд уншиж болно |
| `itemSecrets/{itemId}` | `ownerId`, `secretDetail`, `createdAt` | Зөвхөн нийтлэгч уншина |

- Зар үүсгэхийн өмнө профайл байх ёстой.
- `items` ба `itemSecrets` ижил document ID-тай, нэг batch-д үүснэ. Rules нь `getAfter()` ашиглан хамт үүссэнийг шалгадаг.
- `ownerId`-г form-оос авахгүй; Firebase Auth-ийн одоогийн UID-гаас авна.
- `eventDate` нь Firestore timestamp; `createdAt` нь server timestamp.
- Шинэ зар үргэлж `status: open`, `isHidden: false` байна.
- Одоогийн Rules дээр дээрх documents-ийг update/delete хийхийг хориглосон. Claim нэмэхдээ зөвхөн шаардлагатай шилжилтийн эрхийг нээнэ.
- Жагсаалт серверээс хуудасладаг тул интернет шаардлагатай; бүрэн offline боломж гэж үзэхгүй.
- Дэлгэрэнгүй дэлгэц `verified`, `returned`, `expired` нэршлийг харуулах чадвартай ч эдгээр төлөвт шилжүүлэх ажиллагаа хараахан байхгүй.

### Мэдээлэл хамгаалах зарчим

Нууц онцлог, claim-ийн нотолгоо, email, утсыг нийтлэг `items` document-д нэмэхгүй. UI дээр нуух нь read эрхийн хамгаалалт болохгүй. Өөр хүний профайлыг бүхэлд нь унших эрх нээхгүй; баталгаажсан хоёр талд л шаардлагатай холбоо барих мэдээлэл унших механизмыг Rules-тай хамт хийнэ.

Client-аас `role: admin` бичээд админ болдог загвар ашиглахгүй. Админ эрхийг итгэмжлэгдсэн аргаар олгож, Rules дээр шалгана. Service account private key, signing keystore, нууц үг, access token-ийг commit хийхгүй. Firebase client API key нь серверийн admin credential биш; API restriction болон Firestore Rules-ийг тусад нь зөв тохируулна.

## 6. Дараагийн хөгжүүлэгчийн хийх ажлууд

Дарааллаар нь жижиг өөрчлөлтүүд болгон хэрэгжүүлнэ. Доорх collection/field нэрүүд нь санал болгосон загвар бөгөөд одоогийн schema биш.

### P0 — Одоогийн суурийг давтаж ажиллуулах

- [ ] Орчноо тохируулж бүртгэл → профайл → зар үүсгэх → жагсаалт → дэлгэрэнгүй урсгалыг шалгах.
- [ ] Жагсаалтын хоёр index-ийг файл болгон нэмэх, deployment тохиргоотой холбох.
- [ ] `flutter analyze`-ийн бодит үр дүнгээр lint-үүдийг засах.
- [ ] Profile дэлгэцийн “дараагийн алхамд зар нэмнэ” гэсэн хуучирсан тайлбарыг шинэчлэх.
- [ ] Firebase Rules автомат тестийн орчныг нэмэх. Одоогоор emulator руу холбох код/тохиргоо бэлэн гэж үзэхгүй.

**Дууссан гэж үзэх нөхцөл:** шинэ хөгжүүлэгч README-г дагаад урсгалыг ажиллуулж чадна; өөр хэрэглэгчийн private мэдээлэл уншигдахгүй.

### P1 — Claim илгээх

- [ ] `claims` model/repository болон нэхэмжлэлийн форм хийх.
- [ ] Санал болгох fields: `itemId`, `claimantId`, `finderId`, `evidence`, `status`, `createdAt`, `updatedAt`.
- [ ] Зөвхөн нээлттэй `found` зар дээр өөр хэрэглэгч claim илгээнэ. Өөрийн зар дээр илгээхгүй.
- [ ] Хоосон нотолгоо болон давхар идэвхтэй claim-ийг серверийн дүрмээр хориглох.
- [ ] “Миний илгээсэн”, “Миний зар дээр ирсэн” claim жагсаалтыг хийх.
- [ ] Нотолгоог claimant болон тухайн finder л унших; маргааны үед админы эрхийг тусгайлан тодорхойлох.

**Дууссан гэж үзэх нөхцөл:** A хэрэглэгчийн found зар дээр B claim илгээнэ, A харна, C уншиж чадахгүй. Давхар илгээлтээс давхардсан идэвхтэй claim үүсэхгүй.

### P2 — Claim шийдвэрлэх ба холбоо барих мэдээлэл

- [ ] Finder claim-ийг `pending`-ээс `verified` эсвэл `rejected` болгох.
- [ ] Нэг зар дээр нэг л claim баталгаажих нөхцөлийг transaction болон Rules-ээр хамгаалах.
- [ ] Item дээр баталгаажсан claim-тай холбоос хадгалах загвар гаргах.
- [ ] Verified хоёр талд л email, утас харуулах. Client өөр хүний контакт гэж дурын утга бичиж болохгүй.
- [ ] Нэхэмжлэгч өөрөө өөрийгөө баталгаажуулах, өөр зарын claim шийдвэрлэх үйлдлийг deny болгох.

**Дууссан гэж үзэх нөхцөл:** хоёр claim зэрэг батлах оролдлогоос нэг нь л амжилттай; баталгаажихаас өмнө болон гуравдагч хэрэглэгчид контакт харагдахгүй.

### P3 — Эд зүйл хүлээлцэх

- [ ] Хоёр талын тусдаа баталгаажуулалт хадгалах.
- [ ] Хэрэглэгч зөвхөн өөрийн баталгаажуулалтыг өгөх боломжтой байх.
- [ ] Хоёр тал баталсан үед л item `returned` болох.
- [ ] Дууссан зар дээр шинэ claim болон давтан шилжилтийг хориглох.

**Дууссан гэж үзэх нөхцөл:** нэг талын дарсан товчоор хүлээлцэлт дуусахгүй; хоёр дахь баталгаажуулалтын дараа хоёр талд ижил төлөв харагдана.

### P4 — Маргаан, админ

- [ ] Маргааны шалтгаан, холбогдох claim, талууд, төлөв хадгалах.
- [ ] Админд зөвхөн шаардлагатай маргаан/нотолгоо харах, шийдвэр ба тайлбар хадгалах боломж өгөх.
- [ ] Шийдвэрийн actor UID, хугацаа, өмнөх/дараах төлөвийг бүртгэх; энгийн хэрэглэгч өөрчилж болохгүй байх.
- [ ] Зар нуух moderation хэрэгтэй бол тусдаа эрхийн дүрэмтэй хэрэгжүүлэх.

**Дууссан гэж үзэх нөхцөл:** энгийн хэрэглэгч admin ажиллагаа хийж чадахгүй; админы шийдвэр талуудад харагдана. Audit log нь Firebase project-ийн бүрэн эрхтэй админаас өөрөө автоматаар хамгаалагдана гэж үзэхгүй.

### P5 — Апп доторх мэдэгдэл ба demo

- [ ] Шинэ claim, шийдвэр, хүлээлцэлт, маргааны төлөвийг апп дотор харуулах.
- [ ] Эхний хувилбарт claim/item өөрчлөлтийг сонсох буюу refresh хийх энгийн хувилбар ашиглах; push шаардлагагүй.
- [ ] Loading, empty, permission denied, интернет тасарсан төлөвүүдийг шалгах.
- [ ] Хоёр хэрэглэгч + админтай demo бэлтгэх, APK гаргах, README-ийн төлөвийг шинэчлэх.

**Нэмж шийдэх зүйл:** lost зарын нийтлэгчтэй олсон хүн хэрхэн холбогдох урсгал. Эхний claim урсгал found зар дээр төвлөрнө; lost зарын урсгалыг баталгаажаагүй байхад дур мэдэн адилтгаж хэрэгжүүлэхгүй.

## 7. Шалгах дараалал

### Одоогийн боломжууд

- [ ] Буруу email, хоосон талбар, бүртгэлийн богино нууц үгийг шалгах.
- [ ] Зөвшөөрөлгүй, буруу утасны дугаартай профайл хадгалагдахгүй.
- [ ] Auth бүртгэл амжилттай боловч профайл хадгалалт тасарсан үед дахин гүйцээж болно.
- [ ] Ирээдүйн огноо болон буруу зарын утгууд UI/Rules дээр зөв шалгагдана.
- [ ] Зар болон нууц онцлог хоёул үүснэ; нэг нь алдахад нөгөө нь дангаар үлдэхгүй.
- [ ] 21-ээс олон зар дээр pagination, refresh, төрөл солих ажиллагааг шалгах.
- [ ] Нэвтрээгүй хэрэглэгч зар уншихгүй; өөр UID хувийн профайл, нууц онцлог уншихгүй.
- [ ] Rules-ийн түвшинд ownerId хуурамчаар бичих, дурын field нэмэх, update/delete хийхийг deny болгох.
- [ ] Гараад дахин нэвтрэх, аппыг хаагаад нээх урсгалыг шалгах.

### Командууд

```powershell
dart format lib
flutter analyze
```

Автомат тест нэмсний дараа:

```powershell
flutter test
```

`flutter analyze` амжилттай байх нь Rules болон бизнесийн урсгал зөв гэсэн баталгаа биш. Claim/эрхийн өөрчлөлт бүрийг Firebase Emulator Suite-ийн allow/deny тест болон олон хэрэглэгчтэй урсгалаар шалгана.

## 8. APK гаргах

```powershell
flutter build apk --release
```

Гаралт: `build/app/outputs/flutter-apk/app-release.apk`.

Одоогийн Gradle тохиргоонд release build нь debug signing key ашигладаг. Энэ нь хичээлийн demo-д зориулагдсан; дэлгүүрт нийтлэхээс өмнө release signing-ийг тусад нь тохируулна.

## 9. Түгээмэл асуудал

| Шинж тэмдэг | Шалгах зүйл |
| --- | --- |
| `PERMISSION_DENIED` | Нэвтрэлт, UID, профайл байгаа эсэх, сонгосон Firebase project, deployed Rules |
| Жагсаалтад `failed-precondition` | Composite index үүссэн, бэлэн болсон эсэх |
| NDK суулгагдсангүй | Android Studio → SDK Manager → SDK Tools → Show Package Details → build-ийн шаардсан NDK хувилбарыг суулгах |
| Firebase эхлэхгүй | Android package ID, хоёр client config, project тохирч байгаа эсэх |
| `flutterfire` команд олдохгүй | `dart pub global run flutterfire_cli:flutterfire configure --platforms=android` ашиглах |
| Шинэ feature write хийхэд denied | Одоогийн Rules update/delete болон шинэ collections-ийг хаадаг; feature-ийн нарийн нөхцөлтэй Rules хэрэгтэй |

NDK хувилбар нь Flutter SDK-г дагадаг. Өмнөх орчинд `28.2.13676358` шаардсан боловч үүнийг бүх орчинд тогтмол гэж үзэхгүй. Алдааг дарахын тулд Rules-ийг `allow read, write: if true` болгохгүй.

## 10. Хамтран хөгжүүлэх зарчим

1. Нэг feature-д нэг branch, жижиг commit ашиглана.
2. Эхлээд schema болон зөвшөөрөгдөх төлөвийн шилжилтийг тодорхойлно.
3. Model/repository, Rules, UI, шаардлагатай index/test-ийг хамтад нь шинэчилнэ.
4. PR-д юу өөрчилсөн, яагаад, хэрхэн шалгасан, шалгаж чадаагүй зүйлээ бичнэ.
5. Одоогийн бүртгэл болон зарын урсгалыг эвдээгүйг шалгана.
6. Feature дуусах бүрд энэ README-ийн төлөв, setup зааврыг шинэчилнэ.

## Албан ёсны лавлах

- Flutter: https://docs.flutter.dev/
- FlutterFire setup: https://firebase.google.com/docs/flutter/setup
- Firestore Rules: https://firebase.google.com/docs/firestore/security/get-started
- Atomic operations: https://firebase.google.com/docs/firestore/manage-data/transactions
- Firebase API keys: https://firebase.google.com/docs/projects/api-keys
- Android NDK: https://developer.android.com/studio/projects/install-ndk
