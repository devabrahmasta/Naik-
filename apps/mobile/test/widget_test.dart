import 'package:flutter_test/flutter_test.dart';
import 'package:hikenav_mobile/main.dart';

void main() {
  testWidgets('HikeNav smoke test and title check', (WidgetTester tester) async {
    await tester.pumpWidget(const HikeNavApp());

    expect(find.text('HikeNav'), findsOneWidget);
    expect(find.text('HikeNav Offline GNSS'), findsOneWidget);
  });
}
