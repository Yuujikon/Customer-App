import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/time_service.dart';

class TimeTravelSheet extends StatelessWidget {
  const TimeTravelSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TimeTravelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final timeService = context.watch<TimeService>();
    final simulatedNow = TimeService.now;
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm:ss a');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : const Color(0xFFF3F1EA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row: Clock Icon + Title + Close X
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: timeService.isSimulated
                          ? AppColors.orangeCTALight
                          : AppColors.sageTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      timeService.isSimulated
                          ? Icons.fast_forward_rounded
                          : Icons.access_time_filled_rounded,
                      color: timeService.isSimulated
                          ? AppColors.orangeCTA
                          : AppColors.forest,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Time Simulation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (timeService.isSimulated) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.orangeCTA,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                timeService.offsetFormatted,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Capstone Fast-Forward & Expiration Tester',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current Simulated Clock Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerLow
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: timeService.isSimulated
                    ? AppColors.orangeCTA.withValues(alpha: 0.5)
                    : Theme.of(context).dividerColor,
                width: timeService.isSimulated ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  timeFormat.format(simulatedNow),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: timeService.isSimulated
                        ? AppColors.orangeCTA
                        : AppColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(simulatedNow),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (timeService.isSimulated) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '⚡ Fast-Forward active. App order expirations and store hours reflect this simulated clock.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Fast-Forward Action Buttons Title
          const Text(
            'FAST-FORWARD TIME BY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.sage,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Fast-Forward Options Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFastForwardChip(
                context,
                label: '+30 Minutes',
                icon: Icons.add_alarm_rounded,
                onTap: () => timeService.addMinutes(30),
              ),
              _buildFastForwardChip(
                context,
                label: '+1 Hour',
                icon: Icons.more_time_rounded,
                onTap: () => timeService.addHours(1),
              ),
              _buildFastForwardChip(
                context,
                label: '+2 Hours (Perishable Test)',
                icon: Icons.timer_rounded,
                highlight: true,
                onTap: () => timeService.addHours(2),
              ),
              _buildFastForwardChip(
                context,
                label: '+6 Hours',
                icon: Icons.fast_forward_rounded,
                onTap: () => timeService.addHours(6),
              ),
              _buildFastForwardChip(
                context,
                label: '+1 Day (Next Day Test)',
                icon: Icons.today_rounded,
                onTap: () => timeService.addDays(1),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Reset Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: timeService.isSimulated
                  ? () => timeService.reset()
                  : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset to Live Real-World Clock'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                disabledForegroundColor: AppColors.mutedText,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: timeService.isSimulated
                      ? AppColors.forest
                      : Theme.of(context).dividerColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFastForwardChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.orangeCTALight
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? AppColors.orangeCTA
                : Theme.of(context).dividerColor,
            width: highlight ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: highlight ? AppColors.orangeCTA : AppColors.forest,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: highlight
                    ? AppColors.orangeCTA
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
