import 'package:flutter_test/flutter_test.dart';

import 'package:mmgold/main.dart';

void main() {
  testWidgets('App renders welcome gate shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyanmarGoldApp());
    await tester.pump();

    expect(find.byType(MyanmarGoldApp), findsOneWidget);
  });
}
