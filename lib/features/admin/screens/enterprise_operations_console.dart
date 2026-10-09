import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/order.dart';
import '../../shop/providers/inventory_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/common/status_badge.dart';

class EnterpriseOperationsConsole extends StatefulWidget {
  const EnterpriseOperationsConsole({super.key});

  @override
  State<EnterpriseOperationsConsole> createState() =>
      _EnterpriseOperationsConsoleState();
}

class _EnterpriseOperationsConsoleState
    extends State<EnterpriseOperationsConsole> {
  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final orderProvider = context.watch<OrderProvider>();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: GdcColors.warmBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 70,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.dashboard_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Admin Dashboard',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                            letterSpacing: -0.3)),
                    Text(
                        'Executive Control, Automated Inventory & Operations Suite',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: GdcColors.peachLight,
            indicatorWeight: 3,
            labelStyle: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
            tabs: [
              Tab(
                  icon: Icon(Icons.space_dashboard_rounded, size: 18),
                  text: 'ADMIN DASHBOARD'),
              Tab(
                  icon: Icon(Icons.auto_graph_rounded, size: 18),
                  text: 'INVENTORY AUTOMATION'),
              Tab(
                  icon: Icon(Icons.local_shipping_rounded, size: 18),
                  text: 'ORDER LOGISTICS'),
              Tab(
                  icon: Icon(Icons.gavel_rounded, size: 18),
                  text: 'DISPUTE GOVERNANCE'),
              Tab(
                  icon: Icon(Icons.tune_rounded, size: 18),
                  text: 'SYSTEM POLICY'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DashboardOverviewTab(
                inventory: inventory, orderProvider: orderProvider),
            _InventoryAutomationTab(inventory: inventory),
            _OrderLogisticsTab(
                orderProvider: orderProvider, inventory: inventory),
            _DisputeGovernanceTab(orderProvider: orderProvider),
            _SystemPolicyTab(inventory: inventory),
          ],
        ),
      ),
    );
  }
}

// ── Tab 0: Admin Dashboard Overview ──────────────────────────────────────────

class _DashboardOverviewTab extends StatelessWidget {
  final InventoryProvider inventory;
  final OrderProvider orderProvider;

  const _DashboardOverviewTab(
      {required this.inventory, required this.orderProvider});

  @override
  Widget build(BuildContext context) {
    final reorderQueue = inventory.autoReorderQueue;
    final expiredQueue = inventory.expiredQueue;
    final criticalQueue = inventory.criticalExpiryQueue;
    final settings = inventory.settings;

    return StreamBuilder<List<PreOrder>>(
      stream: orderProvider.ordersStream,
      builder: (context, snap) {
        final allOrders = snap.data ?? orderProvider.orders;
        final activeOrders = allOrders
            .where((o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.staging ||
                o.status == OrderStatus.ready)
            .toList();
        final pendingRefunds = allOrders
            .where((o) => o.status == OrderStatus.refundRequested)
            .toList();

        final totalSalesAmount = allOrders
            .where((o) => o.status == OrderStatus.collected)
            .fold(0.0, (sum, o) => sum + o.total);

        return RefreshIndicator(
          onRefresh: () async => inventory.refreshData(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Executive Summary Banner ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [GdcColors.warmBrown, GdcColors.terracottaDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded,
                                color: GdcColors.peachLight, size: 18),
                            SizedBox(width: 8),
                            Text('EXECUTIVE DASHBOARD OVERVIEW',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: settings.effectivelyClosed
                                ? GdcColors.error
                                : GdcColors.success,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            settings.effectivelyClosed
                                ? 'STORE OVERRIDE: CLOSED'
                                : 'LIVE OPERATIONAL',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardMetricCard(
                            label: 'TOTAL REVENUE',
                            value: formatPeso(totalSalesAmount),
                            subText: 'Collected Orders',
                            icon: Icons.payments_rounded,
                            accentColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashboardMetricCard(
                            label: 'INVENTORY VALUE',
                            value: formatPeso(inventory.totalRetailValuation),
                            subText:
                                '${inventory.grossMarginPercentage.toStringAsFixed(0)}% Margin',
                            icon: Icons.inventory_2_rounded,
                            accentColor: GdcColors.peachLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text('Store Health & Operations Summary',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: GdcColors.textPrimary)),
              const SizedBox(height: 12),

              // Metric Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _StatusTile(
                    title: 'Active Orders Queue',
                    value: '${activeOrders.length}',
                    statusText: activeOrders.isNotEmpty
                        ? 'Needs Processing'
                        : 'All Clear',
                    icon: Icons.local_shipping_rounded,
                    color: activeOrders.isNotEmpty
                        ? GdcColors.terracotta
                        : Colors.grey,
                  ),
                  _StatusTile(
                    title: 'Auto-Reorder SKUs',
                    value: '${reorderQueue.length}',
                    statusText: reorderQueue.isNotEmpty
                        ? 'ROP Triggered'
                        : 'Stock Optimal',
                    icon: Icons.published_with_changes_rounded,
                    color: reorderQueue.isNotEmpty
                        ? GdcColors.warning
                        : GdcColors.success,
                  ),
                  _StatusTile(
                    title: 'Expiry Telemetry',
                    value: '${expiredQueue.length + criticalQueue.length}',
                    statusText:
                        '${expiredQueue.length} Expired · ${criticalQueue.length} Critical',
                    icon: Icons.no_food_rounded,
                    color: expiredQueue.isNotEmpty
                        ? GdcColors.error
                        : GdcColors.warning,
                  ),
                  _StatusTile(
                    title: 'Dispute Claims',
                    value: '${pendingRefunds.length}',
                    statusText: pendingRefunds.isNotEmpty
                        ? 'Requires Action'
                        : 'No Claims',
                    icon: Icons.gavel_rounded,
                    color: pendingRefunds.isNotEmpty
                        ? GdcColors.warning
                        : Colors.grey,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Quick Automated Triggers ──────────────────────────────────
              const Text('Automated One-Tap Triggers',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: GdcColors.textPrimary)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: reorderQueue.isEmpty
                          ? null
                          : () async {
                              final count = await inventory
                                  .executeBulkAutoReplenishment();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      'Automated restock executed for $count SKUs!'),
                                  backgroundColor: GdcColors.success,
                                ));
                              }
                            },
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text('AUTO-RESTOCK (${reorderQueue.length})',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: GdcColors.terracotta,
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: expiredQueue.isEmpty
                          ? null
                          : () async {
                              final count = await inventory
                                  .executeAutoQuarantineExpired();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      'Automated quarantine applied to $count expired SKUs.'),
                                  backgroundColor: GdcColors.warning,
                                ));
                              }
                            },
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: Text('QUARANTINE EXPIRED (${expiredQueue.length})',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: GdcColors.warning,
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Live Order Stream Preview ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live Active Orders',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: GdcColors.textPrimary)),
                  Text('${activeOrders.length} pending',
                      style: const TextStyle(
                          fontSize: 12,
                          color: GdcColors.textMuted,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),

              if (activeOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Center(
                    child: Text(
                        'No active customer orders waiting to be packed.',
                        style: TextStyle(
                            color: GdcColors.textMuted,
                            fontWeight: FontWeight.bold)),
                  ),
                )
              else
                ...activeOrders.take(3).map((o) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text('${o.orderId} · ${o.customerName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                            '${o.items.length} items · Pickup: ${o.pickupTime}',
                            style: const TextStyle(
                                fontSize: 11, color: GdcColors.textMuted)),
                        trailing: StatusBadge(o.status),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subText;
  final IconData icon;
  final Color accentColor;

  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.subText,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subText,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String value;
  final String statusText;
  final IconData icon;
  final Color color;

  const _StatusTile({
    required this.title,
    required this.value,
    required this.statusText,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: GdcColors.textMuted)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(statusText,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ── Tab 1: Automated Inventory Control & Governance ─────────────────────────

class _InventoryAutomationTab extends StatefulWidget {
  final InventoryProvider inventory;
  const _InventoryAutomationTab({required this.inventory});

  @override
  State<_InventoryAutomationTab> createState() =>
      _InventoryAutomationTabState();
}

class _InventoryAutomationTabState extends State<_InventoryAutomationTab> {
  final _searchCtrl = TextEditingController();
  String _filterQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.inventory;
    final products = inv.products;
    final reorderQueue = inv.autoReorderQueue;
    final expiredQueue = inv.expiredQueue;
    final criticalQueue = inv.criticalExpiryQueue;

    final categories = [
      'All',
      ...products.map((p) => p.category).toSet().toList()..sort()
    ];

    final filteredProducts = products.where((p) {
      final matchesSearch = _filterQuery.isEmpty ||
          p.name.toLowerCase().contains(_filterQuery.toLowerCase()) ||
          (p.barcode != null && p.barcode!.contains(_filterQuery));
      final matchesCat =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => inv.refreshData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Executive KPI Telemetry Banner ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [GdcColors.warmBrown, GdcColors.terracottaDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COMMERCIAL ASSET VALUATION',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                    Icon(Icons.analytics_rounded,
                        color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatPeso(inv.totalRetailValuation),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text('Retail Value',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MetricTile(
                      label: 'COST BASIS (COGS)',
                      value: formatPeso(inv.totalCostValuation),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    _MetricTile(
                      label: 'GROSS MARGIN %',
                      value: '${inv.grossMarginPercentage.toStringAsFixed(1)}%',
                      color: inv.grossMarginPercentage >= 20
                          ? GdcColors.peachLight
                          : Colors.amberAccent,
                    ),
                    const SizedBox(width: 16),
                    _MetricTile(
                      label: 'ACTIVE SKU COUNT',
                      value: '${products.length}',
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Automated Reorder Trigger Panel ──────────────────────────────
          _AutomationActionCard(
            title: 'Automated Stock Replenishment Engine',
            subtitle:
                '${reorderQueue.length} SKU(s) triggered reorder threshold (ROP)',
            icon: Icons.published_with_changes_rounded,
            badgeColor:
                reorderQueue.isNotEmpty ? GdcColors.warning : GdcColors.success,
            badgeText: reorderQueue.isNotEmpty
                ? '${reorderQueue.length} REORDER REQUIRED'
                : 'OPTIMAL STOCK',
            actionLabel: 'EXECUTE BULK AUTOMATED REPLENISHMENT',
            onAction: reorderQueue.isEmpty
                ? null
                : () async {
                    final count = await inv.executeBulkAutoReplenishment();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Automated restock executed for $count SKUs!'),
                        backgroundColor: GdcColors.success,
                      ));
                    }
                  },
            child: reorderQueue.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        'All inventory items maintain optimal stock levels above Reorder Points.',
                        style: TextStyle(
                            fontSize: 12, color: GdcColors.textMuted)),
                  )
                : Column(
                    children: reorderQueue
                        .take(3)
                        .map((p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              subtitle: Text(
                                  'Current Stock: ${p.totalStock} ${p.unit} · ROP: ${p.effectiveReorderPoint} · Rec. Reorder: +${p.effectiveReorderQuantity}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: GdcColors.textMuted)),
                              trailing: Text(formatPeso(p.price),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // ── Automated Expiry & Quarantine Telemetry Panel ──────────────────
          _AutomationActionCard(
            title: 'Automated Quality & Expiry Control',
            subtitle:
                '${expiredQueue.length} expired SKU(s), ${criticalQueue.length} critical (<48h)',
            icon: Icons.no_food_rounded,
            badgeColor: expiredQueue.isNotEmpty
                ? GdcColors.error
                : (criticalQueue.isNotEmpty
                    ? GdcColors.warning
                    : GdcColors.success),
            badgeText: expiredQueue.isNotEmpty
                ? '${expiredQueue.length} EXPIRED'
                : '${criticalQueue.length} CRITICAL',
            actionLabel: 'EXECUTE AUTOMATED EXPIRY QUARANTINE',
            onAction: expiredQueue.isEmpty
                ? null
                : () async {
                    final count = await inv.executeAutoQuarantineExpired();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Automated quarantine applied to $count expired SKUs.'),
                        backgroundColor: GdcColors.warning,
                      ));
                    }
                  },
            child: (expiredQueue.isEmpty && criticalQueue.isEmpty)
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        'No expired or critical perishable inventory detected.',
                        style: TextStyle(
                            fontSize: 12, color: GdcColors.textMuted)),
                  )
                : Column(
                    children: [
                      ...expiredQueue.map((p) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.report_problem_rounded,
                                color: GdcColors.error, size: 20),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: GdcColors.error)),
                            subtitle: Text(
                                'Expired on ${p.expiryDate != null ? DateFormat('MMM dd, yyyy').format(p.expiryDate!) : 'N/A'} · Stock: ${p.totalStock}',
                                style: const TextStyle(
                                    fontSize: 11, color: GdcColors.textMuted)),
                          )),
                      ...criticalQueue.map((p) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_rounded,
                                color: GdcColors.warning, size: 20),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(
                                'Expires in ${p.daysUntilExpiry} days (${DateFormat('MMM dd').format(p.expiryDate!)})',
                                style: const TextStyle(
                                    fontSize: 11, color: GdcColors.textMuted)),
                          )),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ── Catalog Stock Reconciliation & Audit Editor ────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stock Counts & Catalog',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: GdcColors.textPrimary)),
              ElevatedButton.icon(
                onPressed: () => _showProductEditorModal(context, inv, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Product',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search SKU name or barcode...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _filterQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedCategory,
                items: categories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedCategory = v ?? 'All'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Catalog List
          ...filteredProducts.map((p) {
            final abc = inv.getProductAbcCategory(p.id);
            final abcLabel = switch (abc) {
              InventoryAbcCategory.categoryA => 'Class A (Fast)',
              InventoryAbcCategory.categoryB => 'Class B (Mid)',
              InventoryAbcCategory.categoryC => 'Class C (Slow)',
            };
            final abcColor = switch (abc) {
              InventoryAbcCategory.categoryA => Colors.purple,
              InventoryAbcCategory.categoryB => Colors.blue,
              InventoryAbcCategory.categoryC => Colors.grey,
            };

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: p.isQuarantined
                      ? GdcColors.error
                      : (p.isAutoReorderRequired
                          ? GdcColors.warning.withValues(alpha: 0.5)
                          : Colors.grey.shade200),
                ),
              ),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: abcColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(abcLabel,
                          style: TextStyle(
                              color: abcColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                        'Price: ${formatPeso(p.price)} · Cost: ${formatPeso(p.effectiveCostPrice)} · Stock: ${p.totalStock} ${p.unit}',
                        style: const TextStyle(
                            fontSize: 12, color: GdcColors.textSecondary)),
                    Text(
                        'ROP: ${p.effectiveReorderPoint} · Reorder Qty: +${p.effectiveReorderQuantity} · Margin: ${p.unitGrossMargin.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 11, color: GdcColors.textMuted)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded,
                          color: GdcColors.terracotta),
                      onPressed: () =>
                          _showStockReconciliationModal(context, inv, p),
                      tooltip: 'Quick Stock Reconciliation',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.grey),
                      onPressed: () => _showProductEditorModal(context, inv, p),
                      tooltip: 'Edit Full Product Settings',
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showStockReconciliationModal(
      BuildContext context, InventoryProvider inv, Product product) {
    final qtyCtrl = TextEditingController(text: '${product.stock}');
    final reasonCtrl =
        TextEditingController(text: 'Physical Audit Reconciliation');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reconcile Stock: ${product.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'New Corrected Stock Count', suffixText: 'units'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                  labelText: 'Audit Reason',
                  hintText: 'Restock, Count Adjustment, Damage'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStock =
                  int.tryParse(qtyCtrl.text.trim()) ?? product.stock;
              final auth = context.read<AppAuthProvider>();
              await inv.updateStockWithAuditLog(
                productId: product.id,
                newStock: newStock,
                reason: reasonCtrl.text.trim(),
                operatorEmail: auth.email,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save & Audit Log'),
          ),
        ],
      ),
    );
  }

  void _showProductEditorModal(
      BuildContext context, InventoryProvider inv, Product? p) {
    final nameCtrl = TextEditingController(text: p?.name ?? '');
    final catCtrl = TextEditingController(text: p?.category ?? 'General');
    final priceCtrl =
        TextEditingController(text: p != null ? '${p.price}' : '');
    final costCtrl =
        TextEditingController(text: p != null ? '${p.effectiveCostPrice}' : '');
    final stockCtrl =
        TextEditingController(text: p != null ? '${p.stock}' : '10');
    final ropCtrl = TextEditingController(
        text: p != null ? '${p.effectiveReorderPoint}' : '10');
    final reorderQtyCtrl = TextEditingController(
        text: p != null ? '${p.effectiveReorderQuantity}' : '20');
    final barcodeCtrl = TextEditingController(text: p?.barcode ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p == null ? 'Create New Product' : 'Edit SKU: ${p.name}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name')),
              const SizedBox(height: 8),
              TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Retail Price (₱)'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Cost Price (₱)'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Current Stock'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: ropCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Reorder Point (ROP)'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: reorderQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Recommended Reorder Quantity')),
              const SizedBox(height: 8),
              TextField(
                  controller: barcodeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Barcode (Optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newProd = Product(
                id: p?.id ?? '',
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                costPrice: double.tryParse(costCtrl.text.trim()) ?? 0,
                stock: int.tryParse(stockCtrl.text.trim()) ?? 0,
                reorderPoint: int.tryParse(ropCtrl.text.trim()) ?? 10,
                reorderQuantity: int.tryParse(reorderQtyCtrl.text.trim()) ?? 20,
                barcode: barcodeCtrl.text.trim().isNotEmpty
                    ? barcodeCtrl.text.trim()
                    : null,
                status: ProductStatus.published,
              );
              await inv.saveProduct(newProd);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save SKU'),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Logistics & Order Fulfillment ─────────────────────────────────────

class _OrderLogisticsTab extends StatelessWidget {
  final OrderProvider orderProvider;
  final InventoryProvider inventory;

  const _OrderLogisticsTab(
      {required this.orderProvider, required this.inventory});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PreOrder>>(
      stream: orderProvider.ordersStream,
      builder: (context, snap) {
        if (snap.hasError)
          return Center(child: Text('Logistics Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final allOrders = snap.data!;
        final activeOrders = allOrders
            .where((o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.staging ||
                o.status == OrderStatus.ready)
            .toList();

        if (activeOrders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text('All Orders Completed',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: activeOrders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final o = activeOrders[i];
            final nextActionLabel = switch (o.status) {
              OrderStatus.pending => 'ACCEPT & STAGE ORDER',
              OrderStatus.staging => 'MARK READY FOR PICKUP',
              OrderStatus.ready => 'CONFIRM PICKUP',
              _ => 'COMPLETE',
            };

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(o.orderId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: GdcColors.warmBrown)),
                        StatusBadge(o.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Customer: ${o.customerName} (${o.customerEmail})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                        'Pickup Slot: ${o.pickupTime} · Location: ${o.location}',
                        style: const TextStyle(
                            fontSize: 11, color: GdcColors.textMuted)),
                    const Divider(height: 16),
                    ...o.items.map((item) => Text(
                        '• ${item.qty}x ${item.name} (${formatPeso(item.price)})',
                        style: const TextStyle(fontSize: 12))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Payable: ${formatPeso(o.total)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: GdcColors.terracotta,
                                fontSize: 15)),
                        ElevatedButton(
                          onPressed: () async {
                            await orderProvider.advanceStatus(o.id);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GdcColors.terracotta,
                            minimumSize: const Size(120, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(nextActionLabel,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 3: Dispute Resolution & Capital Restitution Governance ─────────────

class _DisputeGovernanceTab extends StatelessWidget {
  final OrderProvider orderProvider;

  const _DisputeGovernanceTab({required this.orderProvider});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PreOrder>>(
      stream: orderProvider.ordersStream,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final refundRequestedOrders = snap.data!
            .where((o) => o.status == OrderStatus.refundRequested)
            .toList();

        if (refundRequestedOrders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text('No Pending Refund Claims',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: refundRequestedOrders.length,
          itemBuilder: (context, i) {
            final order = refundRequestedOrders[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: GdcColors.warning),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.orderId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        StatusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Customer: ${order.customerName} (${order.customerEmail})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const Divider(height: 16),
                    Text('Claim Amount: ${formatPeso(order.total)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: GdcColors.terracotta,
                            fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await orderProvider.refundOrder(order.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Refund Approved & Processed.')));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: GdcColors.success),
                            child: const Text('APPROVE REFUND',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 4: System Policy & Operational Governance ──────────────────────────

class _SystemPolicyTab extends StatefulWidget {
  final InventoryProvider inventory;
  const _SystemPolicyTab({required this.inventory});

  @override
  State<_SystemPolicyTab> createState() => _SystemPolicyTabState();
}

class _SystemPolicyTabState extends State<_SystemPolicyTab> {
  late TextEditingController _announcementCtrl;
  late TextEditingController _closureMessageCtrl;
  late TextEditingController _websiteUrlCtrl;

  @override
  void initState() {
    super.initState();
    final settings = widget.inventory.settings;
    _announcementCtrl =
        TextEditingController(text: settings.announcement ?? '');
    _closureMessageCtrl = TextEditingController(
        text: settings.closureMessage ??
            'Store is currently closed for maintenance.');
    _websiteUrlCtrl = TextEditingController(text: settings.websiteUrl);
  }

  @override
  void dispose() {
    _announcementCtrl.dispose();
    _closureMessageCtrl.dispose();
    _websiteUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.inventory.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SwitchListTile(
            title: const Text('Store Closed / Manual Override',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Prevents new pre-orders from being placed by customers.'),
            value: settings.isClosed,
            onChanged: (val) async {
              final updated = settings.copyWith(isClosed: val);
              await widget.inventory.updateSettings(updated);
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Official Store Website URL',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _websiteUrlCtrl,
                  decoration: const InputDecoration(
                    hintText: 'https://gdc-sari-sari.web.app',
                    labelText: 'Website URL',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final updated = settings.copyWith(
                        websiteUrl: _websiteUrlCtrl.text.trim());
                    await widget.inventory.updateSettings(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Website URL updated!')));
                    }
                  },
                  child: const Text('Save Website URL'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Store Announcement Broadcast',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _announcementCtrl,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Fresh batch of dairy products arrived today!',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final updated = settings.copyWith(
                        announcement: _announcementCtrl.text.trim());
                    await widget.inventory.updateSettings(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Announcement updated!')));
                    }
                  },
                  child: const Text('Broadcast Announcement'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared Helper Widgets ───────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _AutomationActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final String badgeText;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _AutomationActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.badgeText,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: GdcColors.terracotta, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: GdcColors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(badgeText,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: badgeColor,
                  minimumSize: const Size.fromHeight(42),
                ),
                child: Text(actionLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
