import 'package:flutter_test/flutter_test.dart';

import 'package:project_manhattan/main.dart';

void main() {
  testWidgets('App boots into login screen', (tester) async {
    await tester.pumpWidget(const ManhattanApp());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
