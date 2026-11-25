// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';

import '../core/ui.dart';
import '../services/media.dart';
import '../items/items_page.dart';
import 'framework.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _data = Api.shared.run('adminStats');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Админ хяналт'),
      actions: [
        IconButton(
          tooltip: 'Шинэчлэх',
          onPressed: () => setState(() => _data = Api.shared.run('adminStats')),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _data,
            builder: (c, s) {
              if (s.hasError) {
                return StateMessage(
                  title: 'Мэдээлэлд хандах боломжгүй',
                  message: errorText(s.error!),
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in {
                    'privateProfiles': 'Хэрэглэгч',
                    'items': 'Зар',
                    'claims': 'Нэхэмжлэл',
                    'returned': 'Буцаан олгосон',
                    'openDisputes': 'Нээлттэй маргаан',
                  }.entries)
                    SizedBox(
                      width: 150,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.data![entry.key] ?? 0}',
                                style: Theme.of(c).textTheme.headlineMedium,
                              ),
                              Text(entry.value),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          for (final route in <({String title, IconData icon, Widget page})>[
            (
              title: 'Маргаан шийдвэрлэх',
              icon: Icons.gavel,
              page: const AdminListPage(kind: 'disputes'),
            ),
            (
              title: 'Зарын хяналт',
              icon: Icons.inventory_2_outlined,
              page: const ItemsPage(admin: true),
            ),
            (
              title: 'Буцаан олголтын тайлан',
              icon: Icons.bar_chart,
              page: const AdminReportsPage(),
            ),
            (
              title: 'Хэрэглэгчид',
              icon: Icons.people_outline,
              page: const AdminListPage(kind: 'users'),
            ),
            (
              title: 'Аудитын түүх',
              icon: Icons.history,
              page: const AdminListPage(kind: 'audit'),
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: Icon(route.icon),
                  title: Text(route.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openPage(context, route.page),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key, required this.kind});
  final String kind;
  @override
  State<AdminListPage> createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  final _query = TextEditingController();
  String _applied = '';
  String? _filter;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.kind == 'users',
        disputes = widget.kind == 'disputes',
        labels = users
            ? {'': 'Бүгд', 'user': 'Хэрэглэгч', 'admin': 'Админ'}
            : disputes
            ? {'': 'Бүгд', 'open': 'Нээлттэй', 'resolved': 'Шийдвэрлэсэн'}
            : {
                '': 'Бүх үйлдэл',
                for (final a in [
                  'item.create',
                  'item.update',
                  'item.delete',
                  'item.hide',
                  'item.unhide',
                  'claim.create',
                  'claim.verify',
                  'claim.reject',
                  'claim.withdraw',
                  'claim.revoke',
                  'handover.schedule',
                  'item.return',
                  'dispute.create',
                  'dispute.resolve',
                  'item.expire',
                ])
                  a: a,
              };
    return ServerListPage(
      title: users
          ? 'Хэрэглэгчид'
          : disputes
          ? 'Маргаанууд'
          : 'Аудитын түүх',
      operation: users
          ? 'adminUsers'
          : disputes
          ? 'adminDisputes'
          : 'adminAudit',
      payload: {
        'query': _applied,
        users
                ? 'role'
                : disputes
                ? 'status'
                : 'action':
            _filter,
      },
      header: Column(
        children: [
          if (!disputes) ...[
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _applied = v),
              decoration: InputDecoration(
                labelText: users
                    ? 'Нэр, имэйл, утас хайх'
                    : 'Гүйцэтгэгч, үйлдэл, объект хайх',
                suffixIcon: IconButton(
                  tooltip: 'Хайх',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _applied = _query.text),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _filter ?? '',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: users
                  ? 'Үүрэг'
                  : disputes
                  ? 'Төлөв'
                  : 'Үйлдэл',
            ),
            items: [
              for (final e in labels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _filter = v == '' ? null : v),
          ),
          const SizedBox(height: 20),
        ],
      ),
      tile: (c, r, refresh) => Card(
        child: ListTile(
          title: Text(
            users
                ? '${r['name']}'
                : disputes
                ? '${r['itemTitle']}'
                : '${r['action']}',
          ),
          subtitle: SelectableText(
            users
                ? '${r['email']}\n${r['phone']} · ${r['role'] ?? 'user'}\nЗар ${r['itemCount']} · Нэхэмжлэл ${r['claimCount']}'
                : disputes
                ? '${statusLabel(r['status'] as String?)}\n${r['reason']}'
                : '${r['actorName']} · ${r['actorId']}\n${r['targetId']} · ${dateLabel(r['createdAt'])}\n${r['note'] ?? r['reason'] ?? ''}',
          ),
          trailing: disputes ? const Icon(Icons.chevron_right) : null,
          onTap: disputes
              ? () async {
                  await openPage(c, AdminDisputePage(id: r['id'] as String));
                  refresh();
                }
              : null,
        ),
      ),
    );
  }
}

class AdminDisputePage extends StatefulWidget {
  const AdminDisputePage({super.key, required this.id});
  final String id;
  @override
  State<AdminDisputePage> createState() => _AdminDisputePageState();
}

class _AdminDisputePageState extends State<AdminDisputePage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _data = Api.shared.run('getDispute', {'id': widget.id}));
  }

  Future<void> _resolve(bool approve) async {
    await openPage(
      context,
      ActionForm(
        title: 'Маргааны эцсийн шийдвэр',
        submitLabel: approve
            ? 'Нэхэмжлэгчийг батлах'
            : 'Татгалзлыг хэвээр үлдээх',
        operation: 'resolveDispute',
        payload: {'id': widget.id, 'approve': approve},
        message: approve
            ? 'Эд зүйл буцаагдаагүй үед өмнөх буруу баталгаажуулалтыг цуцалж шинэ эзэмшигчийг тогтооно.'
            : 'Шийдвэр аудитын түүхэнд хадгалагдана.',
        fields: const [
          FieldSpec(
            'note',
            'Шийдвэрийн үндэслэл',
            min: 10,
            max: 2000,
            lines: 5,
          ),
        ],
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Маргаан хянах')),
    body: ContentWidth(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (c, s) {
          if (s.hasError) {
            return StateMessage(
              title: 'Маргааныг уншиж чадсангүй',
              message: errorText(s.error!),
              action: 'Дахин оролдох',
              onAction: _reload,
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = s.data!,
              d = jsonMap(r['dispute']),
              claim = jsonMap(r['claim']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${d['itemTitle']}',
                style: Theme.of(c).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              InfoBanner(
                text: '${statusLabel(d['status'] as String?)}\n${d['reason']}',
              ),
              const SizedBox(height: 20),
              Text(
                'Нэхэмжлэгчийн нотолгоо',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              SelectableText('${claim['answer']}\n${claim['contents'] ?? ''}'),
              const SizedBox(height: 20),
              InfoBanner(text: 'Олсон хүний нууц онцлог: ${r['secretDetail']}'),
              for (final path in [
                ...List<String>.from(claim['proofPaths'] as List? ?? []),
                ...List<String>.from(d['proofPaths'] as List? ?? []),
              ])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: StorageImage(
                    path: path,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 16),
              SelectableText(
                'Татгалзлын үндэслэл: ${claim['decisionReason'] ?? ''}',
              ),
              const SizedBox(height: 20),
              if (d['status'] == 'open') ...[
                FilledButton(
                  onPressed: () => _resolve(true),
                  child: const Text('Нэхэмжлэгчийг баталгаажуулах'),
                ),
                OutlinedButton(
                  onPressed: () => _resolve(false),
                  child: const Text('Татгалзлыг хэвээр үлдээх'),
                ),
              ] else
                InfoBanner(
                  text:
                      'Шийдвэр: ${d['decision']}\n${d['note']}\n${dateLabel(d['resolvedAt'])}',
                ),
            ],
          );
        },
      ),
    ),
  );
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _summary = {}, _insights = {};
  String? _from, _to, _cursor, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load(true);
  }

  Future<void> _load(bool reset) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.shared.run('adminReports', {
        'from': _from,
        'to': _to,
        'cursor': reset ? null : _cursor,
      });
      if (mounted) {
        setState(() {
          if (reset) {
            _rows.clear();
          }
          _rows.addAll(jsonRows(r['rows']));
          _summary = jsonMap(r['summary']);
          _insights = jsonMap(r['insights']);
          _cursor = r['cursor'] as String?;
        });
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

  Future<void> _range() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (r != null && mounted) {
      setState(() {
        _from = r.start.toIso8601String().substring(0, 10);
        _to = r.end.toIso8601String().substring(0, 10);
      });
      _load(true);
    }
  }

  Future<void> _export(bool all) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.shared.run('adminReportExport', {
            'scope': all ? 'items' : 'returned',
            'from': _from,
            'to': _to,
          }),
          bytes = await FirebaseStorage.instance
              .ref(r['path'] as String)
              .getData(30 * 1024 * 1024);
      if (bytes == null) {
        throw StateError('Тайлан хоосон.');
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'lost-found-report.csv',
            ),
          ],
          fileNameOverrides: ['lost-found-report.csv'],
        ),
      );
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
    appBar: AppBar(title: const Text('Буцаан олголтын тайлан')),
    body: ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final n in [7, 30, 90])
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final today = DateTime.now();
                          setState(() {
                            _to = today.toIso8601String().substring(0, 10);
                            _from = today
                                .subtract(Duration(days: n - 1))
                                .toIso8601String()
                                .substring(0, 10);
                          });
                          _load(true);
                        },
                  child: Text('$n хоног'),
                ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _range,
            icon: const Icon(Icons.date_range),
            label: Text(_from == null ? 'Огноогоор шүүх' : '$_from → $_to'),
          ),
          if (_from != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _from = null;
                        _to = null;
                      });
                      _load(true);
                    },
              child: const Text('Хугацааг цэвэрлэх'),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : () => _export(false),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Буцаан олголтын CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _export(true),
            icon: const Icon(Icons.table_view),
            label: const Text('Бүх зарын хугацааны CSV'),
          ),
          const SizedBox(height: 20),
          for (final e in {
            'totals': 'Хугацааны нийт үзүүлэлт',
            'categories': 'Ангиллын задаргаа',
            'itemStates': 'Зарын төлөв',
            'claimStates': 'Нэхэмжлэлийн төлөв',
            'trend': 'Сарын чиг хандлага',
          }.entries)
            if (jsonMap(_insights[e.key]).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          e.value,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        for (final n in jsonMap(_insights[e.key]).entries) ...[
                          Text(
                            '${statusLabel(n.key).replaceAll(' · lost', ' · Гээсэн').replaceAll(' · found', ' · Олсон')} · ${n.value}',
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value:
                                (n.value as num).toDouble() /
                                jsonMap(_insights[e.key]).values
                                    .cast<num>()
                                    .fold<num>(1, (a, b) => a > b ? a : b)
                                    .toDouble(),
                            semanticsLabel: n.key,
                            semanticsValue: '${n.value}',
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          for (final e in _summary.entries)
            ListTile(title: Text(e.key), trailing: Text('${e.value}')),
          for (final row in _rows)
            Card(
              child: ListTile(
                title: Text('${row['title']}'),
                subtitle: Text(
                  '${row['category']} · ${dateLabel(row['returnedAt'])}',
                ),
              ),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            StateMessage(
              title: 'Тайлан уншиж чадсангүй',
              message: _error!,
              action: 'Дахин оролдох',
              onAction: () => _load(_rows.isEmpty),
            ),
          if (_cursor != null && !_busy)
            OutlinedButton(
              onPressed: () => _load(false),
              child: const Text('Цааш үзэх'),
            ),
          if (!_busy && _rows.isEmpty && _error == null)
            const StateMessage(
              title: 'Буцаан олголт алга',
              message: 'Сонгосон хугацаанд бүртгэл олдсонгүй.',
            ),
        ],
      ),
    ),
  );
}
