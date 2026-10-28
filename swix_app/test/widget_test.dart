import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bluebase/main.dart';

void main() {
  testWidgets('BlueBase app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BlueBaseApp(),
      ),
    );

    expect(find.byType(BlueBaseApp), findsOneWidget);
  });
}