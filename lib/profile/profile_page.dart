import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../items/create_item_page.dart';

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
        () => _error = 'Мэдээлэл ашиглах нөхцөлтэй танилцаж зөвшөөрнө үү.',
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
      if (mounted)
        setState(
          () => _error = 'Хадгалж чадсангүй. Интернет болон Firestore Rules-ээ шалгаад дахин оролдоно уу.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Гарах үйлдэл амжилтгүй. Дахин оролдоно уу.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Миний бүртгэл'),
      actions: [
        TextButton(
          onPressed: _busy ? null : _logout,
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
                'Профайл унших эрх эсвэл холболтын алдаа. Firestore Rules байршуулсан эсэхээ шалгана уу.',
              ),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data();
        if (data != null) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.teal,
              ),
              const SizedBox(height: 20),
              Text(
                'Сайн байна уу, ${data['name']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(data['email'] as String),
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(data['phone'] as String),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const CreateItemPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Зар нэмэх'),
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Бүртгэлийн эхний алхам бэлэн. Дараагийн алхамд Lost/Found зарын хэсгийг нэмнэ.',
                  ),
                ),
              ),
            ],
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
                  'Одоогийн хувилбарт зөвхөн та өөрийн мэдээллийг харна. '
                  'Claim боломж нэмэгдэхэд Verified болсон хоёр талд email, утсыг харуулна. '
                  'Хичээлийн demo тул бодит эмзэг мэдээлэл бүү оруулаарай.',
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
