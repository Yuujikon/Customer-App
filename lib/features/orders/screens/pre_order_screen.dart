import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/store_hours.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop/providers/inventory_provider.dart';
import '../providers/order_provider.dart';
import 'order_ticket_screen.dart';

class PreOrderScreen extends StatefulWidget {
  final VoidCallback onSubmitted;
  final VoidCallback onBrowseMore;
  final VoidCallback? onGoToAccount;

  const PreOrderScreen({
    super.key,
    required this.onSubmitted,
    required this.onBrowseMore,
    this.onGoToAccount,
  });

  @override
  State<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends State<PreOrderScreen> {
  late String _pickupSlot;
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  PreOrder? _submittedOrder;

  @override
  void initState() {
    super.initState();
    _pickupSlot = StoreHours.defaultPickupSlot();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _isPickupSlotExpired(String slot) {
    if (!slot.startsWith('Today')) return false;

    final now = DateTime.now();
    try {
      final parts = slot.split(',');
      if (parts.length < 2) return false;
      final timePart = parts[1].split('–')[0].trim();
      final timeFormat = DateFormat('h:mm a');
      final parsedTime = timeFormat.parse(timePart);

      final slotStartTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      return now.isAfter(slotStartTime) || now.isAtSameMomentAs(slotStartTime);
    } catch (_) {
      return false;
    }
  }

  Future<void> _showPickupTimePicker() async {
    final orderProvider = context.read<OrderProvider>();
    final cart = orderProvider.preCart;
    final bool hasPerishables = cart.any((item) => item.isPerishable);
    final bool hasNonPerishables = cart.any((item) => !item.isPerishable);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today;

    // Rule 1: Calendar Max Allowed Date based on Item Composition:
    // - Perishable ONLY: Present day only (0 days in advance)
    // - Mixed items: Up to 1 day in advance (Today & Tomorrow)
    // - Non-Perishable ONLY: Up to 3 days in advance (Today + 3 days)
    DateTime lastDate;
    String itemTypeNotice;

    if (hasPerishables && !hasNonPerishables) {
      lastDate = today;
      itemTypeNotice = 'PERISHABLE ONLY: PRESENT DAY PICKUP';
    } else if (hasPerishables && hasNonPerishables) {
      lastDate = today.add(const Duration(days: 1));
      itemTypeNotice = 'MIXED ORDER: UP TO 1 DAY ADVANCE';
    } else {
      lastDate = today.add(const Duration(days: 3));
      itemTypeNotice = 'NON-PERISHABLE: UP TO 3 DAYS ADVANCE';
    }

    // If today is past designated pickup closing hour (3:00 PM) and lastDate allows tomorrow
    final bool isPastTodayClosing = now.hour >= StoreHours.closeHour;
    DateTime initialCalendarDate = isPastTodayClosing
        ? today.add(const Duration(days: 1))
        : today;

    if (initialCalendarDate.isAfter(lastDate)) {
      initialCalendarDate = lastDate;
    }

    // 1. Show Native Material Calendar Date Picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialCalendarDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'SELECT PICKUP DATE • $itemTypeNotice',
      confirmText: 'NEXT: PICK TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.forest,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    // Calculate default initial time within designated pickup hours (11:00 AM - 3:00 PM)
    final bool isToday = pickedDate.year == today.year &&
        pickedDate.month == today.month &&
        pickedDate.day == today.day;

    int defaultHour = StoreHours.openHour; // 11:00 AM
    if (isToday) {
      if (now.hour + 1 < StoreHours.openHour) {
        defaultHour = StoreHours.openHour;
      } else if (now.hour + 1 < StoreHours.closeHour) {
        defaultHour = now.hour + 1;
      } else {
        defaultHour = StoreHours.closeHour - 1;
      }
    } else {
      defaultHour = StoreHours.openHour; // 11:00 AM
    }

    // 2. Show Native Material Time Picker
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: defaultHour, minute: 0),
      helpText: 'SELECT PICKUP TIME (11:00 AM – 3:00 PM)',
      confirmText: 'CONFIRM TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.forest,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    // 3. Enforce Real-Time & Store Hours Constraints
    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Rule 3 Constraint: Real-Time Past Time Check
    if (selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⏰ Selected time (${pickedTime.format(context)}) has already passed. Please choose a future pickup time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Designated Pickup Hours Check (11:00 AM – 3:00 PM)
    if (pickedTime.hour < StoreHours.openHour ||
        pickedTime.hour >= StoreHours.closeHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pickup schedules are limited to designated hours: 11:00 AM to 3:00 PM.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Format Date Label (Today, Tomorrow, or EEE, MMM d)
    final tomorrow = today.add(const Duration(days: 1));

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (pickedDate.year == tomorrow.year &&
        pickedDate.month == tomorrow.month &&
        pickedDate.day == tomorrow.day) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEE, MMM d').format(pickedDate);
    }

    final startHourNum =
        pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod;
    final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
    final minuteStr = pickedTime.minute.toString().padLeft(2, '0');
    final endHourVal = (pickedTime.hour + 1) % 24;
    final endHourPeriodVal = endHourVal % 12 == 0 ? 12 : endHourVal % 12;
    final endPeriodStr = endHourVal >= 12 ? 'PM' : 'AM';

    final rangeStr =
        '$startHourNum:$minuteStr $period – $endHourPeriodVal:$minuteStr $endPeriodStr';

    setState(() {
      _pickupSlot = '$dateLabel, $rangeStr';
    });
  }

  void _showEditQuantityDialog({
    required BuildContext context,
    required CartItem item,
    required int maxStock,
    required OrderProvider orderProvider,
  }) {
    final ctrl = TextEditingController(text: '${item.qty}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modify Quantity',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              'Available Stock: $maxStock item${maxStock == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity must be at least 1.')),
                );
                return;
              }

              final clamped = val.clamp(1, maxStock);
              orderProvider.setPreCartQty(
                item.productId,
                clamped,
                maxStock,
                variantId: item.variantId,
              );

              Navigator.pop(ctx);

              if (val > maxStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Quantity capped at maximum available stock ($maxStock).'),
                    backgroundColor: AppColors.orangeCTA,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeCTA,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveItem(
      BuildContext context, CartItem item, OrderProvider orderProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Item?'),
        content: Text('Remove "${item.name}" from your pre-order basket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              orderProvider.removeFromPreCart(item.productId,
                  variantId: item.variantId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showFullNameRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.person_outline_rounded,
                color: AppColors.orangeCTA, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Full Name Required',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your full name is needed for store cashiers to verify your identity when you pick up your pre-order.',
              style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.primaryText,
                  height: 1.4,
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Please enter your full name in your Account profile to proceed with purchasing.',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.mutedText, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onGoToAccount != null) {
                widget.onGoToAccount!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeCTA,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Go to Account Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmPreOrder() async {
    final orderProvider = context.read<OrderProvider>();
    final authProvider = context.read<AppAuthProvider>();
    final inventoryProvider = context.read<InventoryProvider>();

    if (orderProvider.preCart.isEmpty) return;

    if (!authProvider.isFullNameSet) {
      _showFullNameRequiredDialog();
      return;
    }

    // Rule 3 Expiration Check: Validate that selected slot hasn't passed current live time
    if (_isPickupSlotExpired(_pickupSlot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏰ Selected pickup time ($_pickupSlot) has passed. Please select a valid future pickup slot.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      await _showPickupTimePicker();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final order = await orderProvider.submitOrder(
        customerName: authProvider.displayName,
        customerEmail: authProvider.email,
        customerPhone: authProvider.phoneNumber ?? '+63 912 345 6789',
        location: 'GDC Store · Main',
        pickupSlot: _pickupSlot,
        allProducts: inventoryProvider.products,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submittedOrder = order;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorStr =
          e.toString().replaceAll('Exception: ', '').replaceAll('Instance of ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pre-order failed: $errorStr'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final cart = orderProvider.preCart;

    if (_submittedOrder != null) {
      return OrderTicketScreen(
        order: _submittedOrder!,
        onTrackOrder: () {
          setState(() => _submittedOrder = null);
          widget.onSubmitted();
        },
        onBackToShop: () {
          setState(() => _submittedOrder = null);
          widget.onBrowseMore();
        },
      );
    }

    final double subtotal = cart.fold(0.0, (sum, i) => sum + i.price * i.qty);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: cart.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppColors.sageTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_basket_outlined,
                          size: 64,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your basket is waiting',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add a few fresh favorites from the catalog.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: widget.onBrowseMore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orangeCTA,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text('Browse the catalog'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'YOUR SELECTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.sage,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pre-order basket',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Review your items and choose a convenient pickup time.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Items List
                    ...cart.map((item) {
                      Product? product;
                      try {
                        product = inventoryProvider.products
                            .firstWhere((p) => p.id == item.productId);
                      } catch (_) {}

                      int maxStock = product?.maxPurchasableStock ?? 99;
                      if (item.variantId != null && product?.variants != null) {
                        final v = product!.variants![item.variantId];
                        if (v != null) {
                          maxStock = v.maxPurchasableStock;
                        }
                      }
                      if (maxStock <= 0) maxStock = 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.warmSurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.eco_rounded,
                                  color: AppColors.forest,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Product details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Capped & Non-Negative Quantity Controller
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.sageTint,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  // Decrease Button
                                  InkWell(
                                    onTap: () {
                                      if (item.qty <= 1) {
                                        _confirmRemoveItem(
                                            context, item, orderProvider);
                                      } else {
                                        orderProvider.adjustPreCartQty(
                                          item.productId,
                                          -1,
                                          maxStock,
                                          variantId: item.variantId,
                                        );
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.remove,
                                          size: 14, color: AppColors.forest),
                                    ),
                                  ),

                                  // Editable Quantity Display
                                  InkWell(
                                    onTap: () => _showEditQuantityDialog(
                                      context: context,
                                      item: item,
                                      maxStock: maxStock,
                                      orderProvider: orderProvider,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      child: Text(
                                        '${item.qty}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Increase Button capped at maxStock
                                  InkWell(
                                    onTap: () {
                                      if (item.qty >= maxStock) {
                                        ScaffoldMessenger.of(context)
                                            .hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Maximum stock reached ($maxStock available).'),
                                            backgroundColor:
                                                AppColors.orangeCTA,
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      } else {
                                        orderProvider.adjustPreCartQty(
                                          item.productId,
                                          1,
                                          maxStock,
                                          variantId: item.variantId,
                                        );
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.add,
                                          size: 14, color: AppColors.forest),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // Pickup Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pickup details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Item Type Notice Banner (Perishable 2-Hour / Mixed 1-Day Notice)
                          Builder(builder: (context) {
                            final bool hasPerishables =
                                cart.any((item) => item.isPerishable);
                            final bool hasNonPerishables =
                                cart.any((item) => !item.isPerishable);

                            if (hasPerishables && !hasNonPerishables) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.orangeCTALight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.orangeCTA
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        size: 18, color: AppColors.orangeCTA),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Perishable Order Notice: Items must be collected within 2 hours of pre-ordering.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (hasPerishables && hasNonPerishables) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.sageTint,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.forest
                                          .withValues(alpha: 0.2)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 18, color: AppColors.forest),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mixed Order Notice: Pickup schedule limited to 1 day advance due to perishables.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),

                          // Pickup Schedule Row
                          InkWell(
                            onTap: _showPickupTimePicker,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.warmSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.sageTint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.access_time_filled_rounded,
                                      color: AppColors.forest,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Pickup time',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.mutedText,
                                          ),
                                        ),
                                        Text(
                                          _pickupSlot,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.mutedText,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Pickup Notes Field
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Pickup notes',
                              hintText: 'Add special instructions...',
                              filled: true,
                              fillColor: AppColors.warmSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.forest, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Price Breakdown & Confirmation
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₱${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Pickup fee',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Free',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: AppColors.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              Text(
                                '₱${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _handleConfirmPreOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orangeCTA,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Confirm pre-order',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
