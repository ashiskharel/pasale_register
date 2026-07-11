import 'package:flutter_test/flutter_test.dart';
import 'package:mlkit_camera_example/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    // Avoid initializing real camera plugins in unit widget tests.
    await tester.pumpWidget(const MlkitCameraExampleApp());
    // First frame only — initialize() is async and may error without camera.
    await tester.pump();
    expect(find.text('ML Kit Camera'), findsOneWidget);
  });
}
