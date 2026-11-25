import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth/auth_page.dart';
import 'profile/profile_page.dart';
import 'shell/app_shell.dart';
import 'core/app_theme.dart';
import 'core/ui.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const bool.fromEnvironment('USE_FIREBASE_EMULATORS')
            ? const FirebaseOptions(
                apiKey: 'demo-key',
                appId: '1:123456:android:demo',
                messagingSenderId: '123456',
                projectId: 'demo-lost-found',
                storageBucket: 'demo-lost-found.appspot.com',
              )
            : DefaultFirebaseOptions.currentPlatform,
      );
      if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
        const host = String.fromEnvironment(
          'EMULATOR_HOST',
          defaultValue: '10.0.2.2',
        );
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
        FirebaseFunctions.instanceFor(region: 'asia-east1')
            .useFunctionsEmulator(host, 5001);
      } else {
        FirebaseMessaging.onBackgroundMessage(_backgroundMessage);
      }
    }
    runApp(const LostFoundApp());
  } catch (_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: ContentWidth(
              child: StateMessage(
                title: 'Аппыг эхлүүлж чадсангүй',
                message: 'Холболтоо шалгаад дахин оролдоно уу.',
                icon: Icons.cloud_off_outlined,
                action: 'Дахин оролдох',
                onAction: _start,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LostFoundApp extends StatelessWidget {
  const LostFoundApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Олсон, гээсэн',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: StateMessage(
              title: 'Нэвтрэлтийг шалгаж чадсангүй',
              message: 'Аппыг дахин нээж оролдоно уу.',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const AuthPage();
        return _ProfileGate(key: ValueKey(user.uid), user: user);
      },
    ),
  );
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.user});
  final User user;
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final _profile = FirebaseFirestore.instance
      .collection('privateProfiles')
      .doc(widget.user.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: StateMessage(
                  title: 'Профайлыг уншиж чадсангүй',
                  message: 'Холболтоо шалгаж дахин нэвтэрнэ үү.',
                  action: 'Нэвтрэх хэсэгт очих',
                  onAction: () => FirebaseAuth.instance.signOut(),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!.exists
              ? AppShell(user: widget.user)
              : ProfilePage(user: widget.user);
        },
      );
}
