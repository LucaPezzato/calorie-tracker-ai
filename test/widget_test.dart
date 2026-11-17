import 'package:calorie_tracker_ai/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Calorie Tracker AI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CalorieTrackerAiApp()),
    );
    expect(find.text('Calorie Tracker'), findsOneWidget);
    // Advance past SplashScreen's 1600ms navigation timer
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Oggi'), findsWidgets);
  });
}
