import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:swix_app/main.dart';

void main() {
  testWidgets('Swix app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SwixApp(),
      ),
    );

    expect(find.byType(SwixApp), findsOneWidget);
  });
}