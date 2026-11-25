import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/api.dart';
import '../services/media.dart';
import 'item.dart';

// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'item_repository.dart';
import '../core/ui.dart';
import '../core/app_theme.dart';

class CreateItemPage extends StatefulWidget {
  const CreateItemPage({super.key, this.item, this.secretDetail = ''});
  final Item? item;
  final String secretDetail;

  @override
  State<CreateItemPage> createState() => _CreateItemPageState();
}

class _CreateItemPageState extends State<CreateItemPage> {
  final _form = GlobalKey<FormState>();
  final _repository = ItemRepository();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _secret = TextEditingController();
  String _type = 'lost';
  String? _category;
  String? _district;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _allowPop = false;
  bool _askingDiscard = false;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  late final _media = MediaSelection(widget.item?.imagePaths ?? []);
  late final _id = widget.item?.id ?? newId();
  late String _initialDraft;
  String get _signature => jsonEncode([
    _title.text,
    _description.text,
    _place.text,
    _secret.text,
    _type,
    _category,
    _district,
    _date.toIso8601String(),
    _media.paths,
    _media.pending.map((v) => identityHashCode(v.bytes)).toList(),
  ]);
  bool get _hasChanges => _signature != _initialDraft;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _title.text = i.title;
      _description.text = i.description;
      _place.text = i.placeName;
      _secret.text = widget.secretDetail;
      _type = i.type;
      _category = i.category;
      _district = i.district;
      _date = i.eventDate;
    }
    _initialDraft = _signature;
    for (final controller in [_title, _description, _place, _secret]) {
      controller.addListener(_onEdit);
    }
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  Future<void> _discard() async {
    if (_saving || _askingDiscard) return;
    _askingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бичиж буй зараа орхих уу?'),
        content: const Text('Нийтлээгүй мэдээлэл хадгалагдахгүй.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Үргэлжлүүлэх'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Орхих'),
          ),
        ],
      ),
    );
    _askingDiscard = false;
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Огноо сонгох',
      cancelText: 'Болих',
      confirmText: 'Сонгох',
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _save() async {
    if (_saving || _saved || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final images = await _media.upload('items/$uid/$_id');
      if (widget.item != null) {
        await Api.shared.run('updateItem', {
          'id': _id,
          'type': _type,
          'title': _title.text,
          'description': _description.text,
          'category': _category,
          'district': _district,
          'placeName': _place.text,
          'secretDetail': _secret.text,
          'eventDate':
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          'imagePaths': images,
        });
      } else {
        await _repository.createItem(
          id: _id,
          type: _type,
          title: _title.text,
          category: _category!,
          description: _description.text,
          eventDate: _date,
          district: _district!,
          placeName: _place.text,
          secretDetail: _secret.text,
          imagePaths: images,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saved = true;
      });
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.code) {
            'permission-denied' => 'Зар нийтлэх эрхийг баталгаажуулж чадсангүй. Профайлаа гүйцээж дахин оролдоно уу.',
            'unavailable' =>
              'Үйлчилгээнд холбогдож чадсангүй. Холболтоо шалгана уу.',
            'unauthenticated' => 'Дахин нэвтэрнэ үү.',
            _ => 'Зар хадгалагдсангүй (${e.code}). Дахин оролдоно уу.',
          },
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() => _error = e.message.toString());
      }
    } on StateError catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Зар хадгалж чадсангүй. Дахин оролдоно уу.');
      }
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    int maxLength, {
    int lines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLength: maxLength,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return '$label оруулна уу.';
          }
          if (text.length > maxLength) {
            return '$maxLength тэмдэгтээс хэтрэхгүй байна.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
        '${_date.day.toString().padLeft(2, '0')}';
    return PopScope(
      canPop: !_saving && (_allowPop || _saved || !_hasChanges),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.item == null ? 'Зар нийтлэх' : 'Зар засах'),
        ),
        body: ContentWidth(
          child: _saved
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 16),
                        const Text('Зар амжилттай хадгалагдлаа.'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Буцах'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Жижиг тус. Том баяр.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Мэдээллээ тодорхой бичвэл эзнээ олох боломж нэмэгдэнэ.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 24),
                        const InfoBanner(
                          text: '5 хүртэл JPG/PNG зураг нэмж болно. Нууц шинжээ зөвхөн тусгай талбарт бичээрэй.',
                          icon: Icons.info_outline,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '01  Эд зүйлийн мэдээлэл',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Зарын төрөл',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'lost',
                              child: Text('Гээсэн'),
                            ),
                            DropdownMenuItem(
                              value: 'found',
                              child: Text('Олсон'),
                            ),
                          ],
                          onChanged: _saving || widget.item != null
                              ? null
                              : (v) => setState(() => _type = v!),
                        ),
                        const SizedBox(height: 20),
                        _textField(_title, 'Эд зүйлийн нэр', 120),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ангилал',
                          ),
                          initialValue: _category,
                          items: itemCategories
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _category = v),
                          validator: (v) =>
                              v == null ? 'Ангилал сонгоно уу.' : null,
                        ),
                        const SizedBox(height: 20),
                        _textField(
                          _description,
                          'Нийтийн тайлбар',
                          2000,
                          lines: 3,
                          helper: 'Нууц онцлог, email, утсаа энд бичихгүй.',
                        ),
                        Text(
                          '02  Хэзээ, хаана?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${_type == 'lost' ? 'Гээсэн' : 'Олсон'} огноо: $dateLabel',
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Дүүрэг',
                          ),
                          initialValue: _district,
                          items: itemDistricts
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _district = v),
                          validator: (v) =>
                              v == null ? 'Дүүрэг сонгоно уу.' : null,
                        ),
                        const SizedBox(height: 20),
                        _textField(_place, 'Газрын нэр', 200),
                        Text(
                          '03  Зөвхөн танд харагдах мэдээлэл',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          _secret,
                          'Нууц онцлог',
                          1000,
                          lines: 3,
                          helper: 'Бусдад харагдахгүй. Жишээ: доторх зүйл эсвэл далд тэмдэг.',
                        ),
                        MediaPicker(
                          selection: _media,
                          enabled: !_saving,
                          onChanged: _onEdit,
                        ),
                        const SizedBox(height: 20),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (_saving)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Серверийн баталгааг хүлээж байна. Интернет холболт шаардлагатай.',
                            ),
                          ),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving ? 'Хадгалж байна…' : 'Зар нийтлэх',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
