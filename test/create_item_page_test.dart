// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found/core/app_theme.dart';
import 'package:lost_found/items/create_item_page.dart';

void main() {
  testWidgets('all required fields validate even after scrolling to submit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const CreateItemPage()),
    );
    final submit = find.widgetWithText(FilledButton, 'Зар нийтлэх');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Эд зүйлийн нэр оруулна уу.'), findsOneWidget);
    expect(find.text('Ангилал сонгоно уу.'), findsOneWidget);
    expect(find.text('Дүүрэг сонгоно уу.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('leaving a changed draft asks before discarding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CreateItemPage()),
              ),
              child: const Text('Нээх'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Нээх'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Түлхүүр');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Бичиж буй зараа орхих уу?'), findsOneWidget);
    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Түлхүүр'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Орхих'));
    await tester.pumpAndSettle();
    expect(find.text('Нээх'), findsOneWidget);
    expect(find.byType(CreateItemPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
