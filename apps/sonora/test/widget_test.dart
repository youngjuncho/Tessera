import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/main.dart';

void main() {
  testWidgets('Sonora home screen renders', (tester) async {
    await tester.pumpWidget(const SonoraApp());

    expect(find.text('Sonora'), findsOneWidget);
    expect(find.text('White noise'), findsOneWidget);
    expect(find.text('Pink noise'), findsOneWidget);
    expect(find.text('Brown noise'), findsOneWidget);
  });
}
