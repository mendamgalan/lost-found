import 'item.dart';

/// Text and location filters apply only to the pages already fetched.
/// The UI keeps pagination available so an empty match is not a global result.
List<Item> filterItems(
  Iterable<Item> items, {
  String query = '',
  String? category,
  String? district,
  bool openOnly = false,
}) {
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return items.where((item) {
    final haystack =
        '${item.title} ${item.description} ${item.category} ${item.district} ${item.placeName}'
            .toLowerCase();
    return (category == null || item.category == category) &&
        (district == null || item.district == district) &&
        (!openOnly || item.status == 'open') &&
        words.every(haystack.contains);
  }).toList();
}
