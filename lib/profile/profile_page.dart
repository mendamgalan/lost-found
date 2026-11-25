import '../workflows/account.dart';
import '../workflows/admin.dart';
import '../workflows/framework.dart';
import '../services/push_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../core/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});
  final User user;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final DocumentReference<Map<String, dynamic>> _ref;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile;
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseFirestore.instance
        .collection('privateProfiles')
        .doc(widget.user.uid);
    _profile = _ref.snapshots();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_consent) {
      setState(
        () => _error = 'Мэдээлэл ашиглах зориулалтыг уншиж зөвшөөрнө үү.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _ref.set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': widget.user.email!,
        'consentVersion': 'mvp-v1',
        'consentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Мэдээллээ хадгалж чадсангүй. Холболтоо шалгаад дахин оролдоно уу.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бүртгэлээс гарах уу?'),
        content: const Text(
          'Та дараа нь цахим шуудан, нууц үгээрээ дахин нэвтрэх боломжтой.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Гарах'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _logout();
  }

  Future<void> _logout() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await PushService.shared.logout();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Гарах үйлдэл амжилтгүй. Дахин оролдоно уу.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _push() async {
    try {
      final enabled = await PushService.shared.enable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Мэдэгдэл идэвхжлээ.'
                  : 'Төхөөрөмжийн мэдэгдлийн тохиргоог шалгана уу.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Миний бүртгэл'),
      actions: [
        TextButton(
          onPressed: _busy ? null : _confirmLogout,
          child: const Text('Гарах'),
        ),
      ],
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Профайлыг уншиж чадсангүй. Интернет холболтоо шалгаж дахин нэвтэрнэ үү.',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data();
        if (data != null) {
          final name = data['name'] as String? ?? 'Хэрэглэгч';
          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.mint,
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : String.fromCharCode(name.runes.first),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Бусдад туслах жижиг алхам бүр үнэ цэнтэй.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFDFEEE8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Хувийн мэдээлэл',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Цахим шуудан'),
                        subtitle: Text(data['email'] as String? ?? ''),
                      ),
                      const Divider(indent: 16, endIndent: 16, height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Утас'),
                        subtitle: Text(data['phone'] as String? ?? ''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const InfoBanner(
                  text: 'Холбоо барих мэдээлэл баталгаажсан хоёр талд нээгдэнэ. Нууц онцлогоо нийтийн тайлбарт бүү бичээрэй.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Хэрхэн ажилладаг вэ?'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (context) => const SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Олсон зүйлээ эзэнд нь хүргэе',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              '1. Гээсэн эсвэл олсон зарыг хайж үзээрэй.\n\n2. Зар нийтлэхдээ байршил, огноо, ялгах шинжийг тодорхой бичээрэй.\n\n3. Нууц онцлогийг зөвхөн тусгай талбарт хадгална.\n\n4. Эд зүйлийг буцаасны дараа өөрийн зарын дэлгэрэнгүйгээс “Буцаан олгосон” гэж тэмдэглээрэй.\n\nЭзэмшигчийн нэхэмжлэл, баталгаажуулалт болон апп доторх харилцаа хараахан нэмэгдээгүй.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => openPage(
                    context,
                    profileForm(name, data['phone'] as String? ?? ''),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Профайл засах'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      openPage(context, const PasswordChangePage()),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Нууц үг солих'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _push,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Мэдэгдэл идэвхжүүлэх'),
                ),
                FutureBuilder<IdTokenResult>(
                  future: widget.user.getIdTokenResult(),
                  builder: (c, s) => s.data?.claims?['admin'] == true
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: FilledButton.icon(
                            onPressed: () =>
                                openPage(context, const AdminPage()),
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            label: const Text('Удирдлага'),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Бүртгэлээс гарах'),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Бүртгэлээ гүйцээх',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Нэр'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Нэрээ оруулна уу.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Утас — 8 оронтой',
                  ),
                  validator: (v) =>
                      RegExp(r'^[0-9]{8}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '8 оронтой утас оруулна уу.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Нэр, email, утсыг бүртгэл болон эд зүйл хүлээлцэхэд ашиглана. '
                  'Одоогоор зөвхөн та өөрийн мэдээллийг харна. '
                  'Холбоо барих мэдээллийг зарын нийтийн тайлбарт харуулахгүй.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _consent = v ?? false),
                  title: const Text(
                    'Дээрх зориулалтаар мэдээллээ ашиглуулахыг зөвшөөрч байна.',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Хадгалж байна…' : 'Бүртгэлээ дуусгах'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
