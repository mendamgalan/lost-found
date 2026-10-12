import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'create_item_page.dart';
import 'item.dart';
import 'item_detail_page.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});
  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  static const _pageSize = 20;
  final List<Item> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  String? _type;
  String? _error;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('items')
          .where('isHidden', isEqualTo: false);
      if (_type != null) {
        query = query.where('type', isEqualTo: _type);
      }
      query = query.orderBy('createdAt', descending: true).limit(_pageSize);
      if (_cursor != null) {
        query = query.startAfterDocument(_cursor!);
      }
      // Server-only paging avoids treating an incomplete offline cache as the last page.
      final result = await query.get(const GetOptions(source: Source.server));
      final parsed = result.docs.map((doc) => Item.fromFirestore(doc)).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        final existingIds = _items.map((item) => item.id).toSet();
        _items.addAll(parsed.where((item) => !existingIds.contains(item.id)));
        if (result.docs.isNotEmpty) {
          _cursor = result.docs.last;
        }
        _hasMore = result.docs.length == _pageSize;
      });
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.code) {
            'failed-precondition' => 'Хайлтын index бэлэн болоогүй байна. Firebase Console-ийн Indexes хэсгийг шалгана уу.',
            'permission-denied' => 'Зарын жагсаалт унших эрхгүй байна. Нэвтрэлт болон Rules-ээ шалгана уу.',
            'unavailable' =>
              'Интернет холболт эсвэл үйлчилгээ боломжгүй байна.',
            _ => 'Зар татаж чадсангүй (${e.code}).',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Зар татаж чадсангүй. Өгөгдлийн формат болон холболтоо шалгана уу.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filter(String? type) {
    if (_loading || _type == type) {
      return;
    }
    setState(() => _type = type);
    _load(reset: true);
  }

  Future<void> _create() async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateItemPage()));
    if (created == true && mounted) {
      await _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Зарууд'),
      actions: [
        IconButton(
          tooltip: 'Шинэчлэх',
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading ? null : _create,
      icon: const Icon(Icons.add),
      label: const Text('Зар нэмэх'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Бүгд'),
                selected: _type == null,
                onSelected: _loading ? null : (_) => _filter(null),
              ),
              ChoiceChip(
                label: const Text('Гээсэн'),
                selected: _type == 'lost',
                onSelected: _loading ? null : (_) => _filter('lost'),
              ),
              ChoiceChip(
                label: const Text('Олсон'),
                selected: _type == 'found',
                onSelected: _loading ? null : (_) => _filter('found'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  if (_loading) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_error != null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _load(),
                            child: const Text('Дахин оролдох'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (_items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Энэ төрөлд зар одоогоор алга.'),
                      ),
                    );
                  }
                  if (_hasMore) {
                    return TextButton(
                      onPressed: () => _load(),
                      child: const Text('Дараагийн 20 зар'),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Бүх зарыг харууллаа.')),
                  );
                }
                final item = _items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      item.type == 'lost'
                          ? Icons.search
                          : Icons.inventory_2_outlined,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.type == 'lost' ? 'Гээсэн' : 'Олсон'} • ${item.category}\n'
                      '${item.district} • ${item.placeName}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailPage(itemId: item.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
