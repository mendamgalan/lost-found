import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found/items/item.dart';
import 'package:lost_found/items/item_filter.dart';

Item sample(
  String id,
  String title,
  String category,
  String district, {
  String status = 'open',
}) => Item(
  id: id,
  ownerId: 'owner',
  type: 'found',
  title: title,
  category: category,
  description: 'Номын сангийн үүдэнд',
  eventDate: DateTime(2026, 11, 19),
  district: district,
  placeName: 'Төв номын сан',
  status: status,
  isHidden: false,
  createdAt: null,
);
void main() {
  final items = [
    sample('1', 'iPhone 15', 'Утас', 'Сүхбаатар'),
    sample('2', 'Арьсан түрийвч', 'Түрийвч', 'Баянгол', status: 'returned'),
  ];
  test('case-insensitive words match across title and location', () {
    expect(filterItems(items, query: '  IPHONE   номын ').map((e) => e.id), [
      '1',
    ]);
  });
  test('category, district and status filters combine', () {
    expect(
      filterItems(items, category: 'Түрийвч', district: 'Баянгол').length,
      1,
    );
    expect(filterItems(items, category: 'Түрийвч', openOnly: true), isEmpty);
    expect(filterItems(items, category: 'Утас', district: 'Баянгол'), isEmpty);
  });
  test('blank query does not discard items and original list is unchanged', () {
    expect(filterItems(items, query: '   ').length, 2);
    filterItems(items, query: 'something missing');
    expect(items.length, 2);
  });
}
