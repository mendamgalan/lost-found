import '../services/api.dart';
import '../services/media.dart';

class ItemRepository {
  Future<String> createItem({
    required String type,
    required String title,
    required String category,
    required String description,
    required DateTime eventDate,
    required String district,
    required String placeName,
    required String secretDetail,
    List<String> imagePaths = const [],
    String? id,
  }) async {
    final itemId = id ?? newId();
    await Api.shared.run('createItem', {
      'id': itemId,
      'type': type,
      'title': title,
      'category': category,
      'description': description,
      'eventDate':
          '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}',
      'district': district,
      'placeName': placeName,
      'secretDetail': secretDetail,
      'imagePaths': imagePaths,
    });
    return itemId;
  }

  Future<void> markReturned(String id) async {
    await Api.shared.run('markReturned', {'id': id});
  }
}
