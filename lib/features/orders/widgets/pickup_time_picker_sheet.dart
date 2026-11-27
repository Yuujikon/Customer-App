import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/store_hours.dart';
import '../../../shared/models/store_settings.dart';
import '../../../shared/services/time_service.dart';

/// Modern bottom sheet for choosing a pickup date and time slot synchronized
/// with Admin [StoreSettings] (operating hours, closed weekdays, holiday &
/// maintenance overrides) and filtered by the basket's [BasketPickupPolicy].
class PickupTimePickerSheet extends StatefulWidget {
  final StoreSettings settings;
  final BasketPickupPolicy policy;
  final String currentSlot;

  const PickupTimePickerSheet({
    super.key,
    required this.settings,
    required this.policy,
    required this.currentSlot,
  });

  static Future<String?> show(
    BuildContext context, {
    required StoreSettings settings,
    required BasketPickupPolicy policy,
    required String currentSlot,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickupTimePickerSheet(
        settings: settings,
        policy: policy,
        currentSlot: currentSlot,
      ),
    );
  }

  @override
  State<PickupTimePickerSheet> createState() => _PickupTimePickerSheetState();
}

class _PickupTimePickerSheetState extends State<PickupTimePickerSheet> {
  late final DateTime _now;
  late final List<DayScheduleInfo> _calendar;
  late int _selectedDayIndex;
  String? _selectedSlotValue;

  @override
  void initState() {
    super.initState();
    _now = TimeService.now;
    _calendar = StoreHours.getScheduleCalendar(
      settings: widget.settings,
      policy: widget.policy,
      nowTime: _now,
    );

    // Pre-select the day & slot matching currentSlot if still valid
    int matchedDayIdx = -1;
    for (int i = 0; i < _calendar.length; i++) {
      if (_calendar[i].slots.any((s) => s.value == widget.currentSlot)) {
        matchedDayIdx = i;
        break;
      }
    }

    if (matchedDayIdx != -1) {
      _selectedDayIndex = matchedDayIdx;
      _selectedSlotValue = widget.currentSlot;
    } else {
      final firstOpenIdx = _calendar.indexWhere((d) => d.hasAvailableSlots);
      _selectedDayIndex = firstOpenIdx != -1 ? firstOpenIdx : 0;
      _selectedSlotValue =
          firstOpenIdx != -1 ? _calendar[firstOpenIdx].slots.first.value : null;
    }
  }

  void _selectDay(int index) {
    final day = _calendar[index];
    setState(() {
      _selectedDayIndex = index;
      if (day.hasAvailableSlots) {
        final stillInDay = day.slots.any((s) => s.value == _selectedSlotValue);
        if (!stillInDay) {
          _selectedSlotValue = day.slots.first.value;
        }
      } else {
        _selectedSlotValue = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isOpenNow = !widget.settings.isClosedAt(_now);
    final bool isEmergencyClosed = widget.settings.isEmergencyClosed;
    final String? nextOpenLabel = StoreHours.formatNextOpeningLabel(
      settings: widget.settings,
      nowTime: _now,
    );

    final DayScheduleInfo? selectedDay =
        _calendar.isNotEmpty ? _calendar[_selectedDayIndex] : null;
    final bool hasAnyOpenDay = _calendar.any((d) => d.hasAvailableSlots);

    final Color policyAccent =
        widget.policy.tier == BasketProductTier.perishableOnly
            ? AppColors.orangeCTA
            : (widget.policy.tier == BasketProductTier.mixed
                ? Colors.amber.shade800
                : AppColors.forest);
    final Color policyBg =
        widget.policy.tier == BasketProductTier.perishableOnly
            ? (isDark
                ? AppColors.orangeCTA.withValues(alpha: 0.16)
                : AppColors.orangeCTALight)
            : (widget.policy.tier == BasketProductTier.mixed
                ? (isDark
                    ? Colors.amber.withValues(alpha: 0.14)
                    : const Color(0xFFFFF8E1))
                : (isDark
                    ? AppColors.forest.withValues(alpha: 0.18)
                    : AppColors.sageTint));

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Handle & Title Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.forest.withValues(alpha: 0.25)
                                  : AppColors.sageTint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.forest,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose Pickup Schedule',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.settings.regularHoursSummary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    children: [
                      // Live Operating Status Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isEmergencyClosed
                              ? AppColors.error.withValues(alpha: 0.1)
                              : (isOpenNow
                                  ? (isDark
                                      ? AppColors.forest.withValues(alpha: 0.18)
                                      : AppColors.sageTint)
                                  : (isDark
                                      ? AppColors.orangeCTA
                                          .withValues(alpha: 0.15)
                                      : AppColors.orangeCTALight)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isEmergencyClosed
                                ? AppColors.error.withValues(alpha: 0.35)
                                : (isOpenNow
                                    ? AppColors.forest.withValues(alpha: 0.3)
                                    : AppColors.orangeCTA
                                        .withValues(alpha: 0.35)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isEmergencyClosed
                                    ? AppColors.error
                                    : (isOpenNow
                                        ? AppColors.forest
                                        : AppColors.orangeCTA),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isEmergencyClosed
                                    ? widget.settings.closureReasonAt(_now)
                                    : isOpenNow
                                        ? '${widget.settings.todayHoursSummary(nowTime: _now)} · Prep time ~${StoreHours.prepBufferMinutes} mins'
                                        : (nextOpenLabel != null
                                            ? 'Store is currently closed · Advance pickup reservation open (Reopens $nextOpenLabel)'
                                            : 'Store is currently closed'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Product-Based Reservation Policy Card
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: policyBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: policyAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  widget.policy.hasPerishables
                                      ? Icons.eco_rounded
                                      : Icons.inventory_2_outlined,
                                  size: 16,
                                  color: policyAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.policy.badgeTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: policyAccent,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor
                                        .withValues(alpha: isDark ? 0.5 : 0.85),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    widget.policy.shortRuleTag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: policyAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.policy.detailedNotice,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Section 1: Select Date
                      Text(
                        '1. Select Pickup Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_calendar.isEmpty)
                        _buildEmptyBox(
                          context,
                          icon: Icons.event_busy_rounded,
                          title: 'No Pickup Dates Available',
                          subtitle:
                              'One or more items in your basket have an expiry date that prevents advance scheduling.',
                        )
                      else
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _calendar.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final day = _calendar[index];
                              final isSelected = index == _selectedDayIndex;
                              final bool selectable = day.hasAvailableSlots;

                              Color borderColor;
                              Color bgColor;
                              if (isSelected && selectable) {
                                borderColor = AppColors.forest;
                                bgColor = isDark
                                    ? AppColors.forest.withValues(alpha: 0.25)
                                    : AppColors.sageTint;
                              } else if (isSelected) {
                                borderColor = AppColors.orangeCTA;
                                bgColor = theme.colorScheme.surfaceContainerLow;
                              } else {
                                borderColor = theme.dividerColor;
                                bgColor = selectable
                                    ? theme.colorScheme.surfaceContainerLow
                                    : theme.colorScheme.surfaceContainerLow
                                        .withValues(alpha: 0.45);
                              }

                              final String subStatus;
                              final Color subColor;
                              if (day.isClosed) {
                                subStatus = 'Closed';
                                subColor = AppColors.error;
                              } else if (day.slots.isEmpty) {
                                subStatus = 'Ended';
                                subColor = AppColors.mutedText;
                              } else if (day.isSpecialHours) {
                                subStatus = 'Special Hrs';
                                subColor = AppColors.orangeCTA;
                              } else {
                                subStatus =
                                    '${day.slots.length} slot${day.slots.length == 1 ? '' : 's'}';
                                subColor = AppColors.forest;
                              }

                              return InkWell(
                                onTap: () => _selectDay(index),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 98,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: borderColor,
                                      width: isSelected ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        day.shortDayLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: selectable
                                              ? theme.colorScheme.onSurface
                                              : theme.textTheme.bodySmall?.color
                                                  ?.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        day.dateSubtitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              theme.textTheme.bodySmall?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              subColor.withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          subStatus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: subColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Section 2: Select Time Slot
                      if (selectedDay != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '2. Select Time Slot',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (selectedDay.window != null)
                              Text(
                                'Hours: ${selectedDay.window!.formattedRange}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),

                        // Special hours / maintenance note for selected day
                        if (selectedDay.statusNote != null &&
                            selectedDay.hasAvailableSlots) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.shade700
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16, color: Colors.amber.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedDay.statusNote!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        if (!selectedDay.hasAvailableSlots)
                          _buildEmptyBox(
                            context,
                            icon: selectedDay.isClosed
                                ? Icons.store_mall_directory_outlined
                                : Icons.access_time_rounded,
                            title: selectedDay.isClosed
                                ? 'Store Closed on ${selectedDay.shortDayLabel} (${selectedDay.dateSubtitle})'
                                : 'No Remaining Slots on ${selectedDay.shortDayLabel}',
                            subtitle: selectedDay.statusNote ??
                                (selectedDay.isToday
                                    ? 'Remaining operating hours for today do not allow the ${StoreHours.prepBufferMinutes}-minute prep buffer.'
                                    : 'No eligible pickup slots are available for the items in your basket on this date.'),
                            actionLabel:
                                hasAnyOpenDay ? 'Jump to Next Open Day' : null,
                            onAction: hasAnyOpenDay
                                ? () {
                                    final idx = _calendar
                                        .indexWhere((d) => d.hasAvailableSlots);
                                    if (idx != -1) _selectDay(idx);
                                  }
                                : null,
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final int cols =
                                  constraints.maxWidth >= 480 ? 3 : 2;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: selectedDay.slots.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 2.35,
                                ),
                                itemBuilder: (context, idx) {
                                  final slot = selectedDay.slots[idx];
                                  final isSelected =
                                      slot.value == _selectedSlotValue;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedSlotValue = slot.value;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 140),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.forest
                                            : theme.colorScheme
                                                .surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.forest
                                              : theme.dividerColor,
                                          width: isSelected ? 1.6 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (isSelected) ...[
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  slot.rangeLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : theme.colorScheme
                                                            .onSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (slot.isExpressEligible) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'Earliest · Ready ~${DateFormat('h:mm a').format(_now.add(const Duration(minutes: StoreHours.prepBufferMinutes)))}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? Colors.white
                                                        .withValues(alpha: 0.9)
                                                    : AppColors.forest,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),

                // Sticky Bottom Confirmation Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border(
                      top: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedSlotValue != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available_rounded,
                                  size: 16, color: AppColors.forest),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: $_selectedSlotValue',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _selectedSlotValue == null
                            ? null
                            : () => Navigator.pop(context, _selectedSlotValue),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Confirm Pickup Time',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyBox(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.mutedText),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.forest),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
