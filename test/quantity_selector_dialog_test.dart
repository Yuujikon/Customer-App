import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/shared/widgets/common/quantity_selector_dialog.dart';

void main() {
  testWidgets('allows typing a specific quantity and updates subtotal',
      (tester) async {
    int? confirmedQty;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuantitySelectorDialog(
            productName: '555 sardines',
            variantName: 'Tomato Sauce',
            unitPrice: 25.0,
            initialQty: 1,
            maxStock: 24,
            onConfirm: (qty) => confirmedQty = qty,
          ),
        ),
      ),
    );

    expect(find.text('555 sardines'), findsOneWidget);
    expect(find.text('Tomato Sauce'), findsOneWidget);
    expect(find.text('₱25.00'), findsNWidgets(2)); // unit price + subtotal

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    await tester.enterText(textField, '12');
    await tester.pump();

    expect(find.text('₱300.00'), findsOneWidget);

    await tester.tap(find.text('Update Quantity'));
    await tester.pumpAndSettle();

    expect(confirmedQty, 12);
  });

  testWidgets('clamps typed quantity exceeding maxStock and shows warning',
      (tester) async {
    int? confirmedQty;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuantitySelectorDialog(
            productName: '555 sardines',
            unitPrice: 25.0,
            initialQty: 1,
            maxStock: 24,
            onConfirm: (qty) => confirmedQty = qty,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '99');
    await tester.pump();

    expect(find.text('Maximum available stock is 24.'), findsOneWidget);
    expect(find.text('₱600.00'), findsOneWidget);

    await tester.tap(find.text('Update Quantity'));
    await tester.pumpAndSettle();

    expect(confirmedQty, 24);
  });

  testWidgets('stepper buttons increment and decrement quantity cleanly',
      (tester) async {
    int? confirmedQty;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuantitySelectorDialog(
            productName: '555 sardines',
            unitPrice: 10.0,
            initialQty: 1,
            maxStock: 5,
            onConfirm: (qty) => confirmedQty = qty,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.text('₱30.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();

    expect(find.text('₱20.00'), findsOneWidget);

    await tester.tap(find.text('Update Quantity'));
    await tester.pumpAndSettle();

    expect(confirmedQty, 2);
  });

  testWidgets('handles maxStock 0 without throwing RangeError', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuantitySelectorDialog(
            productName: '555 sardines',
            unitPrice: 15.0,
            initialQty: 1,
            maxStock: 0,
            onConfirm: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('555 sardines'), findsOneWidget);
  });
}
