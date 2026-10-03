import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/main.dart';

void main() {
  testWidgets('renders the application bootstrap screen', (tester) async {
    await tester.pumpWidget(const KerjancokApp());

    expect(find.text('Kerjancok'), findsOneWidget);
    expect(find.text('Employee app bootstrap'), findsOneWidget);
  });
}
