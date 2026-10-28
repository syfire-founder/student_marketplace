import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bluubase/main.dart';

void main() {
  testWidgets('BluuBase app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BluuBaseApp(),
      ),
    );

    expect(find.byType(BluuBaseApp), findsOneWidget);
  });
}