import 'package:firebase_auth/firebase_auth.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/media.dart';
import '../core/ui.dart';
export '../services/api.dart';

String statusLabel(String? s) => switch (s) {
  'open' => 'Нээлттэй',
  'claimed' => 'Нэхэмжлэлтэй',
  'pending' => 'Хүлээгдэж буй',
  'verified' => 'Баталгаажсан',
  'rejected' => 'Татгалзсан',
  'returned' => 'Буцаан олгосон',
  'expired' => 'Хугацаа дууссан',
  'withdrawn' => 'Буцаан татсан',
  'disputed' => 'Маргаантай',
  'resolved' => 'Шийдвэрлэсэн',
  'hidden' => 'Нуугдсан',
  _ => s ?? '',
};
String dateLabel(dynamic v) {
  final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
  return d == null
      ? '—'
      : '${displayDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Тийм'),
          ),
        ],
      ),
    ) ??
    false;
Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

class ServerListPage extends StatefulWidget {
  const ServerListPage({
    super.key,
    required this.title,
    required this.operation,
    this.payload = const {},
    this.rowKey = 'rows',
    this.header,
    required this.tile,
  });
  final String title, operation, rowKey;
  final Map<String, dynamic> payload;
  final Widget? header;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback) tile;
  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  final _rows = <Map<String, dynamic>>[];
  bool _busy = false;
  String? _cursor, _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load(true);
  }

  @override
  void didUpdateWidget(ServerListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operation != widget.operation ||
        oldWidget.payload.toString() != widget.payload.toString()) {
      _load(true);
    }
  }

  Future<void> _load(bool reset) async {
    if (_busy && !reset) {
      return;
    }
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.shared.run(widget.operation, {
        ...widget.payload,
        'cursor': reset ? null : _cursor,
      });
      if (mounted && generation == _generation) {
        setState(() {
          if (reset) {
            _rows.clear();
          }
          _rows.addAll(jsonRows(r[widget.rowKey]));
          _cursor = r['cursor'] as String?;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Шинэчлэх',
          onPressed: () => _load(true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ContentWidth(
      child: RefreshIndicator(
        onRefresh: () => _load(true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.header != null) widget.header!,
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: widget.tile(context, row, () => _load(true)),
              ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              StateMessage(
                title: 'Мэдээлэл татаж чадсангүй',
                message: _error!,
                action: 'Дахин оролдох',
                onAction: () => _load(_rows.isEmpty),
              ),
            if (!_busy && _rows.isEmpty && _error == null)
              const StateMessage(
                title: 'Одоогоор мэдээлэл алга',
                message: 'Шинэ мэдээлэл ирэхэд энд харагдана.',
              ),
            if (_cursor != null && !_busy)
              OutlinedButton(
                onPressed: () => _load(false),
                child: const Text('Цааш үзэх'),
              ),
          ],
        ),
      ),
    ),
  );
}

class FieldSpec {
  const FieldSpec(
    this.keyName,
    this.label, {
    this.min = 1,
    this.max = 2000,
    this.lines = 1,
    this.initial = '',
    this.secret = false,
  });
  final String keyName, label, initial;
  final int min, max, lines;
  final bool secret;
}

class ActionForm extends StatefulWidget {
  const ActionForm({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.operation,
    this.payload = const {},
    required this.fields,
    this.photos = false,
    this.photoId,
    this.message,
  });
  final String title, submitLabel, operation;
  final Map<String, dynamic> payload;
  final List<FieldSpec> fields;
  final bool photos;
  final String? photoId, message;
  @override
  State<ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<ActionForm> {
  final _form = GlobalKey<FormState>(), _media = MediaSelection();
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields)
      f.keyName: TextEditingController(text: f.initial),
  };
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = {
        ...widget.payload,
        for (final f in widget.fields) f.keyName: _controllers[f.keyName]!.text,
      };
      if (widget.photos) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        payload['proofPaths'] = await _media.upload(
          'claims/$uid/${widget.photoId}',
        );
      }
      await Api.shared.run(widget.operation, payload);
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
      appBar: AppBar(title: Text(widget.title)),
      body: ContentWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.message != null) ...[
                  InfoBanner(text: widget.message!),
                  const SizedBox(height: 24),
                ],
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: TextFormField(
                      controller: _controllers[f.keyName],
                      enabled: !_busy,
                      obscureText: f.secret,
                      maxLength: f.max,
                      maxLines: f.lines,
                      decoration: InputDecoration(labelText: f.label),
                      validator: (v) => (v?.trim().length ?? 0) < f.min
                          ? '${f.min}-аас доошгүй тэмдэгт оруулна уу.'
                          : null,
                    ),
                  ),
                if (widget.photos) ...[
                  MediaPicker(selection: _media, limit: 3, enabled: !_busy),
                  const SizedBox(height: 20),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Хадгалж байна…' : widget.submitLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
