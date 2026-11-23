import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/store_hours.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/customer_appeal.dart';
import '../../../shared/services/time_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/xendit_service.dart';
import '../../../shared/widgets/common/quantity_selector_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String _selectedPaymentMethod = 'GCash'; // 'GCash', 'Maya'
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
    _refNumCtrl.dispose();
    super.dispose();
  }

  bool _isPickupSlotExpired(String slot) {
    return StoreHours.isSlotExpired(slot);
  }

  Future<void> _showPickupTimePicker() async {
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isOrderRestricted) {
      _showRestrictionDialog(authProvider);
      return;
    }

    final orderProvider = context.read<OrderProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final cart = orderProvider.preCart;
    final allProducts = inventoryProvider.products;

    final bool hasPerishables = cart.any((item) => item.isPerishable);

    // Calculate earliest batch expiry (FEFO)
    DateTime? earliestExpiry;
    for (final cartItem in cart) {
      final p = allProducts.firstWhere(
        (prod) => prod.id == cartItem.productId,
        orElse: () => Product(
            id: cartItem.productId,
            name: cartItem.name,
            category: 'Others',
            price: cartItem.price,
            stock: cartItem.qty),
      );
      if (p.expiryDate != null) {
        if (earliestExpiry == null || p.expiryDate!.isBefore(earliestExpiry)) {
          earliestExpiry = p.expiryDate;
        }
      }
    }

    final now = TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final earliestAvailableDate =
        StoreHours.getEarliestPickupDate(nowTime: now);
    final firstDate = earliestAvailableDate;

    // Calendar Max Allowed Date:
    // - Perishable: max 1 day advance
    // - Non-Perishable + Prepaid (GCash/Maya): max 3 days advance
    // - Bounded by earliest FEFO expiry date
    DateTime lastDate;
    String itemTypeNotice;

    if (hasPerishables) {
      lastDate = today.add(const Duration(days: 1));
      itemTypeNotice = 'PERISHABLE: UP TO 1 DAY ADVANCE';
    } else {
      lastDate = today.add(const Duration(days: 3));
      itemTypeNotice = 'PREPAID NON-PERISHABLE: UP TO 3 DAYS ADVANCE';
    }

    if (earliestExpiry != null) {
      final expiryDay = DateTime(
          earliestExpiry.year, earliestExpiry.month, earliestExpiry.day);
      if (expiryDay.isBefore(lastDate)) {
        lastDate = expiryDay;
      }
    }

    if (lastDate.isBefore(firstDate)) {
      lastDate = firstDate;
    }

    DateTime initialCalendarDate = earliestAvailableDate;
    if (initialCalendarDate.isAfter(lastDate)) {
      initialCalendarDate = lastDate;
    }

    // 1. Show Native Material Calendar Date Picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialCalendarDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'SELECT PICKUP TIME (DATE) • $itemTypeNotice',
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

    // Calculate default initial time within store hours (11:00 AM - 3:00 PM)
    final bool isToday = pickedDate.year == today.year &&
        pickedDate.month == today.month &&
        pickedDate.day == today.day;

    int defaultHour = StoreHours.openHour; // 11:00 AM
    if (isToday) {
      if (now.hour + 1 < StoreHours.openHour) {
        defaultHour = StoreHours.openHour;
      } else if (now.hour < StoreHours.closeHour) {
        defaultHour = now.hour;
      } else {
        defaultHour = StoreHours.closeHour - 1;
      }
    } else {
      defaultHour = StoreHours.openHour;
    }

    TimeOfDay? currentSelectedTime = TimeOfDay(hour: defaultHour, minute: 0);
    bool isValidTime = false;

    // 2. Show Native Material Time Picker with loop on invalid selection
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

      final selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      final slotEndTime = selectedDateTime.add(const Duration(hours: 1));

      // 3. Enforce Prep Buffer & Store Hours Constraints
      if (isToday &&
          TimeService.now
              .add(const Duration(minutes: StoreHours.prepBufferMinutes))
              .isAfter(slotEndTime)) {
        if (!mounted) return;
        final bool? reselect = await _showTimeValidationDialog(
          title: 'Time Already Passed',
          message:
              'Selected time (${pickedTime.format(context)}) does not allow sufficient preparation time (${StoreHours.prepBufferMinutes} mins). Please choose a future pickup time.',
        );

        if (reselect == true) {
          continue;
        } else {
          return;
        }
      }

      // Store Operating Hours Check (11:00 AM – 3:00 PM)
      if (pickedTime.hour < StoreHours.openHour ||
          pickedTime.hour >= StoreHours.closeHour) {
        if (!mounted) return;
        final bool? reselect = await _showTimeValidationDialog(
          title: 'Outside Pickup Hours',
          message:
              'Pickup schedules are limited to store operating hours: 11:00 AM to 3:00 PM.',
        );

        if (reselect == true) {
          continue;
        } else {
          return;
        }
      }

      isValidTime = true;
    }

    final validTime = currentSelectedTime!;
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
        title: const Row(
          children: [
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
              color: isSelected
                  ? AppColors.forest
                  : Theme.of(context).dividerColor,
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
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
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

    if (inventoryProvider.settings.effectivelyClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventoryProvider.settings.closureReason),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (authProvider.isOrderRestricted) {
      _showRestrictionDialog(authProvider);
      return;
    }

    if (!authProvider.isFullNameSet) {
      _showFullNameRequiredDialog();
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

    PreOrder? reservedOrder;

    try {
      final pickupNotesText = _notesCtrl.text.trim();

      // Step 1: Reserve stock atomically BEFORE opening Xendit payment
      final reservation = await orderProvider.reserveOrderForPayment(
        customerName: authProvider.displayName,
        customerEmail: authProvider.email,
        customerPhone: authProvider.phoneNumber ?? '+63 912 345 6789',
        location: 'GDC Store · Main',
        pickupSlot: _pickupSlot,
        allProducts: inventoryProvider.products,
        paymentMethod: _selectedPaymentMethod,
        notes: pickupNotesText.isNotEmpty ? pickupNotesText : null,
      );
      reservedOrder = reservation.order;

      // Step 2: Create Xendit invoice for the reserved order
      final checkout = await XenditService.createInvoice(
        amount: reservedOrder.total,
        description: 'GDC Store Order #${reservedOrder.orderId}',
        customerName: authProvider.displayName,
        customerEmail: authProvider.email,
        customerPhone: authProvider.phoneNumber ?? '+63 912 345 6789',
        paymentMethods: [
          _selectedPaymentMethod == 'GCash' ? 'GCASH' : 'PAYMAYA'
        ],
      );

      final checkoutUrl = checkout['url']!;
      final sessionId = checkout['id']!;

      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!mounted) {
        await orderProvider.releaseUnpaidReservation(reservedOrder);
        return;
      }

      final paymentReference = await _showPaymentAwaitingDialog(sessionId);

      if (paymentReference == null) {
        // Customer cancelled payment: release reserved stock immediately
        await orderProvider.releaseUnpaidReservation(reservedOrder);
        reservedOrder = null;
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // Step 3: Confirm payment and activate the reserved order
      final order = await orderProvider.confirmReservedOrderPayment(
        reservedOrder: reservedOrder,
        paymentReference: paymentReference,
        pickupExpiresAt: reservation.pickupExpiresAt,
      );
      reservedOrder = null;

      _notesCtrl.clear();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submittedOrder = order;
      });
    } catch (e) {
      // Release reservation if anything failed after reserving stock
      if (reservedOrder != null) {
        try {
          await orderProvider.releaseUnpaidReservation(reservedOrder);
        } catch (_) {}
      }
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

  Future<String?> _showPaymentAwaitingDialog(String sessionId) async {
    bool isChecking = false;
    String? errorMsg;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (context, setSt) {
        return AlertDialog(
          title: const Text('Complete Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isChecking)
                const CircularProgressIndicator()
              else
                const Icon(Icons.payment_rounded,
                    size: 48, color: AppColors.forest),
              const SizedBox(height: 16),
              const Text(
                'Please complete the payment in the browser that just opened. Once done, press the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isChecking ? null : () => Navigator.pop(ctx, null),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isChecking
                  ? null
                  : () async {
                      setSt(() {
                        isChecking = true;
                        errorMsg = null;
                      });
                      try {
                        final ref =
                            await XenditService.checkPaymentStatus(sessionId);
                        if (ref != null) {
                          if (ctx.mounted) Navigator.pop(ctx, ref);
                        } else {
                          setSt(() {
                            isChecking = false;
                            errorMsg =
                                'Payment not yet received. Please complete it or wait a moment.';
                          });
                        }
                      } catch (e) {
                        setSt(() {
                          isChecking = false;
                          errorMsg = 'Error verifying payment. Try again.';
                        });
                      }
                    },
              child: const Text('I HAVE PAID'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final authProvider = context.watch<AppAuthProvider>();
    final cart = orderProvider.preCart;

    if (_submittedOrder != null) {
      if (cart.isNotEmpty) {
        // New items added to basket after an old confirmation:
        // Remove the old confirmation view and show the active basket transaction process
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _submittedOrder = null);
        });
      } else {
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
    }

    // Automatically advance pickup slot if current selection has passed
    if (_isPickupSlotExpired(_pickupSlot)) {
      _pickupSlot = StoreHours.defaultPickupSlot();
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

                    if (authProvider.isOrderRestricted) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: authProvider.isPermanentlyLocked
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: authProvider.isPermanentlyLocked
                                ? Colors.red.withValues(alpha: 0.5)
                                : Colors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  authProvider.isPermanentlyLocked
                                      ? Icons.gavel_rounded
                                      : Icons.warning_amber_rounded,
                                  color: authProvider.isPermanentlyLocked
                                      ? Colors.red[800]
                                      : Colors.orange[800],
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authProvider.isPermanentlyLocked
                                        ? 'Account Permanently Locked'
                                        : 'Pre-Order Placement Restricted',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: authProvider.isPermanentlyLocked
                                          ? Colors.red[900]
                                          : Colors.orange[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              authProvider.isPermanentlyLocked
                                  ? 'Your account is permanently locked due to 4 ghosted/uncollected orders. You cannot submit pre-orders.'
                                  : 'You are restricted from placing pre-orders due to uncollected/ghosted orders (${authProvider.restrictionStatusText}).',
                              style: TextStyle(
                                fontSize: 12,
                                color: authProvider.isPermanentlyLocked
                                    ? Colors.red[900]
                                    : Colors.orange[900],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showRestrictionDialog(authProvider),
                                icon: const Icon(Icons.gavel_rounded, size: 16),
                                label: const Text(
                                    'View Penalty Details & Submit Appeal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      authProvider.isPermanentlyLocked
                                          ? Colors.red[800]
                                          : Colors.orange[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Items List
                    ...cart.map((item) {
                      Product? product;
                      try {
                        product = inventoryProvider.products
                            .firstWhere((p) => p.id == item.productId);
                      } catch (_) {}

                      int maxStock = product?.maxPurchasableStock ?? 0;
                      if (item.variantId != null && product?.variants != null) {
                        final v = product!.variants![item.variantId];
                        if (v != null) {
                          maxStock = v.maxPurchasableStock;
                        }
                      }
                      final bool isOutOfStock = maxStock <= 0;

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
                                    isOutOfStock
                                        ? 'Out of stock'
                                        : '₱${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isOutOfStock
                                          ? AppColors.error
                                          : Theme.of(context)
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
                                      if (isOutOfStock || item.qty <= 1) {
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
                                    onTap: isOutOfStock
                                        ? null
                                        : () => _showEditQuantityDialog(
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isOutOfStock
                                              ? AppColors.mutedText
                                              : AppColors.forest,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Increase Button capped at maxStock
                                  InkWell(
                                    onTap: isOutOfStock
                                        ? null
                                        : () {
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
                                                  duration: const Duration(
                                                      seconds: 2),
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
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.add,
                                        size: 14,
                                        color: isOutOfStock
                                            ? AppColors.mutedText
                                            : AppColors.forest,
                                      ),
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

                          // Dynamic Hold Grace Period Banner
                          Builder(builder: (context) {
                            final bool hasPerishables =
                                cart.any((item) => item.isPerishable);

                            String noticeText;
                            IconData noticeIcon;
                            Color bgColor;
                            Color borderThemeColor;

                            if (hasPerishables) {
                              noticeText =
                                  'Perishable Notice: Stock reserved and held until the end of your chosen pickup slot before auto-cancellation.';
                              noticeIcon = Icons.timer_outlined;
                              bgColor = AppColors.orangeCTALight;
                              borderThemeColor = AppColors.orangeCTA;
                            } else {
                              noticeText =
                                  'Prepaid Order Notice: Stock reserved and held until the end of your chosen pickup slot.';
                              noticeIcon = Icons.verified_user_outlined;
                              bgColor = AppColors.sageTint;
                              borderThemeColor = AppColors.forest;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: borderThemeColor.withValues(
                                        alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(noticeIcon,
                                      size: 18, color: borderThemeColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      noticeText,
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
                          }),

                          // Interactive Pickup Time Slot Button Box
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
                                  color: Theme.of(context).dividerColor,
                                ),
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
                                        const SizedBox(height: 2),
                                        Text(
                                          _pickupSlot,
                                          style: TextStyle(
                                            fontSize: 14,
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
                                child: const Text(
                                  'Cashless / Digital',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Payment Option Chips Row (GCash and Maya only)
                          Row(
                            children: [
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
                                  const Row(
                                    children: [
                                      Icon(Icons.security_rounded,
                                          color: AppColors.forest, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Secure Payment via Xendit',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You will be redirected to a secure Xendit page to complete your $_selectedPaymentMethod payment. Please do not close the app.',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.mutedText,
                                        height: 1.3),
                                  ),
                                ],
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

  void _showRestrictionDialog(AppAuthProvider authProvider) {
    final isLocked = authProvider.isPermanentlyLocked;
    final remaining = authProvider.remainingRestrictionDuration;

    final String title = isLocked
        ? 'Account Permanently Locked'
        : 'Order Restriction Active (${authProvider.offenseCount}/4 Offenses)';

    final String message;
    if (isLocked) {
      message =
          'Your account has reached 4 offenses due to ghosting/uncollected pre-orders. Your pre-ordering privileges are permanently locked. You may submit an appeal to store management to request a review.';
    } else {
      final remainingStr =
          remaining != null ? _formatDuration(remaining) : 'active duration';
      message =
          'You are currently restricted from placing pre-orders for $remainingStr due to uncollected orders (${authProvider.restrictionStatusText}).\n\nIf you believe this was an error, you can submit an appeal.';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isLocked ? Icons.gavel_rounded : Icons.warning_amber_rounded,
              color: isLocked ? Colors.red : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text('Offense Policy Tiers:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildTierItem(
                  '1st Offense', '2-Hour Restriction', Colors.orange),
              _buildTierItem(
                  '2nd Offense', '24-Hour Restriction', Colors.deepOrange),
              _buildTierItem('3rd Offense', '72-Hour Restriction', Colors.red),
              _buildTierItem('4th Offense', 'Permanent Lock', Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                'Note: If your appeal is approved by the store admin, your offense tier will be decremented by 1.',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showAppealDialog(authProvider);
            },
            icon: const Icon(Icons.gavel_rounded, size: 16),
            label: const Text('Submit Appeal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final mins = d.inMinutes % 60;
      return '$hours hr${hours > 1 ? "s" : ""} $mins min${mins > 1 ? "s" : ""}';
    } else {
      final mins = d.inMinutes;
      return '$mins min${mins > 1 ? "s" : ""}';
    }
  }

  Widget _buildTierItem(String tier, String penalty, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$tier: $penalty',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppealDialog(AppAuthProvider auth) {
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: AppColors.orangeCTA),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Submit Restriction Appeal',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explain why you missed or ghosted your pre-order pick up. Your appeal will be reviewed by store management.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Enter your explanation for missing the order (e.g. medical emergency, technical issue)...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.forest, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please enter an explanation for your appeal.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => submitting = true);

                        try {
                          final appeal = CustomerAppeal(
                            id: '',
                            userId: auth.currentUser?.uid ?? '',
                            customerEmail: auth.email,
                            customerName: auth.displayName,
                            offenseCount: auth.offenseCount,
                            reason: reason,
                            status: AppealStatus.pending,
                            createdAt: TimeService.now,
                          );

                          await FirestoreService().submitAppeal(appeal);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '🎉 Your appeal has been submitted to store admins for review.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => submitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to submit appeal: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Appeal',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
