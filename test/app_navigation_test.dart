import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/app.dart';
import 'package:os_2604/navigation/app_routes.dart';

void main() {
  testWidgets('development launcher opens every placeholder and returns home', (
    tester,
  ) async {
    await tester.pumpWidget(const MorningCheckApp());
    await tester.pumpAndSettle();

    expect(find.text('開発用の画面骨格'), findsOneWidget);
    for (final title in AppRoutes.destinations.values) {
      final destination = find.widgetWithText(ListTile, title);
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      expect(find.text('未実装の画面です。今後、担当機能を接続します。'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('開発用の画面骨格'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
