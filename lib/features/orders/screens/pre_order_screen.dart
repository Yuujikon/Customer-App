import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/store_hours.dart';
import '../../../core/utils/pricing_engine.dart';
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
import '../widgets/pickup_time_picker_sheet.dart';
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
  String _pickupSlot = '';
  final _notesCtrl = TextEditingController();
  String _selectedPaymentMethod = 'GCash'; // 'GCash', 'Maya'
  bool _isSubmitting = false;
  PreOrder? _submittedOrder;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showPickupTimePicker() async {
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isOrderRestricted) {
      _showRestrictionDialog(authProvider);
      return;
    }

    final orderProvider = context.read<OrderProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final settings = inventoryProvider.settings;

    if (settings.isEmergencyClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.closureReason.isNotEmpty
                ? settings.closureReason
                : 'Store is currently under emergency maintenance.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final policy = BasketPickupPolicy.fromCart(
      cart: orderProvider.preCart,
      allProducts: inventoryProvider.products,
      settings: settings,
    );

    final pickedSlot = await PickupTimePickerSheet.show(
      context,
      settings: settings,
      policy: policy,
      currentSlot: _pickupSlot,
    );

    if (pickedSlot != null && mounted) {
      setState(() {
        _pickupSlot = pickedSlot;
      });
    }
  }

  void _showEditQuantityDialog({
    required BuildContext context,
    required CartItem item,
    required double unitPrice,
    required int maxStock,
    required OrderProvider orderProvider,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => QuantitySelectorDialog(
        productName: item.name,
        variantName: item.variantName,
        unitPrice: unitPrice,
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
              orderProvider.removeFromPreCart(
                item.productId,
                variantId: item.variantId,
                exactVariantMatch: true,
              );
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

    final settings = inventoryProvider.settings;

    // Only block ordering completely during Admin Emergency Maintenance.
    // Outside normal operating hours, customers can still reserve pickup for
    // upcoming open hours based on the products in their basket.
    if (settings.isEmergencyClosed) {
      final reason = settings.closureReason;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reason.isNotEmpty
                ? reason
                : 'Store is currently under maintenance and not accepting pre-orders.',
          ),
          backgroundColor: AppColors.error,
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

    // Pre-validate live inventory BEFORE launching Xendit checkout so customers
    // are never charged for out-of-stock or quarantined items.
    // Reconcile cart against live online-allocated stock (from real-time category splits)
    // BEFORE launching Xendit checkout so customers are never charged above live limits.
    final adjustments = orderProvider.reconcileCartWithLiveStock(
      inventoryProvider.products,
    );
    if (adjustments.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderProvider.stockLimitBannerMessage ??
                'Online stock limits changed. Your basket quantities were adjusted — please review and try again.',
          ),
          backgroundColor: AppColors.orangeCTA,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    for (final item in orderProvider.preCart) {
      final matching =
          inventoryProvider.products.where((p) => p.id == item.productId);
      if (matching.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '"${item.name}" is no longer available. Please remove it from your basket.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final product = matching.first;
      if (product.isQuarantined || product.status != ProductStatus.published) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '"${item.name}" is currently unavailable. Please remove it from your basket.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (product.hasVariants) {
        if (item.variantId == null ||
            product.variants?[item.variantId] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Please select a valid option for "${item.name}" before checking out.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        final variant = product.variants![item.variantId]!;
        final avail = variant.maxPurchasableStock;
        if (avail <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '"${item.name} (${variant.name})" is currently out of stock. Please remove it from your basket.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (item.qty > avail) {
          orderProvider.setPreCartQty(
            item.productId,
            avail,
            avail,
            variantId: item.variantId,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Only $avail left in stock for "${item.name} (${variant.name})". Quantity adjusted to $avail.'),
              backgroundColor: AppColors.orangeCTA,
            ),
          );
          return;
        }
      } else {
        final avail = product.maxPurchasableStock;
        if (avail <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '"${item.name}" is currently out of stock. Please remove it from your basket.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (item.qty > avail) {
          orderProvider.setPreCartQty(
            item.productId,
            avail,
            avail,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Only $avail left in stock for "${item.name}". Quantity adjusted to $avail.'),
              backgroundColor: AppColors.orangeCTA,
            ),
          );
          return;
        }
      }
    }

    // Validate selected pickup slot against live Admin operating hours,
    // holiday/maintenance overrides, and the basket's product policy.
    final policy = BasketPickupPolicy.fromCart(
      cart: orderProvider.preCart,
      allProducts: inventoryProvider.products,
      settings: settings,
    );
    final defaultValidSlot = StoreHours.getDefaultSlotOption(
      settings: settings,
      policy: policy,
    );
    if (defaultValidSlot == null) {
      await _showTimeValidationDialog(
        title: 'No Pickup Slots Available',
        message:
            'There are no open store pickup slots within the freshness/reservation window of the items in your basket. Please adjust your basket or check store hours.',
      );
      return;
    }

    if (!StoreHours.isSlotValidForSettings(
      _pickupSlot,
      settings: settings,
      policy: policy,
    )) {
      final bool? reselect = await _showTimeValidationDialog(
        title: 'Pickup Schedule Updated',
        message:
            'Your selected pickup slot ($_pickupSlot) is no longer available under current store operating hours or product rules. Please choose an available pickup time.',
      );
      if (reselect == true && mounted) {
        await _showPickupTimePicker();
      }
      return;
    }

    setState(() => _isSubmitting = true);

    String? paymentReference;

    try {
      final breakdown = PricingEngine.calculate(
        items: orderProvider.preCart,
        allProducts: inventoryProvider.products,
      );

      final checkout = await XenditService.createInvoice(
        amount: breakdown.total,
        description: 'GDC Store Order',
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

      if (!mounted) return;
      final isPaid = await _showPaymentAwaitingDialog(sessionId);

      if (!mounted) return;
      if (isPaid == null) {
        setState(() => _isSubmitting = false);
        return;
      }
      paymentReference = isPaid;

      final pickupNotesText = _notesCtrl.text.trim();
      final order = await orderProvider.submitOrder(
        customerName: authProvider.displayName,
        customerEmail: authProvider.email,
        customerPhone: authProvider.phoneNumber ?? '+63 912 345 6789',
        location: 'GDC Store · Main',
        pickupSlot: _pickupSlot,
        allProducts: inventoryProvider.products,
        paymentMethod: _selectedPaymentMethod,
        paymentReference: paymentReference,
        notes: pickupNotesText.isNotEmpty ? pickupNotesText : null,
      );

      _notesCtrl.clear();

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

  Future<String?> _showPaymentAwaitingDialog(String sessionId) async {
    bool isChecking = false;
    String? errorMsg;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (dialogContext, setSt) {
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
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.orangeCTA),
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
                        if (!ctx.mounted) return;
                        if (ref != null) {
                          Navigator.pop(ctx, ref);
                        } else {
                          setSt(() {
                            isChecking = false;
                            errorMsg =
                                'Payment not yet received. Please complete it or wait a moment.';
                          });
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
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
    context.watch<TimeService>();
    final settings = inventoryProvider.settings;
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

    final policy = BasketPickupPolicy.fromCart(
      cart: cart,
      allProducts: inventoryProvider.products,
      settings: settings,
    );
    final defaultSlotOption = StoreHours.getDefaultSlotOption(
      settings: settings,
      policy: policy,
    );
    final bool hasAvailablePickupSlots =
        !settings.isEmergencyClosed && defaultSlotOption != null;

    // Automatically keep pickup slot synchronized with Admin operating hours,
    // schedule overrides, and the basket's current product reservation rules.
    if (cart.isNotEmpty &&
        !StoreHours.isSlotValidForSettings(
          _pickupSlot,
          settings: settings,
          policy: policy,
        )) {
      _pickupSlot = defaultSlotOption?.value ??
          StoreHours.defaultPickupSlot(settings: settings, policy: policy);
    }

    final pricing = PricingEngine.calculate(
      items: cart,
      allProducts: inventoryProvider.products,
    );
    final double subtotal = pricing.subtotal;
    final double total = pricing.total;

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

                    // Live Stock-Limit Adjustment Banner (when category allocation split reduces online stock)
                    if (orderProvider.stockLimitBannerMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                Colors.amber.shade700.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Stock Limit Updated',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    orderProvider.stockLimitBannerMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.amber.shade900,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Dismiss',
                              onPressed: () =>
                                  orderProvider.clearStockLimitNotice(),
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
                      double unitPrice = item.price;
                      final bool hasItemVariant =
                          item.variantId != null && item.variantId!.isNotEmpty;
                      if (product != null) {
                        if (hasItemVariant && product.variants != null) {
                          final v = product.variants![item.variantId];
                          if (v != null) {
                            maxStock = v.maxPurchasableStock;
                            unitPrice = v.price;
                          } else {
                            maxStock = 0;
                          }
                        } else {
                          unitPrice = product.price;
                        }
                      }
                      final bool isItemUnavailable = product == null ||
                          product.isQuarantined ||
                          maxStock <= 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isItemUnavailable
                                ? AppColors.error.withValues(alpha: 0.5)
                                : Theme.of(context).dividerColor,
                          ),
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
                                  if (item.variantName != null &&
                                      item.variantName!.isNotEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      item.variantName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.forest,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    isItemUnavailable
                                        ? 'Out of stock'
                                        : '₱${unitPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isItemUnavailable
                                          ? AppColors.error
                                          : Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                      fontWeight: isItemUnavailable
                                          ? FontWeight.w800
                                          : FontWeight.w600,
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
                              tooltip: 'Remove item',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                orderProvider.removeFromPreCart(
                                  item.productId,
                                  variantId: item.variantId,
                                  exactVariantMatch: true,
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
                            Material(
                              color: AppColors.sageTint,
                              borderRadius: BorderRadius.circular(100),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    // Decrease Button
                                    InkWell(
                                      borderRadius: BorderRadius.circular(100),
                                      onTap: () {
                                        if (item.qty <= 1) {
                                          _confirmRemoveItem(
                                              context, item, orderProvider);
                                        } else {
                                          orderProvider.adjustPreCartQty(
                                            item.productId,
                                            -1,
                                            maxStock > 0 ? maxStock : item.qty,
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
                                      onTap: isItemUnavailable
                                          ? null
                                          : () => _showEditQuantityDialog(
                                                context: context,
                                                item: item,
                                                unitPrice: unitPrice,
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
                                      borderRadius: BorderRadius.circular(100),
                                      onTap: () {
                                        if (isItemUnavailable) {
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'This item is currently out of stock.'),
                                              backgroundColor: AppColors.error,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        } else if (item.qty >= maxStock) {
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
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color: isItemUnavailable
                                              ? AppColors.mutedText
                                              : AppColors.forest,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Pickup details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: settings.isEmergencyClosed
                                      ? AppColors.error.withValues(alpha: 0.12)
                                      : (settings.effectivelyClosed
                                          ? AppColors.orangeCTALight
                                          : AppColors.sageTint),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: settings.isEmergencyClosed
                                            ? AppColors.error
                                            : (settings.effectivelyClosed
                                                ? AppColors.orangeCTA
                                                : AppColors.forest),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      settings.isEmergencyClosed
                                          ? 'Maintenance'
                                          : settings.formattedDailyHours,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: settings.isEmergencyClosed
                                            ? AppColors.error
                                            : (settings.effectivelyClosed
                                                ? AppColors.orangeCTA
                                                : AppColors.forest),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Live Store Operating Status Banner (Emergency vs After-Hours Reservation)
                          if (settings.isEmergencyClosed)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.error
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_clock_rounded,
                                      size: 18, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      settings.closureReason,
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
                            )
                          else if (settings.effectivelyClosed)
                            Builder(builder: (context) {
                              final nextOpen =
                                  StoreHours.formatNextOpeningLabel(
                                settings: settings,
                              );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.forest.withValues(alpha: 0.18)
                                      : AppColors.sageTint,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.forest
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event_available_rounded,
                                        size: 18, color: AppColors.forest),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        nextOpen != null
                                            ? 'Store is currently closed (Reopens $nextOpen). You can still reserve your pickup slot below!'
                                            : 'Store is currently outside operating hours. Reserve your pickup for the next open slot below!',
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

                          // Product-Based Reservation Policy Banner
                          Builder(builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final IconData noticeIcon = policy.hasPerishables
                                ? Icons.timer_outlined
                                : Icons.verified_user_outlined;
                            final Color borderThemeColor =
                                policy.tier == BasketProductTier.perishableOnly
                                    ? AppColors.orangeCTA
                                    : (policy.tier == BasketProductTier.mixed
                                        ? Colors.amber.shade800
                                        : AppColors.forest);
                            final Color bgColor = policy.tier ==
                                    BasketProductTier.perishableOnly
                                ? (isDark
                                    ? AppColors.orangeCTA
                                        .withValues(alpha: 0.15)
                                    : AppColors.orangeCTALight)
                                : (policy.tier == BasketProductTier.mixed
                                    ? (isDark
                                        ? Colors.amber.withValues(alpha: 0.14)
                                        : const Color(0xFFFFF8E1))
                                    : (isDark
                                        ? AppColors.forest
                                            .withValues(alpha: 0.15)
                                        : AppColors.sageTint));

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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(noticeIcon,
                                        size: 18, color: borderThemeColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              policy.badgeTitle,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                                color: borderThemeColor,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '· ${policy.shortRuleTag}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${policy.detailedNotice} Stock is held until the end of your chosen slot.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Interactive Pickup Time Slot Button Box
                          InkWell(
                            onTap: settings.isEmergencyClosed
                                ? null
                                : _showPickupTimePicker,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: hasAvailablePickupSlots
                                      ? AppColors.forest.withValues(alpha: 0.35)
                                      : AppColors.error.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: hasAvailablePickupSlots
                                          ? AppColors.sageTint
                                          : AppColors.error
                                              .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      hasAvailablePickupSlots
                                          ? Icons.access_time_filled_rounded
                                          : Icons.event_busy_rounded,
                                      color: hasAvailablePickupSlots
                                          ? AppColors.forest
                                          : AppColors.error,
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
                                          'Scheduled pickup time',
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
                                          hasAvailablePickupSlots
                                              ? _pickupSlot
                                              : 'No eligible pickup slots available',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: hasAvailablePickupSlots
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                : AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!settings.isEmergencyClosed) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.sageTint,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: const Text(
                                        'Change',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.mutedText,
                                    ),
                                  ],
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
                        borderRadius: BorderRadius.circular(22),
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
                                '₱${total.toStringAsFixed(2)}',
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
                              onPressed: (_isSubmitting ||
                                      settings.isEmergencyClosed ||
                                      !hasAvailablePickupSlots)
                                  ? null
                                  : _handleConfirmPreOrder,
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
                                  : Text(
                                      settings.isEmergencyClosed
                                          ? 'Store under maintenance'
                                          : (!hasAvailablePickupSlots
                                              ? 'No pickup slots available'
                                              : (settings.effectivelyClosed
                                                  ? 'Reserve pickup order'
                                                  : 'Confirm pre-order')),
                                      style: const TextStyle(
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
    showDialog(
      context: context,
      builder: (_) => _PreOrderAppealDialog(auth: auth),
    );
  }
}

class _PreOrderAppealDialog extends StatefulWidget {
  final AppAuthProvider auth;
  const _PreOrderAppealDialog({required this.auth});

  @override
  State<_PreOrderAppealDialog> createState() => _PreOrderAppealDialogState();
}

class _PreOrderAppealDialogState extends State<_PreOrderAppealDialog> {
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: AppColors.orangeCTA),
          SizedBox(width: 10),
          Expanded(
            child: Text('Submit Restriction Appeal',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
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
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
                  final reason = _reasonCtrl.text.trim();
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

                  setState(() => _submitting = true);

                  try {
                    final appeal = CustomerAppeal(
                      id: '',
                      userId: widget.auth.currentUser?.uid ?? '',
                      customerEmail: widget.auth.email,
                      customerName: widget.auth.displayName,
                      offenseCount: widget.auth.offenseCount,
                      reason: reason,
                      status: AppealStatus.pending,
                      createdAt: TimeService.now,
                    );

                    await FirestoreService().submitAppeal(appeal);

                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            '🎉 Your appeal has been submitted to store admins for review.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _submitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit appeal: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _submitting
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
  }
}
