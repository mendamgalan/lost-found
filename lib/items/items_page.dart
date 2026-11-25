import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../workflows/framework.dart';
import 'item.dart';
import 'item_card.dart';
import 'item_detail_page.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, this.ownerId, this.onCreate, this.admin = false});
  final String? ownerId;
  final VoidCallback? onCreate;
  final bool admin;
  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _search = TextEditingController(), _items = <Item>[];
  String? _cursor, _type, _category, _district, _status, _from, _to, _error;
  bool _loading = false, _more = false;
  Timer? _debounce;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load(true);
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load(bool reset) async {
    if (_loading && !reset) {
      return;
    }
    final generation = reset ? ++_generation : _generation;
    if (_search.text.trim().isNotEmpty && _search.text.trim().length < 3) {
      setState(() {
        _error = 'Хайлтын үг 3-аас доошгүй тэмдэгттэй байна.';
        _loading = false;
        _items.clear();
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
      }
    });
    try {
      final r = await Api.shared.run('listItems', {
        'ownerOnly': widget.ownerId != null,
        'admin': widget.admin,
        'query': _search.text,
        'type': _type,
        'category': _category,
        'district': _district,
        'status': _status,
        'from': _from,
        'to': _to,
        'cursor': reset ? null : _cursor,
      });
      if (mounted && generation == _generation) {
        setState(() {
          final ids = _items.map((i) => i.id).toSet();
          _items.addAll(
            jsonRows(r['items'])
                .map(Item.fromJson)
                .where((i) => !ids.contains(i.id)),
          );
          _cursor = r['cursor'] as String?;
          _more = r['hasMore'] == true;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _reset() {
    _debounce?.cancel();
    _load(true);
  }

  Future<void> _filters() async {
    String? district = _district, status = _status, from = _from, to = _to;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Хайлтаа нарийвчлах',
                style: Theme.of(c).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: district ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Дүүрэг'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Бүх дүүрэг')),
                  for (final d in itemDistricts)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => setSheet(() => district = v == '' ? null : v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: status ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Төлөв'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Бүх идэвхтэй'),
                  ),
                  for (final s
                      in widget.admin || widget.ownerId != null
                          ? [
                              'open',
                              'claimed',
                              'verified',
                              'returned',
                              'expired',
                              if (widget.admin) 'hidden',
                            ]
                          : ['open', 'claimed', 'verified'])
                    DropdownMenuItem(value: s, child: Text(statusLabel(s))),
                ],
                onChanged: (v) => setSheet(() => status = v == '' ? null : v),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(from == null ? 'Огнооны хүрээ' : '$from → $to'),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: c,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (range != null) {
                    setSheet(() {
                      from = range.start.toIso8601String().substring(0, 10);
                      to = range.end.toIso8601String().substring(0, 10);
                    });
                  }
                },
              ),
              TextButton(
                onPressed: () => setSheet(() {
                  district = null;
                  status = null;
                  from = null;
                  to = null;
                }),
                child: const Text('Цэвэрлэх'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Шүүлтүүр хэрэглэх'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _district = district;
        _status = status;
        _from = from;
        _to = to;
      });
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: widget.admin
          ? const Text('Зарын хяналт')
          : widget.ownerId != null
          ? const Text('Миний зарууд')
          : const Brand(),
      actions: [
        IconButton(
          tooltip: 'Шинэчлэх',
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ContentWidth(
      width: 1040,
      child: RefreshIndicator(
        onRefresh: () => _load(true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.ownerId == null
                  ? 'Эзнээ олох жижиг тус'
                  : 'Таны нийтэлсэн зарууд',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reset(),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 400),
                        _reset,
                      );
                    },
                    decoration: const InputDecoration(
                      labelText: 'Эд зүйлийн нэр, тайлбар',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Шүүлтүүр',
                  onPressed: _filters,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final t in <String?>[null, 'lost', 'found'])
                  ChoiceChip(
                    label: Text(
                      t == null
                          ? 'Бүгд'
                          : t == 'lost'
                          ? 'Гээсэн'
                          : 'Олсон',
                    ),
                    selected: _type == t,
                    onSelected: (_) {
                      setState(() => _type = t);
                      _reset();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in itemCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(categoryIcon(cat), size: 18),
                        label: Text(cat),
                        selected: _category == cat,
                        onSelected: (_) {
                          setState(
                            () => _category = _category == cat ? null : cat,
                          );
                          _reset();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_district != null || _from != null || _status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InfoBanner(
                  text: [
                    ?_district,
                    if (_from != null) '$_from → $_to',
                    if (_status != null) statusLabel(_status),
                  ].join(' · '),
                ),
              ),
            LayoutBuilder(
              builder: (c, b) {
                final n = b.maxWidth >= 880
                        ? 3
                        : b.maxWidth >= 570
                        ? 2
                        : 1,
                    w = (b.maxWidth - (n - 1) * 16) / n;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final item in _items)
                      SizedBox(
                        width: w,
                        child: ItemCard(
                          item: item,
                          onTap: () async {
                            await openPage(
                              context,
                              ItemDetailPage(itemId: item.id),
                            );
                            if (mounted) {
                              _reset();
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              StateMessage(
                title: 'Заруудыг уншиж чадсангүй',
                message: _error!,
                action: 'Дахин оролдох',
                onAction: _reset,
              ),
            if (!_loading && _error == null && _items.isEmpty)
              StateMessage(
                title: 'Тохирох зар алга',
                message: 'Өөр үг эсвэл шүүлтүүр сонгоорой.',
                action: widget.onCreate == null ? null : 'Зар нэмэх',
                onAction: widget.onCreate,
              ),
            if (_more && !_loading)
              OutlinedButton(
                onPressed: () => _load(false),
                child: const Text('Дараагийн зарууд'),
              ),
          ],
        ),
      ),
    ),
  );
}
