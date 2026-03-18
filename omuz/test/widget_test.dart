import 'package:flutter_test/flutter_test.dart';

import 'package:omuz/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OMuzApp());
    await tester.pumpAndSettle();
    expect(find.text('OMuz'), findsWidgets);
  });
}
