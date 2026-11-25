import 'package:firebase_auth/firebase_auth.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/ui.dart';
import 'framework.dart';

Widget profileForm(String name, String phone) => ActionForm(
  title: 'Профайл засах',
  submitLabel: 'Хадгалах',
  operation: 'updateProfile',
  fields: [
    FieldSpec('name', 'Нэр', initial: name, max: 80),
    FieldSpec('phone', 'Утас — 8 оронтой', initial: phone, min: 8, max: 8),
  ],
  message: 'Холбоо барих мэдээлэл зөвхөн баталгаажсан нэхэмжлэлийн хоёр талд нээгдэнэ.',
);

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});
  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _form = GlobalKey<FormState>(),
      _current = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw StateError('Нэвтрэх шаардлагатай.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: _current.text,
        ),
      );
      await user.updatePassword(_password.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Нууц үг шинэчлэгдлээ.')));
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.code) {
            'wrong-password' ||
            'invalid-credential' => 'Одоогийн нууц үг буруу байна.',
            'weak-password' => 'Илүү найдвартай нууц үг сонгоно уу.',
            _ => 'Дахин нэвтрээд оролдоно уу.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Холболтоо шалгаад дахин оролдоно уу.');
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
      appBar: AppBar(title: const Text('Нууц үг солих')),
      body: ContentWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const InfoBanner(
                  text: 'Одоогийн нууц үгээрээ баталгаажуулж, шинэ нууц үг тохируулна.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _current,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Одоогийн нууц үг',
                  ),
                  validator: (v) => (v?.isEmpty ?? true)
                      ? 'Одоогийн нууц үгээ оруулна уу.'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Шинэ нууц үг'),
                  validator: (v) => (v?.length ?? 0) < 8
                      ? '8-аас доошгүй тэмдэгт оруулна уу.'
                      : v == _current.text
                      ? 'Өмнөхөөс өөр нууц үг сонгоно уу.'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Шинэ нууц үг давтах',
                  ),
                  validator: (v) => v != _password.text || (v?.isEmpty ?? true)
                      ? 'Шинэ нууц үг таарахгүй байна.'
                      : null,
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Нууц үг шинэчлэх'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
