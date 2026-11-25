// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found/auth/auth_page.dart';
import 'package:lost_found/core/app_theme.dart';

void main() {
  testWidgets('auth validates locally and switches to registration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const AuthPage()),
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pump();
    expect(find.text('Зөв email оруулна уу.'), findsOneWidget);
    expect(find.text('Нууц үгээ оруулна уу.'), findsOneWidget);
    await tester.ensureVisible(find.text('Шинэ бүртгэл үүсгэх'));
    await tester.tap(find.text('Шинэ бүртгэл үүсгэх'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'test@example.mn');
    await tester.enterText(find.byType(TextFormField).last, '1234567');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Бүртгэл үүсгэх'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Бүртгэл үүсгэх'));
    await tester.pump();
    expect(find.text('8-аас доошгүй тэмдэгт оруулна уу.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('auth scrolls without overflow on narrow screen and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: AuthPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Шинэ бүртгэл үүсгэх'));
    expect(tester.takeException(), isNull);
  });
}
