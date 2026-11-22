
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoride/main.dart';

void main() {
  testWidgets('EcoRide shows Firebase setup instructions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const SetupRequiredApp(
            details: 'Firebase is not configured',
          ),
        );

        expect(find.text('Firebase setup required'), findsOneWidget);
        expect(find.textContaining('Create a Firebase project'), findsOneWidget);
      });
}
