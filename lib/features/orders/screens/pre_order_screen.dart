import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/store_hours.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/services/time_service.dart';
import '../../../shared/widgets/common/quantity_selector_dialog.dart';
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
  final _refNumCtrl = TextEditingController();
  String _selectedPaymentMethod = 'Cash'; // 'Cash', 'GCash', 'Maya'
  bool _isSubmitting = false;
  PreOrder? _submittedOrder;

  String get _storeGcashNumber =>
      dotenv.env['STORE_GCASH_NUMBER'] ?? '09558297358';

  @override
  void initState() {
    super.initState();
    _pickupSlot = StoreHours.defaultPickupSlot();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _refNumCtrl.dispose();
    super.dispose();
  }

  bool _isPickupSlotExpired(String slot) {
    if (!slot.startsWith('Today')) return false;

    final now = TimeService.now;
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

    final now = TimeService.now;
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
    DateTime initialCalendarDate =
        isPastTodayClosing ? today.add(const Duration(days: 1)) : today;

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

    TimeOfDay? currentSelectedTime = TimeOfDay(hour: defaultHour, minute: 0);
    bool isValidTime = false;

    // 2. Show Native Material Time Picker with automatic loop on invalid selection
    while (!isValidTime) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime:
            currentSelectedTime ?? TimeOfDay(hour: defaultHour, minute: 0),
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
      currentSelectedTime = pickedTime;

      // 3. Enforce Real-Time & Store Hours Constraints
      final selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Rule 3 Constraint: Real-Time Past Time Check
      if (selectedDateTime.isBefore(TimeService.now)) {
        if (!mounted) return;
        final bool? reselect = await _showTimeValidationDialog(
          title: 'Time Already Passed',
          message:
              'Selected time (${pickedTime.format(context)}) has already passed. Please choose a future pickup time.',
        );

        if (reselect == true) {
          continue; // Re-opens time picker without losing date selection!
        } else {
          return;
        }
      }

      // Designated Pickup Hours Check (11:00 AM – 3:00 PM)
      if (pickedTime.hour < StoreHours.openHour ||
          pickedTime.hour >= StoreHours.closeHour) {
        if (!mounted) return;
        final bool? reselect = await _showTimeValidationDialog(
          title: 'Outside Pickup Hours',
          message:
              'Pickup schedules are limited to store operating hours: 11:00 AM to 3:00 PM.',
        );

        if (reselect == true) {
          continue; // Re-opens time picker!
        } else {
          return;
        }
      }

      isValidTime = true;
    }

    final validTime = currentSelectedTime!;

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
        validTime.hourOfPeriod == 0 ? 12 : validTime.hourOfPeriod;
    final period = validTime.period == DayPeriod.am ? 'AM' : 'PM';
    final minuteStr = validTime.minute.toString().padLeft(2, '0');
    final endHourVal = (validTime.hour + 1) % 24;
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
    showDialog(
      context: context,
      builder: (ctx) => QuantitySelectorDialog(
        productName: item.name,
        unitPrice: item.price,
        initialQty: item.qty,
        maxStock: maxStock,
        onConfirm: (newQty) {
          orderProvider.setPreCartQty(
            item.productId,
            newQty,
            maxStock,
            variantId: item.variantId,
          );
        },
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

  void _showQrCodeModal(String providerName, String accountNumber) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        title: Column(
          children: [
            Text('$providerName Payment QR',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(accountNumber,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forest)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan this QR code using your $providerName app or send payment to $accountNumber (GDC Sari-Sari Store).',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 180,
                height: 180,
                child: QrImageView(
                  data: '00020101021226480016A000000677010111$accountNumber',
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Account: $accountNumber\nName: GDC Sari-Sari Store',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.forest),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.forest : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.forest : Theme.of(context).dividerColor,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.forest,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showTimeValidationDialog({
    required String title,
    required String message,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor:
            isDark ? Theme.of(context).cardColor : const Color(0xFFF3F1EA),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Soft Orange Alarm Badge + Title + Close X
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3E2D1D)
                            : const Color(0xFFFDE8C3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.access_time_filled_rounded,
                          color: Color(0xFFD97706),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Body Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Theme.of(context).textTheme.bodySmall?.color
                        : const Color(0xFF384A32),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons Row (Cancel | Reselect Time)
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          side: const BorderSide(
                            color: AppColors.forest,
                            width: 1.8,
                          ),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          backgroundColor: isDark
                              ? Theme.of(context).cardColor
                              : Colors.white,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Reselect Time Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Reselect Time',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

    // Validation: Require Payment Reference Number for GCash / Maya
    if (_selectedPaymentMethod != 'Cash' &&
        _refNumCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Please enter your $_selectedPaymentMethod Transaction Reference Number before placing the pre-order.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Rule 3 Expiration Check: Validate that selected slot hasn't passed current live time
    if (_isPickupSlotExpired(_pickupSlot)) {
      await _showTimeValidationDialog(
        title: 'Time Already Passed',
        message:
            'Selected pickup time ($_pickupSlot) has passed. Please select a valid future pickup slot.',
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
        paymentMethod: _selectedPaymentMethod,
        paymentReference: _refNumCtrl.text.trim().isNotEmpty
            ? _refNumCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submittedOrder = order;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorStr = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('Instance of ', '');
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      Text(
                        'Your basket is waiting',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a few fresh favorites from the catalog.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
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
                        child: const Text('Browse The Catalog'),
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
                    Text(
                      'Pre-order basket',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review your items and choose a convenient pickup time.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).textTheme.bodySmall?.color,
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
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
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
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Direct Remove Item Button
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                              tooltip: '',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                orderProvider.removeFromPreCart(
                                  item.productId,
                                  variantId: item.variantId,
                                );
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Removed "${item.name}" from basket.'),
                                    backgroundColor: AppColors.orangeCTA,
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),

                            const SizedBox(width: 8),

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
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
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
                          Text(
                            'Pickup details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
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
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        size: 18, color: AppColors.orangeCTA),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Perishable Order Notice: Items must be collected within 2 hours of pre-ordering.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
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
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded,
                                        size: 18, color: AppColors.forest),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mixed Order Notice: Pickup schedule limited to 1 day advance due to perishables.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Theme.of(context).dividerColor),
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
                                        Text(
                                          'Pickup time',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                        Text(
                                          _pickupSlot,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
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
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
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

                    // Payment Method Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment method',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.sageTint,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  _selectedPaymentMethod == 'Cash'
                                      ? 'Cash on Pickup'
                                      : 'Cashless / Digital',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Payment Option Chips Row
                          Row(
                            children: [
                              _buildPaymentChip(
                                label: 'Cash on Pickup',
                                icon: Icons.payments_rounded,
                                isSelected: _selectedPaymentMethod == 'Cash',
                                onTap: () => setState(() {
                                  _selectedPaymentMethod = 'Cash';
                                }),
                              ),
                              const SizedBox(width: 8),
                              _buildPaymentChip(
                                label: 'GCash',
                                icon: Icons.account_balance_wallet_rounded,
                                isSelected: _selectedPaymentMethod == 'GCash',
                                onTap: () => setState(() {
                                  _selectedPaymentMethod = 'GCash';
                                }),
                              ),
                              const SizedBox(width: 8),
                              _buildPaymentChip(
                                label: 'Maya / QR Ph',
                                icon: Icons.qr_code_2_rounded,
                                isSelected: _selectedPaymentMethod == 'Maya',
                                onTap: () => setState(() {
                                  _selectedPaymentMethod = 'Maya';
                                }),
                              ),
                            ],
                          ),

                          if (_selectedPaymentMethod != 'Cash') ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Theme.of(context).dividerColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code_scanner_rounded,
                                          color: AppColors.forest, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Pay via ${_selectedPaymentMethod == 'GCash' ? 'GCash' : 'Maya / QR Ph'}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _showQrCodeModal(
                                          _selectedPaymentMethod == 'GCash'
                                              ? 'GCash'
                                              : 'Maya',
                                          _storeGcashNumber,
                                        ),
                                        icon: const Icon(
                                            Icons.qr_code_rounded,
                                            size: 16),
                                        label: const Text('View QR',
                                            style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.forest,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Send payment to $_storeGcashNumber (GDC Sari-Sari Store) then enter your Reference Number below.',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.mutedText,
                                        height: 1.3),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _refNumCtrl,
                                    decoration: InputDecoration(
                                      labelText:
                                          '${_selectedPaymentMethod} Ref # (e.g. 1002 9382 1928)',
                                      hintText: 'Enter 13-digit Ref #',
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AppColors.forest,
                                            width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Price Breakdown & Confirmation
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₱${subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pickup fee',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Free',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Divider(
                              height: 24,
                              color: Theme.of(context).dividerColor),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '₱${subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
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
