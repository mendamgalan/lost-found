import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'item.dart';

class ItemRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ItemRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> createItem({
    required String type,
    required String title,
    required String category,
    required String description,
    required DateTime eventDate,
    required String district,
    required String placeName,
    required String secretDetail,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Зар нэмэхийн тулд нэвтэрнэ үү.');
    }

    final normalizedType = type.trim().toLowerCase();

    if (normalizedType != 'lost' && normalizedType != 'found') {
      throw ArgumentError('Зарын төрөл lost эсвэл found байна.');
    }

    final cleanTitle = _requiredText(title, 'Нэр');
    final cleanCategory = _requiredText(category, 'Ангилал');
    final cleanDescription = _requiredText(description, 'Тайлбар');
    final cleanDistrict = _requiredText(district, 'Дүүрэг');
    final cleanPlaceName = _requiredText(placeName, 'Газрын нэр');
    final cleanSecretDetail = _requiredText(secretDetail, 'Нууц онцлог');

    // Compare calendar dates, ignoring the time of day.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final localEventDate = eventDate.toLocal();
    final eventDay = DateTime(
      localEventDate.year,
      localEventDate.month,
      localEventDate.day,
    );

    if (eventDay.isAfter(today)) {
      throw ArgumentError('Ирээдүйн огноо сонгож болохгүй.');
    }

    // Firestore generates the ID without writing a document yet.
    final itemReference = _firestore.collection('items').doc();

    final secretReference = _firestore
        .collection('itemSecrets')
        .doc(itemReference.id);

    final item = Item(
      id: itemReference.id,
      ownerId: user.uid,
      type: normalizedType,
      title: cleanTitle,
      category: cleanCategory,
      description: cleanDescription,
      eventDate: eventDay,
      district: cleanDistrict,
      placeName: cleanPlaceName,
      status: 'open',
      isHidden: false,
      createdAt: null,
    );

    final publicData = item.toFirestore();
    publicData['createdAt'] = FieldValue.serverTimestamp();

    final batch = _firestore.batch();

    batch.set(itemReference, publicData);

    batch.set(secretReference, {
      'ownerId': user.uid,
      'secretDetail': cleanSecretDetail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Both documents succeed together or neither is written.
    // Errors propagate to the caller.
    await batch.commit();

    return itemReference.id;
  }

  String _requiredText(String value, String fieldName) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError('$fieldName хоосон байж болохгүй.');
    }

    return cleaned;
  }
}
