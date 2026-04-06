import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sentinel/app/sentinel_app.dart';

void main() {
  testWidgets('Sentinel shell renders home title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SentinelApp()));

    expect(find.text('Adaptive Task Scheduler'), findsOneWidget);
  });
}
