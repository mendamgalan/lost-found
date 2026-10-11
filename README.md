# Олсон • Гээсэн — Алхам 1

Энэ нь бүтэн апп биш: бүртгэл, нэвтрэлт, хувийн профайл, зөвшөөрөл,
гарах ажиллагааны эхний source багц. Android platform файлуудыг өөрийн
Flutter SDK-аар үүсгэнэ. Firebase project болон firebase_options.dart нь
хэрэглэгчийн өөрийн тохиргооноос үүсэх тул багцад оруулаагүй.

## 1. Орчноо шалгах

```sh
flutter --version
flutter doctor -v
```

Flutter команд олдохгүй бол эхлээд Flutter SDK болон Android Studio/Android SDK
суулгана: https://docs.flutter.dev/get-started/install
Android toolchain алдааг зассаны дараа үргэлжлүүлнэ.

## 2. Шинэ төсөл үүсгэх

Өөрийн хөгжүүлэлтийн хавтас дотор:

```sh
flutter create --platforms=android --org mn.mendamgalan lost_found
cd lost_found
flutter pub add firebase_core firebase_auth cloud_firestore
```

Татсан багцын `lib/` хавтсыг шинэ төслийн `lib/` дээр хуулж солино.
`firestore.rules`, `firebase.json` файлыг pubspec.yaml-тай ижил түвшинд хуулна.
Flutter-ээс үүссэн default `test/widget_test.dart` нь хуучин counter аппыг
шалгадаг тул устгана. Firebase emulator-той тестийг дараагийн шатанд нэмнэ.

## 3. Firebase project

https://console.firebase.google.com/ хаягаар өөрийн Google account-аар орно.

1. Шинэ project үүсгэнэ. Spark төлөвлөгөөг хадгална; billing холбохгүй.
2. Authentication → Sign-in method → Email/Password → Enable → Save.
3. Authentication-ийн password policy тохиргоонд хамгийн бага уртыг 8 болгоно.
   Flutter формын шалгалт дангаараа серверийн хамгаалалт биш.
4. Firestore Database → Create database → Standard edition сонгоно.
   Production mode ашиглана. Region-оо сонгохдоо дараа нь амархан өөрчлөхгүйг анхаар.
5. Firestore → Rules хэсэгт багцын firestore.rules-ийг бүтнээр хуулж Publish хийнэ.
   Test mode эсвэл allow read, write: if true ашиглахгүй.

## 4. FlutterFire тохируулах

Node.js/npm болон Firebase CLI шаардлагатай.
Албан ёсны суулгах заавар: https://firebase.google.com/docs/cli

```sh
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

Linux дээр npm EACCES гарвал sudo-гаар шууд засахын оронд npm user prefix
эсвэл Node version manager тохируул. Windows болон Linux-ийн PATH ялгаатай.
FlutterFire executable PATH-д байхгүй үед дараах байдлаар шууд ажиллуулж болно:

```sh
dart pub global run flutterfire_cli:flutterfire configure --platforms=android
```

Өөрийн Firebase project-ийг сонгоно. Энэ нь lib/firebase_options.dart үүсгэнэ.
Командыг заавал lost_found төслийн үндсэн хавтаснаас ажиллуулна.
Энэ файл үүсээгүй үед main.dart-ийн import алдаа гарах нь хүлээгдэж буй зүйл.
Хуурамч API key/project ID оруулж алдааг дарахгүй.

## 5. Android интернет эрх

android/app/src/main/AndroidManifest.xml дотор `<manifest ...>`-ийн шууд хүүхэд,
`<application ...>`-ийн гадна дараах мөр байгаа эсэхийг шалгаж, байхгүй бол нэмнэ:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## 6. Ажиллуулах

```sh
flutter pub get
dart format lib
flutter analyze
flutter devices
flutter run
```

USB утас бол Developer options болон USB debugging асаана.
Эсвэл Android Studio-аас emulator асаана. Firebase нь интернет шаарддаг.

## 7. Шалгах дараалал

- Шинэ email/password → бүртгэл үүсэх → нэр/утас/зөвшөөрлийн форм гарна.
- Зөвшөөрөлгүйгээр профайл хадгалахгүй.
- 8 оронтой утас, нэр, зөвшөөрөл өгөөд хадгална.
- Firestore privateProfiles/{uid} дотор мэдээлэл байна, нууц үг байхгүй.
- Гараад буцаж нэвтрэхэд профайл харагдана.
- Аппыг хаагаад нээхэд нэвтрэлтийн төлөв сэргээнэ.
- Auth бүртгэл үүссэний дараа профайл хадгалалт тасарвал дахин нэвтрээд
  профайлаа гүйцээнэ. Auth ба Firestore нь нэг transaction биш учраас энэ урсгал хэрэгтэй.
- Firebase Rules playground-д unauthenticated болон өөр uid-ээр privateProfiles
  уншихад deny; өөрийн uid-ээр уншихад allow байхыг шалга.
- Өөрийн профайлд role: admin нэмэх, профайл шинэчлэх/устгах хүсэлт deny байх ёстой.

## 8. APK (тохиргоо, шалгалтын дараа)

```sh
flutter build apk --release
```

Гарах файл: build/app/outputs/flutter-apk/app-release.apk.
Энэ алхам нь хичээлийн sideload demo-д зориулагдсан; дэлгүүрийн нийтлэл,
production signing тохиргоо энэ багцын хүрээнд ороогүй.

## Кодын тайлбар

- lib/main.dart: Firebase эхлүүлж, authStateChanges-аар нэвтрэлтийг сонсоно.
- lib/auth/auth_page.dart: email/password форм болон Firebase Auth хүсэлт.
- lib/profile/profile_page.dart: профайл байгаа эсэхийг сонсож, байхгүй бол
  бүртгэл гүйцээх форм харуулна. Server timestamp-аар зөвшөөрлийн хугацаа хадгална.
- firestore.rules: зөвхөн өөрийн профайл үүсгэх/унших эрх; бусад бүх хандалт хаалттай.

Security rules-ийн нөхцөлүүдийг Emulator Suite-аар автомат тестлэх ажил үлдсэн.
Энэ багцыг бэлтгэсэн орчинд Flutter/Dart SDK байхгүй тул compile, analyze,
Android runtime болон бодит Firebase холболтыг ажиллуулж баталгаажуулаагүй.
pubspec.lock-ийг flutter pub add амжилттай ажилласны дараа git-д хадгал.

Албан ёсны эх сурвалж:
- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/auth/flutter/password-auth
- https://firebase.google.com/docs/firestore/security/get-started

Дараагийн алхам: Lost/Found зарын өгөгдөл, дэлгэц, repository, Security Rules.
