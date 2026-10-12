import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'item_repository.dart';

class CreateItemPage extends StatefulWidget {
  const CreateItemPage({super.key});

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
  bool _saving = false;
  bool _saved = false;
  String? _error;

  static const _categories = [
    'Утас',
    'Түрийвч',
    'Түлхүүр',
    'Бичиг баримт',
    'Цүнх',
    'Электрон төхөөрөмж',
    'Бусад',
  ];
  static const _districts = [
    'Баянгол',
    'Баянзүрх',
    'Сүхбаатар',
    'Сонгинохайрхан',
    'Хан-Уул',
    'Чингэлтэй',
    'Багануур',
    'Багахангай',
    'Налайх',
  ];

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
      await _repository.createItem(
        type: _type,
        title: _title.text,
        category: _category!,
        description: _description.text,
        eventDate: _date,
        district: _district!,
        placeName: _place.text,
        secretDetail: _secret.text,
      );
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
            'permission-denied' => 'Хадгалах эрхгүй байна. Профайлаа гүйцээсэн эсэх болон шинэ Rules байршуулсан эсэхийг шалгана уу.',
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
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Зар нэмэх')),
        body: _saved
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
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Зарын төрөл',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'lost', child: Text('Гээсэн')),
                        DropdownMenuItem(value: 'found', child: Text('Олсон')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _type = v!),
                    ),
                    const SizedBox(height: 20),
                    _textField(_title, 'Эд зүйлийн нэр', 120),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Ангилал'),
                      items: _categories
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
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
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        '${_type == 'lost' ? 'Гээсэн' : 'Олсон'} огноо: $dateLabel',
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Дүүрэг'),
                      items: _districts
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _district = v),
                      validator: (v) => v == null ? 'Дүүрэг сонгоно уу.' : null,
                    ),
                    const SizedBox(height: 20),
                    _textField(_place, 'Газрын нэр', 200),
                    _textField(
                      _secret,
                      'Нууц онцлог',
                      1000,
                      lines: 3,
                      helper: 'Бусдад харагдахгүй. Жишээ: доторх зүйл эсвэл далд тэмдэг.',
                    ),
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
                      child: Text(_saving ? 'Хадгалж байна…' : 'Зар хадгалах'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
