import 'package:flutter_test/flutter_test.dart';

import 'package:smart_pharmacy/main.dart';

void main() {
  testWidgets('shows the main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Smart Pharmacy System'), findsOneWidget);
  });
}
