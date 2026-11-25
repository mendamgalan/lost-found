import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../items/create_item_page.dart';
import '../items/items_page.dart';
import '../profile/profile_page.dart';
import '../workflows/claims.dart';
import '../workflows/notifications.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});
  final User user;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0, _revision = 0;
  final _visited = <int>{0}, _refresh = <int>[0, 0, 0, 0, 0];
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  late final _unread = FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientId', isEqualTo: widget.user.uid)
      .where('isRead', isEqualTo: false)
      .snapshots();
  void _select(int value) {
    setState(() {
      _tab = value;
      _visited.add(value);
      _refresh[value]++;
    });
  }

  @override
  void initState() {
    super.initState();
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      _foreground = FirebaseMessaging.onMessage.listen((m) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(m.notification?.title ?? 'Шинэ мэдэгдэл ирлээ.'),
              action: SnackBarAction(
                label: 'Үзэх',
                onPressed: () => _select(3),
              ),
            ),
          );
        }
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((m) {
        if (mounted) {
          openNotification(context, Map<String, dynamic>.from(m.data));
        }
      });
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((m) {
            if (m != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  openNotification(context, Map<String, dynamic>.from(m.data));
                }
              });
            }
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateItemPage()));
    if (ok == true && mounted) {
      setState(() {
        _revision++;
        _tab = 1;
        _visited.add(1);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _tab,
      children: [
        ItemsPage(
          key: ValueKey('discover-$_revision-${_refresh[0]}'),
          onCreate: _create,
        ),
        if (_visited.contains(1))
          ItemsPage(
            key: ValueKey('mine-$_revision-${_refresh[1]}'),
            ownerId: widget.user.uid,
            onCreate: _create,
          )
        else
          const SizedBox.shrink(),
        if (_visited.contains(2))
          ClaimsPage(key: ValueKey('claims-${_refresh[2]}'))
        else
          const SizedBox.shrink(),
        if (_visited.contains(3))
          NotificationsPage(key: ValueKey('notifications-${_refresh[3]}'))
        else
          const SizedBox.shrink(),
        if (_visited.contains(4))
          ProfilePage(user: widget.user)
        else
          const SizedBox.shrink(),
      ],
    ),
    floatingActionButton: _tab == 1
        ? FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('Зар нэмэх'),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _select,
      destinations: [
        const NavigationDestination(icon: Icon(Icons.search), label: 'Хайх'),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Миний зар',
        ),
        const NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          label: 'Хүсэлт',
        ),
        NavigationDestination(
          icon: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _unread,
            builder: (c, s) => Badge(
              isLabelVisible: (s.data?.size ?? 0) > 0,
              label: Text(
                (s.data?.size ?? 0) > 99 ? '99+' : '${s.data?.size ?? 0}',
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          label: 'Мэдэгдэл',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Профайл',
        ),
      ],
    ),
  );
}
