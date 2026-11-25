import 'package:firebase_auth/firebase_auth.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../services/media.dart';
import '../items/item_detail_page.dart';
import 'framework.dart';

class ClaimsPage extends StatelessWidget {
  const ClaimsPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Нэхэмжлэлүүд'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Миний илгээсэн'),
            Tab(text: 'Ирсэн хүсэлт'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          for (final incoming in [false, true])
            ServerListPage(
              title: incoming ? 'Ирсэн хүсэлт' : 'Илгээсэн хүсэлт',
              operation: incoming ? 'incomingClaims' : 'myClaims',
              tile: (c, r, refresh) => Card(
                child: ListTile(
                  title: Text('${r['itemTitle']}'),
                  subtitle: Text(
                    '${statusLabel(r['status'] as String?)}\n${dateLabel(r['createdAt'])}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await openPage(c, ClaimDetailPage(id: r['id'] as String));
                    refresh();
                  },
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget claimForm({
  required String itemId,
  required String title,
  String? claimId,
}) {
  final id = claimId ?? newId();
  return ActionForm(
    title: claimId == null ? 'Эзэмшлийн нэхэмжлэл' : 'Маргаан үүсгэх',
    submitLabel: claimId == null ? 'Нэхэмжлэл илгээх' : 'Маргаан бүртгүүлэх',
    operation: claimId == null ? 'createClaim' : 'createDispute',
    payload: claimId == null
        ? {'id': id, 'itemId': itemId}
        : {'claimId': claimId},
    fields: [
      FieldSpec(
        claimId == null ? 'answer' : 'reason',
        claimId == null
            ? 'Нууц онцлог, эзэмшлийн нотолгоо'
            : 'Маргааны үндэслэл',
        min: 10,
        max: claimId == null ? 500 : 2000,
        lines: 4,
      ),
      if (claimId == null)
        const FieldSpec(
          'contents',
          'Нэмэлт тайлбар',
          min: 0,
          max: 300,
          lines: 3,
        ),
    ],
    photos: true,
    photoId: id,
    message:
        '$title\nЭнэ мэдээллийг зөвхөн та, зар эзэмшигч болон эрх бүхий админ харна.',
  );
}

class ClaimDetailPage extends StatefulWidget {
  const ClaimDetailPage({super.key, required this.id});
  final String id;
  @override
  State<ClaimDetailPage> createState() => _ClaimDetailPageState();
}

class _ClaimDetailPageState extends State<ClaimDetailPage> {
  late Future<Map<String, dynamic>> _data;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _data = Api.shared.run('getClaim', {'id': widget.id}));
  }

  Future<void> _run(String op, Map<String, dynamic> p) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.shared.run(op, p);
      if (mounted) {
        _reload();
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

  Future<void> _form(Widget page) async {
    await openPage(context, page);
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Нэхэмжлэлийн дэлгэрэнгүй'),
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
              title: 'Уншиж чадсангүй',
              message: errorText(s.error!),
              action: 'Дахин оролдох',
              onAction: _reload,
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = s.data!,
              c = jsonMap(r['claim']),
              i = jsonMap(r['item']),
              uid = FirebaseAuth.instance.currentUser?.uid,
              owner = c['ownerId'] == uid,
              claimant = c['claimantId'] == uid;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${c['itemTitle']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              InfoBanner(text: statusLabel(c['status'] as String?)),
              TextButton.icon(
                onPressed: () => openPage(
                  context,
                  ItemDetailPage(itemId: i['id'] as String),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Зарыг харах'),
              ),
              const SizedBox(height: 16),
              Text(
                'Эзэмшлийн тайлбар',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SelectableText('${c['answer']}\n${c['contents'] ?? ''}'),
              if (r['secretDetail'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: InfoBanner(
                    text: 'Зарын нууц онцлог: ${r['secretDetail']}',
                  ),
                ),
              for (final path in List<String>.from(
                c['proofPaths'] as List? ?? [],
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: StorageImage(
                    path: path,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ),
              if (c['decisionReason'] != null && c['decisionReason'] != '')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: InfoBanner(
                    text: 'Шийдвэрийн үндэслэл: ${c['decisionReason']}',
                  ),
                ),
              if (owner && c['status'] == 'pending') ...[
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await confirmAction(
                            context,
                            'Эзэмшлийг баталгаажуулах уу?',
                            'Нэг эзэмшигчийг баталж, бусад хүлээгдэж буй хүсэлтэд татгалзана.',
                          )) {
                            await _run('decideClaim', {
                              'id': widget.id,
                              'approve': true,
                            });
                          }
                        },
                  child: const Text('Нэхэмжлэлийг батлах'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _form(
                          ActionForm(
                            title: 'Татгалзах үндэслэл',
                            submitLabel: 'Татгалзах',
                            operation: 'decideClaim',
                            payload: {'id': widget.id, 'approve': false},
                            fields: const [
                              FieldSpec(
                                'reason',
                                'Шалтгаан',
                                min: 5,
                                max: 300,
                                lines: 4,
                              ),
                            ],
                          ),
                        ),
                  child: const Text('Шалтгаантай татгалзах'),
                ),
              ],
              if (claimant && c['status'] == 'pending')
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await confirmAction(
                            context,
                            'Хүсэлтээ буцаах уу?',
                            'Хүлээгдэж буй нэхэмжлэлийг цуцална.',
                          )) {
                            await _run('withdrawClaim', {'id': widget.id});
                          }
                        },
                  child: const Text('Нэхэмжлэлээ буцаах'),
                ),
              if (claimant &&
                  c['status'] == 'rejected' &&
                  i['status'] != 'returned')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _form(
                          claimForm(
                            itemId: i['id'] as String,
                            title: c['itemTitle'] as String,
                            claimId: widget.id,
                          ),
                        ),
                  child: const Text('Маргаан үүсгэх'),
                ),
              if (r['contacts'] != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Баталгаажсан хоёр талын холбоо',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final e in jsonMap(r['contacts']).entries)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text('${jsonMap(e.value)['name']}'),
                      subtitle: SelectableText(
                        '${jsonMap(e.value)['email']}\n${jsonMap(e.value)['phone']}',
                      ),
                    ),
                  ),
              ],
              if (c['handover'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: InfoBanner(
                    text:
                        'Хүлээлцэх уулзалт\n${dateLabel(jsonMap(c['handover'])['meetAt'])}\n${jsonMap(c['handover'])['place']}\n${jsonMap(c['handover'])['note'] ?? ''}',
                  ),
                ),
              if (owner &&
                  c['status'] == 'verified' &&
                  i['status'] == 'verified') ...[
                if (c['handover'] == null)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _form(HandoverForm(claimId: widget.id)),
                    icon: const Icon(Icons.event_available),
                    label: const Text('Уулзах цаг, газар товлох'),
                  ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await confirmAction(
                            context,
                            'Эд зүйлийг хүлээлцсэн үү?',
                            'Эд зүйлийг бодитоор буцаан өгсний дараа батална.',
                          )) {
                            await _run('markReturned', {'id': i['id']});
                          }
                        },
                  child: const Text('Буцаан олгосон гэж тэмдэглэх'),
                ),
              ],
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    ),
  );
}

class HandoverForm extends StatefulWidget {
  const HandoverForm({super.key, required this.claimId});
  final String claimId;
  @override
  State<HandoverForm> createState() => _HandoverFormState();
}

class _HandoverFormState extends State<HandoverForm> {
  final _form = GlobalKey<FormState>(),
      _place = TextEditingController(),
      _note = TextEditingController();
  DateTime? _meetAt;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (day == null || !mounted) {
      return;
    }
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null && mounted) {
      setState(
        () =>
            _meetAt = DateTime(day.year, day.month, day.day, t.hour, t.minute),
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_meetAt == null || !_meetAt!.isAfter(DateTime.now())) {
      setState(() => _error = 'Ирээдүйн уулзах цаг сонгоно уу.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.shared.run('scheduleHandover', {
        'id': widget.claimId,
        'place': _place.text,
        'note': _note.text,
        'meetAt': _meetAt!.toUtc().toIso8601String(),
      });
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Хүлээлцэх уулзалт')),
      body: ContentWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _meetAt == null
                        ? 'Уулзах цаг сонгох'
                        : dateLabel(_meetAt!.toIso8601String()),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _place,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Уулзах газар'),
                  validator: (v) => (v?.trim().length ?? 0) < 3
                      ? 'Газрыг тодорхой оруулна уу.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Нэмэлт тайлбар',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Уулзалт товлох'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
