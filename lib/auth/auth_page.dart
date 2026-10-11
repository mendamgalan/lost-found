import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Олсон • Гээсэн')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.travel_explore, size: 64),
                const SizedBox(height: 20),
                Text(
                  _register ? 'Бүртгэл үүсгэх' : 'Тавтай морил',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _register
                      ? 'Дараагийн алхамд нэр, утас, зөвшөөрлөө бүртгэнэ.'
                      : 'Өөрийн бүртгэлээр нэвтэрнэ үү.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Зөв email оруулна уу.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _hidden,
                  decoration: InputDecoration(
                    labelText: 'Нууц үг',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      tooltip: _hidden ? 'Нууц үг харах' : 'Нууц үг нуух',
                      icon: Icon(
                        _hidden ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Нууц үгээ оруулна уу.';
                    if (_register && v.length < 8)
                      return '8-аас доошгүй тэмдэгт оруулна уу.';
                    return null;
                  },
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
