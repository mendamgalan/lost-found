import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found/core/app_theme.dart';
import 'package:lost_found/workflows/framework.dart';
import 'package:lost_found/workflows/admin.dart';
import 'package:lost_found/workflows/claims.dart';
import 'package:lost_found/workflows/account.dart';

void main() {
  tearDown(() => Api.shared = Api());
  testWidgets('server list paginates and merges next results', (tester) async {
    var calls = 0;
    Api.shared = Api(
      call: (op, p) async {
        calls++;
        return {
          'rows': [
            {
              'id': p['cursor'] == null ? '1' : '2',
              'title': p['cursor'] == null
                  ? 'Эхний хүсэлт'
                  : 'Дараагийн хүсэлт',
            },
          ],
          'cursor': p['cursor'] == null ? '1' : null,
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ServerListPage(
          title: 'Хүсэлт',
          operation: 'myClaims',
          tile: (c, r, refresh) => ListTile(title: Text('${r['title']}')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Эхний хүсэлт'), findsOneWidget);
    await tester.tap(find.text('Цааш үзэх'));
    await tester.pumpAndSettle();
    expect(find.text('Дараагийн хүсэлт'), findsOneWidget);
    expect(calls, 2);
  });
  testWidgets('admin report renders both pending and populated responses', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    Api.shared = Api(call: (op, p) => response.future);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const AdminReportsPage()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    response.complete({
      'rows': <Map<String, dynamic>>[],
      'summary': {'Нийт буцаан олголт': 0},
      'insights': {
        'totals': {'Зар': 42},
      },
      'cursor': null,
    });
    await tester.pumpAndSettle();
    expect(find.text('Зар · 42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('claim requires private evidence before calling Firebase', (
    tester,
  ) async {
    var calls = 0;
    Api.shared = Api(
      call: (op, p) async {
        calls++;
        return {};
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: claimForm(itemId: 'item', title: 'Түлхүүр'),
      ),
    );
    final submit = find.text('Нэхэмжлэл илгээх');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('10-аас доошгүй тэмдэгт оруулна уу.'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('handover validates location and explicit future date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const HandoverForm(claimId: 'c1'),
      ),
    );
    await tester.tap(find.text('Уулзалт товлох'));
    await tester.pumpAndSettle();
    expect(find.text('Газрыг тодорхой оруулна уу.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'ШУТИС номын сан');
    await tester.ensureVisible(find.text('Уулзалт товлох'));
    await tester.tap(find.text('Уулзалт товлох'));
    await tester.pumpAndSettle();
    expect(find.text('Ирээдүйн уулзах цаг сонгоно уу.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('password change checks current and matching confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const PasswordChangePage()),
    );
    await tester.tap(find.text('Нууц үг шинэчлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Одоогийн нууц үгээ оруулна уу.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldPassword123');
    await tester.enterText(fields.at(1), 'newPassword123');
    await tester.enterText(fields.at(2), 'different123');
    await tester.ensureVisible(find.text('Нууц үг шинэчлэх'));
    await tester.tap(find.text('Нууц үг шинэчлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Шинэ нууц үг таарахгүй байна.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
