import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flood2food/main.dart';

void main() {
  testWidgets('App transitions from splash to dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const Flood2FoodApp());

    // Splash screen is shown initially
    expect(find.byType(Image), findsOneWidget);

    // Advance past the 2-second splash delay
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();

    // After splash, we should see the MainShell with NavigationBar
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('flood2food'), findsWidgets);
    expect(find.text('Sensor Tidak Terhubung'), findsOneWidget);
  });

  testWidgets('Connecting sensor shows monitoring section', (WidgetTester tester) async {
    await tester.pumpWidget(const Flood2FoodApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sensor Tidak Terhubung'), findsOneWidget);

    await tester.tap(find.text('Mode Simulasi'));
    await tester.pump();

    expect(find.text('Sensor Monitoring'), findsOneWidget);
  });
}
