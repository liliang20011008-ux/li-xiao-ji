import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lixiaoji/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'lixiaoji_contacts_v1': '[]',
      'lixiaoji_records_v1': '[]',
      'lixiaoji_calendar_v1': '[]',
    });
  });

  testWidgets('Home renders bottom tab and search area', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LiXiaoJiApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'tab/home.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home empty states match received and returned artwork', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LiXiaoJiApp());
    await tester.pumpAndSettle();

    expect(find.text('暂无收礼记录'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'relation/3.png',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('我的回礼'));
    await tester.pumpAndSettle();

    expect(find.text('暂无回礼记录'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'relation/2.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Stats tab renders overview cards', (WidgetTester tester) async {
    await tester.pumpWidget(const LiXiaoJiApp());
    await tester.pumpAndSettle();

    final homeTabImage = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'tab/home.png',
    );
    final tabRect = tester.getRect(homeTabImage);

    await tester.tapAt(
      Offset(tabRect.left + tabRect.width * 0.7, tabRect.center.dy),
    );
    await tester.pumpAndSettle();

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('关系分布'), findsOneWidget);
    expect(find.text('趋势图'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'tab/data.png',
      ),
      findsOneWidget,
    );
  });
}
