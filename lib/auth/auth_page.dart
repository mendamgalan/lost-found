import '../items/items_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../core/app_theme.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.code) {
            'email-already-in-use' =>
              'Энэ email бүртгэлтэй байна. Нэвтрэх хэсгийг сонгоно уу.',
            'weak-password' => 'Нууц үг хангалтгүй байна.',
            'invalid-email' => 'Email хаягаа шалгана уу.',
            'invalid-credential' ||
            'wrong-password' ||
            'user-not-found' => 'Email эсвэл нууц үг буруу байна.',
            'network-request-failed' => 'Интернет холболтоо шалгана уу.',
            'too-many-requests' =>
              'Олон удаа оролдлоо. Түр хүлээгээд дахин оролдоно уу.',
            _ => 'Нэвтрэх боломжгүй байна. Firebase тохиргоо болон холболтоо шалгана уу.',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Алдаа гарлаа. Дахин оролдоно уу.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Эхлээд цахим шуудангийн хаягаа оруулна уу.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Хаяг бүртгэлтэй бол сэргээх холбоос илгээгдэнэ. Шуудангаа шалгана уу.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Холбоос илгээж чадсангүй. Холболтоо шалгаад дахин оролдоно уу.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Brand()),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ItemArtwork(category: 'Түлхүүр', height: 170),
                  const SizedBox(height: 20),
                  Text(
                    _register
                        ? 'Хамтдаа олъё.'
                        : 'Эргээд уулзахад таатай байна.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Бүртгэлээ үүсгээд бусдад туслах эхний алхмаа хийгээрэй.'
                        : 'Гээсэн зүйлээ хайж, олсон зүйлээ эзэнд нь хүргээрэй.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Цахим шуудан',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Зөв email оруулна уу.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_busy) _submit();
                    },
                    enabled: !_busy,
                    obscureText: _hidden,
                    decoration: InputDecoration(
                      labelText: 'Нууц үг',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hidden = !_hidden),
                        tooltip: _hidden ? 'Нууц үг харах' : 'Нууц үг нуух',
                        icon: Icon(
                          _hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Нууц үгээ оруулна уу.';
                      }
                      if (_register && v.length < 8) {
                        return '8-аас доошгүй тэмдэгт оруулна уу.';
                      }
                      return null;
                    },
                  ),
                  if (!_register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Нууц үгээ мартсан уу?'),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Түр хүлээнэ үү…'
                          : (_register ? 'Бүртгэл үүсгэх' : 'Нэвтрэх'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                            _form.currentState?.reset();
                          }),
                    child: Text(
                      _register
                          ? 'Бүртгэлтэй юу? Нэвтрэх'
                          : 'Шинэ бүртгэл үүсгэх',
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ItemsPage(),
                            ),
                          ),
                    child: const Text('Зочиноор зар үзэх'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Олсон зүйл. Зөв эзэн. Сайхан төгсгөл.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
