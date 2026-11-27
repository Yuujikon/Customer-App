import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/store_hours.dart';
import '../../../features/shop/providers/inventory_provider.dart';

class PickupBanner extends StatelessWidget {
  final VoidCallback onStartOrder;

  const PickupBanner({
    super.key,
    required this.onStartOrder,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<InventoryProvider>().settings;
    final bool isOpen = !settings.effectivelyClosed;
    final String? nextOpen = StoreHours.formatNextOpeningLabel(
      settings: settings,
    );

    final String eyebrowText;
    final String headlineText;
    final String subtitleText;

    if (settings.isEmergencyClosed) {
      eyebrowText = 'TEMPORARILY CLOSED';
      headlineText = 'Store under maintenance';
      subtitleText = settings.closureReason;
    } else if (isOpen) {
      eyebrowText =
          'OPEN TODAY · ${settings.formattedDailyHours.toUpperCase()}';
      headlineText = 'Pick up today, skip the queue';
      subtitleText =
          'Your order will be packed and waiting at our counter during open hours.';
    } else {
      eyebrowText = nextOpen != null
          ? 'REOPENS ${nextOpen.toUpperCase()}'
          : 'OPERATING HOURS: ${settings.formattedDailyHours.toUpperCase()}';
      headlineText = 'Reserve your pickup ahead';
      subtitleText =
          'Store is closed right now — you can still pre-order for our next open pickup slots.';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 550;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.warmSurface, AppColors.sageTint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Decorative low-opacity green circle in the upper-right
              Positioned(
                top: -24,
                right: -24,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.forest.withValues(alpha: 0.06),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(19),
                child: isTablet
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.sageTint,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: AppColors.forest,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eyebrowText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.sage,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  headlineText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitleText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: onStartOrder,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Theme.of(context).cardColor,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: const Text('Start An Order'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.sageTint,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: AppColors.forest,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eyebrowText,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.sage,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      headlineText,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryText,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitleText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedText,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: onStartOrder,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Theme.of(context).cardColor,
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                                side: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                    width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              child: const Text('Start An Order'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
