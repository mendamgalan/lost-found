import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String ownerId;
  final String type;
  final String title;
  final String category;
  final String description;
  final DateTime eventDate;
  final String district;
  final String placeName;
  final String status;
  final bool isHidden;
  final DateTime? createdAt;

  const Item({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.category,
    required this.description,
    required this.eventDate,
    required this.district,
    required this.placeName,
    required this.status,
    required this.isHidden,
    required this.createdAt,
  });

  factory Item.fromFirestore(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    if (data == null) {
      throw StateError('Зарын мэдээлэл олдсонгүй.');
    }

    final eventTimestamp = data['eventDate'];
    final createdTimestamp = data['createdAt'];

    if (eventTimestamp is! Timestamp) {
      throw const FormatException('Зарын огнооны формат буруу байна.');
    }

    if (createdTimestamp != null && createdTimestamp is! Timestamp) {
      throw const FormatException('Үүсгэсэн огнооны формат буруу байна.');
    }

    return Item(
      id: document.id,
      ownerId: data['ownerId'] as String,
      type: data['type'] as String,
      title: data['title'] as String,
      category: data['category'] as String,
      description: data['description'] as String,
      eventDate: eventTimestamp.toDate(),
      district: data['district'] as String,
      placeName: data['placeName'] as String,
      status: data['status'] as String,
      isHidden: data['isHidden'] as bool,
      createdAt: (createdTimestamp as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'type': type,
      'title': title,
      'category': category,
      'description': description,
      'eventDate': Timestamp.fromDate(eventDate),
      'district': district,
      'placeName': placeName,
      'status': status,
      'isHidden': isHidden,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }
}
