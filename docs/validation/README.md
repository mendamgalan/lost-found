# Сэргээсэн эх кодын шалгалтын нотолгоо

13 Flutter unit/widget, 16 server workflow, 10 Firestore/Storage Rules тест амжилттай. Callable integration нь Auth emulator-ийн бодит ID token ашиглан хоёр хэрэглэгчийн бүрэн claim/verified-contact/handover/returned, admin эрх, forged UID, CSV export/security-г шалгана. Demo seed мөн ажилласан.

Rules-ийн сөрөг тестийн PERMISSION_DENIED нь хүлээгдсэн үр дүн. Callable app MISSING нь local integration-д App Check token ашиглаагүйг илэрхийлнэ. Production App Check/FCM delivery баталгаажсан гэсэн үг биш.

Эдгээр лог нь орчин сэргэсэн дараах шинэчилсэн source-ийн дахин ажиллуулсан шалгалт. Өмнөх алдагдсан APK-ийн логийг ашиглаагүй. User-ийн хүсэлтээр тусдаа APK delivery/дахин native build хийгээгүй. Debian Android emulator дээр README-ийн заавраар ажиллуулна.
