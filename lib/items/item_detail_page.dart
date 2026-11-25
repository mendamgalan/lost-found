import 'package:firebase_auth/firebase_auth.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../services/media.dart';
import '../workflows/framework.dart';
import '../workflows/claims.dart';
import '../auth/auth_page.dart';
import 'item.dart';
import 'create_item_page.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});
  final String itemId;
  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late Future<Map<String, dynamic>> _data;
  bool _admin = false, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
    _role();
  }

  Future<void> _role() async {
    try {
      final t = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
      if (mounted) {
        setState(() => _admin = t?.claims?['admin'] == true);
      }
    } catch (_) {}
  }

  void _reload() {
    setState(() => _data = Api.shared.run('getItem', {'id': widget.itemId}));
  }

  Future<void> _open(Widget page) async {
    await openPage(context, page);
    if (mounted) {
      _reload();
    }
  }

  Future<void> _delete() async {
    if (!await confirmAction(
      context,
      'Зарыг устгах уу?',
      'Идэвхтэй нэхэмжлэлгүй зарыг нийтийн жагсаалтаас устгана.',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.shared.run('deleteItem', {'id': widget.itemId});
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Зарын дэлгэрэнгүй'),
      actions: [
        IconButton(
          tooltip: 'Шинэчлэх',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ContentWidth(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, s) {
          if (s.hasError) {
            return StateMessage(
              title: 'Зарыг уншиж чадсангүй',
              message: errorText(s.error!),
              action: 'Дахин оролдох',
              onAction: _reload,
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = s.data!,
              i = Item.fromJson(jsonMap(r['item'])),
              uid = FirebaseAuth.instance.currentUser?.uid,
              mine = uid == i.ownerId,
              active = ['open', 'claimed'].contains(i.status);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (i.imagePaths.isEmpty)
                ItemArtwork(
                  category: i.category,
                  lost: i.type == 'lost',
                  height: 240,
                )
              else
                for (final path in i.imagePaths)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StorageImage(
                      path: path,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  StatusPill(
                    lost: i.type == 'lost',
                    returned: i.status == 'returned',
                  ),
                  Chip(label: Text(statusLabel(i.status))),
                  Chip(label: Text(i.category)),
                  if (i.isHidden) const Chip(label: Text('Нуугдсан')),
                ],
              ),
              const SizedBox(height: 16),
              SelectableText(
                i.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(i.district),
                      subtitle: Text(i.placeName),
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: Text(displayDate(i.eventDate)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Эд зүйлийн тухай',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SelectableText(i.description),
              if (r['secretDetail'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: InfoBanner(text: 'Нууц онцлог: ${r['secretDetail']}'),
                ),
              if (!mine && i.type == 'found' && active && !i.isHidden)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton(
                    onPressed: () => _open(
                      uid == null
                          ? const AuthPage()
                          : claimForm(itemId: i.id, title: i.title),
                    ),
                    child: Text(
                      uid == null ? 'Нэвтэрч нэхэмжлэх' : 'Миний эд зүйл мөн',
                    ),
                  ),
                ),
              if (mine) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _open(MatchesPage(itemId: i.id)),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Тохирох зарууд'),
                ),
                if (i.type == 'found')
                  OutlinedButton.icon(
                    onPressed: () => _open(const ClaimsPage(initialTab: 1)),
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Ирсэн нэхэмжлэлүүд'),
                  ),
                if (active)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _open(
                            CreateItemPage(
                              item: i,
                              secretDetail: r['secretDetail'] as String? ?? '',
                            ),
                          ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Зар засах'),
                  ),
                if (active || i.status == 'expired')
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Зар устгах'),
                  ),
                if (i.verifiedClaimId != null)
                  FilledButton(
                    onPressed: () =>
                        _open(ClaimDetailPage(id: i.verifiedClaimId!)),
                    child: const Text('Баталгаажсан хүсэлт, хүлээлцэлт'),
                  ),
              ],
              if (_admin) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _open(
                    ActionForm(
                      title: i.isHidden ? 'Зар ил гаргах' : 'Зар нуух',
                      submitLabel: 'Хадгалах',
                      operation: 'hideItem',
                      payload: {'id': i.id, 'hidden': !i.isHidden},
                      fields: const [
                        FieldSpec(
                          'reason',
                          'Шалтгаан',
                          min: 5,
                          max: 300,
                          lines: 3,
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(i.isHidden ? 'Зарыг ил гаргах' : 'Зарыг нуух'),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_busy) const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    ),
  );
}

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key, required this.itemId});
  final String itemId;
  @override
  Widget build(BuildContext context) => ServerListPage(
    title: 'Тохирох зарууд',
    operation: 'matches',
    payload: {'id': itemId},
    rowKey: 'matches',
    header: const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: InfoBanner(
        text: 'Ангилал 30 · Байршил 30 · Огноо 20 · Түлхүүр үг 20 оноо.',
      ),
    ),
    tile: (c, r, refresh) {
      final i = jsonMap(r['item']);
      return Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('${r['score']}')),
          title: Text('${i['title']}'),
          subtitle: Text(
            '${i['district']} · ${i['placeName']}\n${jsonMap(r['breakdown']).entries.map((e) => '${const {'category': 'Ангилал', 'location': 'Байршил', 'date': 'Огноо', 'keyword': 'Түлхүүр үг'}[e.key] ?? e.key}: ${e.value}').join(' · ')}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openPage(c, ItemDetailPage(itemId: i['id'] as String)),
        ),
      );
    },
  );
}
