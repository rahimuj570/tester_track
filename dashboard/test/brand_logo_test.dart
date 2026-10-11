import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track_dashboard/widgets/brand_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Brand Widgets Tests', () {
    testWidgets('BrandLogo renders with specified size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandLogo(size: 40),
          ),
        ),
      );

      final finder = find.byType(BrandLogo);
      expect(finder, findsOneWidget);

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxWidth, equals(40));
      expect(container.constraints?.maxHeight, equals(40));
    });

    testWidgets('BrandWordmark renders logo, title, and tagline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandWordmark(
              logoSize: 36,
              titleSize: 20,
              taglineSize: 12,
              showTagline: true,
            ),
          ),
        ),
      );

      expect(find.byType(BrandWordmark), findsOneWidget);
      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.text('Know who is actually testing.'), findsOneWidget);
    });

    testWidgets('BrandWordmark hides tagline when showTagline is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandWordmark(
              showTagline: false,
            ),
          ),
        ),
      );

      expect(find.byType(BrandWordmark), findsOneWidget);
      expect(find.text('Know who is actually testing.'), findsNothing);
    });
  });
}
