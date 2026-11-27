import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/shared/widgets/common/gdc_popup_menu.dart';

void main() {
  testWidgets('Customer GdcPopupMenuButton.icon shows badge and selects option',
      (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GdcPopupMenuButton<String>.icon(
              tooltip: 'Filter options',
              menuTitle: 'Catalog Filters',
              icon: Icons.tune_rounded,
              isActive: true,
              activeBadgeCount: 1,
              onSelected: (val) => selected = val,
              options: const [
                GdcPopupOption<String>(
                  value: 'oos',
                  label: 'Show Sold Out Items',
                  subtitle: 'Include out-of-stock products',
                  icon: Icons.inventory_2_rounded,
                  isSelected: true,
                ),
                GdcPopupOption<String>(
                  value: 'saved',
                  label: 'Saved Items',
                  subtitle: 'Only show your favorites',
                  icon: Icons.favorite_border_rounded,
                  trailingBadge: '4',
                ),
                GdcPopupOption<String>(
                  value: 'reset',
                  label: 'Reset Filters',
                  icon: Icons.restart_alt_rounded,
                  isDestructive: true,
                  showDividerBefore: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byType(GdcPopupIconTrigger));
    await tester.pumpAndSettle();

    expect(find.text('CATALOG FILTERS'), findsOneWidget);
    expect(find.text('Show Sold Out Items'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Reset Filters'), findsOneWidget);

    await tester.tap(find.text('Reset Filters'));
    await tester.pumpAndSettle();

    expect(selected, 'reset');
  });
}
