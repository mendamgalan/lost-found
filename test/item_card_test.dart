// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found/core/app_theme.dart';
import 'package:lost_found/items/item.dart';
import 'package:lost_found/items/item_card.dart';

void main() {
  testWidgets('card remains tappable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var tapped = false;
    final item = Item(
      id: '1',
      ownerId: 'a',
      type: 'lost',
      title: 'Урт нэртэй гээсэн эд зүйлийн мэдээлэл',
      category: 'Утас',
      description: 'Тайлбар',
      eventDate: DateTime(2026, 11, 19),
      district: 'Сонгинохайрхан',
      placeName: 'Төв номын сан',
      status: 'open',
      isHidden: false,
      createdAt: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 150,
                child: ItemCard(item: item, onTap: () => tapped = true),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(ItemCard));
    expect(tapped, isTrue);
  });
}
