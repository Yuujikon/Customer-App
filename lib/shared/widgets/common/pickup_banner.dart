import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PickupBanner extends StatelessWidget {
  final VoidCallback onStartOrder;

  const PickupBanner({
    super.key,
    required this.onStartOrder,
  });

  @override
  Widget build(BuildContext context) {
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
                              children: const [
                                Text(
                                  'ORDER BEFORE 4:00 PM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.sage,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pick up today, skip the queue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Your order will be packed and waiting at our counter.',
                                  style: TextStyle(
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
                                  children: const [
                                    Text(
                                      'ORDER BEFORE 4:00 PM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.sage,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Pick up today, skip the queue',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryText,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Your order will be packed and waiting at our counter.',
                                      style: TextStyle(
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
