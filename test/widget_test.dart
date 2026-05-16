import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unitrendclaude/main.dart';

void main() {
  testWidgets('UniTrendApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: UniTrendApp()),
    );
    // App mounts — dotenv is not loaded in test, but the widget tree builds.
    expect(find.byType(UniTrendApp), findsOneWidget);

    // Drain the 2-second splash timer so no pending timers remain.
    await tester.pump(const Duration(seconds: 3));
  });
}
