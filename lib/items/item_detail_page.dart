import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'item.dart';

class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Зарын дэлгэрэнгүй')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Зарыг уншиж чадсангүй. Зар нуугдсан эсвэл хандах эрхгүй болсон байж болно.',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Зар олдсонгүй.'));
          }
          final Item item;
          try {
            item = Item.fromFirestore(snapshot.data!);
          } catch (_) {
            return const Center(
              child: Text('Зарын өгөгдлийн формат буруу байна.'),
            );
          }
          if (item.isHidden) {
            return const Center(child: Text('Энэ зар нуугдсан байна.'));
          }
          final date =
              '${item.eventDate.year}-'
              '${item.eventDate.month.toString().padLeft(2, '0')}-'
              '${item.eventDate.day.toString().padLeft(2, '0')}';
          final statusLabel = switch (item.status) {
            'open' => 'Нээлттэй',
            'verified' => 'Эзэмшигч баталгаажсан',
            'returned' => 'Буцаан олгосон',
            'expired' => 'Хугацаа дууссан',
            _ => 'Тодорхойгүй',
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(item.type == 'lost' ? 'Гээсэн' : 'Олсон')),
                  Chip(label: Text(statusLabel)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.category_outlined),
                title: Text(item.category),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(item.district),
                subtitle: Text(item.placeName),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(date),
                subtitle: Text(
                  item.type == 'lost' ? 'Гээсэн огноо' : 'Олсон огноо',
                ),
              ),
              const Divider(),
              const SizedBox(height: 12),
              Text('Тайлбар', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(item.description),
            ],
          );
        },
      ),
    );
  }
}
