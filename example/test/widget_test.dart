import 'package:face_liveness_check_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders Face Liveness & Match example home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FaceLivenessExampleApp());
    expect(find.text('Face Liveness & Match'), findsOneWidget);
    expect(find.text('1. Liveness Configuration Page'), findsOneWidget);
    expect(find.text('2. Take Liveness Check'), findsOneWidget);
  });
}
