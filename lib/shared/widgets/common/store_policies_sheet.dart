import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StorePoliciesSheet extends StatefulWidget {
  final int initialIndex;

  const StorePoliciesSheet({super.key, this.initialIndex = 0});

  static void show(BuildContext context, {int initialIndex = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StorePoliciesSheet(initialIndex: initialIndex),
    );
  }

  @override
  State<StorePoliciesSheet> createState() => _StorePoliciesSheetState();
}

class _StorePoliciesSheetState extends State<StorePoliciesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : const Color(0xFFF7F6F0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.sageTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: AppColors.forest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Policies & Legal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'GDC Sari-Sari Store Guidelines',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
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
          ),
          const SizedBox(height: 12),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerLow
                  : const Color(0xFFEBE8DE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor:
                  Theme.of(context).textTheme.bodySmall?.color,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Terms'),
                Tab(text: 'Privacy'),
                Tab(text: 'Pickup & Refunds'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab View Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTermsTab(context),
                _buildPrivacyTab(context),
                _buildPickupPolicyTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicyCard(
            context,
            icon: Icons.storefront_rounded,
            title: '1. Account & Store Registration',
            body:
                'Customers must provide their real full name, valid email address, and active mobile number upon registration. Cashiers at GDC Store require name verification upon store pickup to prevent fraudulent pre-orders.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.shopping_basket_rounded,
            title: '2. Pre-Order Agreement',
            body:
                'Submitting a pre-order reserves inventory items for local pickup at GDC Store Main Branch. Pre-orders are binding reservations. Repeated uncollected orders may result in temporary pre-order account restrictions.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.payments_rounded,
            title: '3. Pricing & Currency',
            body:
                'All item prices are listed in Philippine Pesos (₱ PHP) and include applicable local taxes. GDC Store reserves the right to update product pricing and stock availability based on store inventory levels.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.badge_rounded,
            title: '4. Senior Citizen & PWD Discounts',
            body:
                'Qualifying Senior Citizens and Persons with Disability (PWD) are eligible for statutory discounts on basic necessities. Valid OSCA/PWD IDs must be presented to the cashier upon physical pickup for verification.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicyCard(
            context,
            icon: Icons.security_rounded,
            title: '1. Information We Collect',
            body:
                'We collect your Full Name, Email Address, Mobile Number, and Pre-Order History. This data is strictly used for order processing, identity verification during store pickup, and transactional communications.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.mark_email_read_rounded,
            title: '2. OTP & Messaging Security',
            body:
                'One-Time Passwords (OTP) sent via Email (Brevo) or SMS (Store Gateway) are used exclusively for multi-factor authentication. OTP codes expire automatically after 5 minutes and are deleted immediately upon verification.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.lock_outline_rounded,
            title: '3. Data Protection & Privacy',
            body:
                'GDC Store respects your privacy in accordance with the Philippine Data Privacy Act of 2012 (RA 10173). We do not sell, rent, or share your personal data with third-party advertisers or marketing agencies.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.manage_accounts_rounded,
            title: '4. Account Management & Rights',
            body:
                'Customers may update their personal information anytime from the Account Profile screen. For complete data deletion requests, customers can contact store administration.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPickupPolicyTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicyCard(
            context,
            icon: Icons.access_time_filled_rounded,
            title: '1. Store Operating & Pickup Hours',
            body:
                'Pre-orders can be collected during official store hours (11:00 AM – 3:00 PM Daily). Please ensure you arrive within your selected pickup time slot.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.timer_rounded,
            title: '2. Perishable Goods Policy',
            body:
                'Orders containing fresh/perishable produce or dairy must be collected within 2 hours of the selected pickup slot. Perishables not collected within the timeframe will be restocked to prevent spoilage.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.qr_code_scanner_rounded,
            title: '3. Cashless & Reference Numbers',
            body:
                'For GCash or Maya payments, customers must provide a valid Transaction Reference Number. Cashiers verify the payment reference against the store account before handing over goods.',
          ),
          _buildPolicyCard(
            context,
            icon: Icons.replay_rounded,
            title: '4. Order Cancellations & Refunds',
            body:
                'Customers may cancel pending pre-orders directly from the My Orders screen prior to cashier preparation. For damaged or defective goods noticed upon pickup, instant replacements or refunds are issued at the counter.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.forest.withValues(alpha: 0.25)
                      : AppColors.sageTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.forest,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
