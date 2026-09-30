import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moneybee/main.dart';

void main() {
  testWidgets('MoneyBee app loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MoneyBeeApp()),
    );

    expect(find.text('MoneyBee'), findsOneWidget);
  });
}