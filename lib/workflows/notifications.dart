// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../items/item_detail_page.dart';
import 'claims.dart';
import 'framework.dart';

void openNotification(BuildContext context, Map<String, dynamic> r) {
  final id = r['refId'] as String?;
  if (id == null) {
    return;
  }
  openPage(
    context,
    r['refType'] == 'item'
        ? ItemDetailPage(itemId: id)
        : ClaimDetailPage(id: id),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unread = false, _busy = false;
  int _version = 0;
  Future<void> _readAll() async {
    setState(() => _busy = true);
    try {
      await Api.shared.run('markAllRead');
      if (mounted) {
        setState(() => _version++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ServerListPage(
    key: ValueKey(_version),
    title: 'Мэдэгдэл',
    operation: 'notifications',
    payload: {'unread': _unread},
    header: Column(
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Бүгд'),
              selected: !_unread,
              onSelected: (_) => setState(() => _unread = false),
            ),
            ChoiceChip(
              label: const Text('Уншаагүй'),
              selected: _unread,
              onSelected: (_) => setState(() => _unread = true),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: _busy ? null : _readAll,
          icon: const Icon(Icons.done_all),
          label: const Text('Бүгдийг уншсан болгох'),
        ),
        const SizedBox(height: 16),
      ],
    ),
    tile: (c, r, refresh) => Card(
      child: ListTile(
        leading: Icon(
          r['isRead'] == true
              ? Icons.notifications_none
              : Icons.notifications_active,
        ),
        title: Text(
          '${r['title']}',
          style: TextStyle(
            fontWeight: r['isRead'] == true
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Text('${r['body']}\n${dateLabel(r['createdAt'])}'),
        isThreeLine: true,
        onTap: () async {
          try {
            await Api.shared.run('markRead', {'id': r['id']});
            if (c.mounted) {
              openNotification(c, r);
              refresh();
            }
          } catch (e) {
            if (c.mounted) {
              ScaffoldMessenger.of(c)
                  .showSnackBar(SnackBar(content: Text(errorText(e))));
            }
          }
        },
        trailing: r['isRead'] == true
            ? null
            : IconButton(
                tooltip: 'Уншсан болгох',
                icon: const Icon(Icons.done),
                onPressed: () async {
                  try {
                    await Api.shared.run('markRead', {'id': r['id']});
                    refresh();
                  } catch (e) {
                    if (c.mounted) {
                      ScaffoldMessenger.of(c)
                          .showSnackBar(SnackBar(content: Text(errorText(e))));
                    }
                  }
                },
              ),
      ),
    ),
  );
}
