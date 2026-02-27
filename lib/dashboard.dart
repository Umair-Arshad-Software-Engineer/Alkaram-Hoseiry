import 'package:alkaram_hosiery/services/employee_services.dart';
import 'package:alkaram_hosiery/vendors/addvendors.dart';
import 'package:alkaram_hosiery/vendors/vendorchequepage.dart';
import 'package:alkaram_hosiery/vendors/viewvendors.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'EmployeeManagementPage.dart';
import 'GodownTransferPage.dart';
import 'itemsManagement.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final RealtimeDatabaseService _databaseService =
  RealtimeDatabaseService();

  Map<String, dynamic> _employeeStats = {
    'total': 0, 'monthly': 0, 'daily': 0,
    'perPiece': 0, 'perDozen': 0,
  };
  Map<String, dynamic> _vendorStats = {
    'totalVendors': 0, 'totalBills': 0.0,
    'totalPayments': 0.0, 'pendingCheques': 0,
  };
  Map<String, dynamic> _itemStats   = {'totalItems': 0};
  Map<String, dynamic> _godownStats = {     // ← NEW
    'totalTransfers': 0,
    'totalQty': 0,
    'todayQty': 0,
  };

  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  static const Color _bgPrimary     = Color(0xFFF8FAFC);
  static const Color _bgSecondary   = Color(0xFFFFFFFF);
  static const Color _bgCard        = Color(0xFFFFFFFF);
  static const Color _accentOrange  = Color(0xFFFF8A65);
  static const Color _accentAmber   = Color(0xFFFFB74D);
  static const Color _accentTeal    = Color(0xFF26A69A);
  static const Color _accentGreen   = Color(0xFF66BB6A);
  static const Color _accentPurple  = Color(0xFFAB47BC);
  static const Color _accentBlue    = Color(0xFF42A5F5);
  static const Color _textPrimary   = Color(0xFF2C3E50);
  static const Color _textSecondary = Color(0xFF7F8C8D);
  static const Color _borderColor   = Color(0xFFE2E8F0);
  static const Color _shadowColor   = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    _loadStatistics();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    final results = await Future.wait([
      _databaseService.getStatistics(),
      _loadVendorStats(),
      _loadItemStats(),
      _loadGodownStats(),   // ← NEW
    ]);

    setState(() {
      _employeeStats = results[0];
      _vendorStats   = results[1];
      _itemStats     = results[2];
      _godownStats   = results[3];   // ← NEW
      _isLoading     = false;
    });
    _fadeController.forward();
  }

  Future<Map<String, dynamic>> _loadVendorStats() async {
    try {
      final snapshot =
      await FirebaseDatabase.instance.ref('vendors').get();
      if (snapshot.value == null) {
        return {
          'totalVendors': 0, 'totalBills': 0.0,
          'totalPayments': 0.0, 'pendingCheques': 0
        };
      }
      final data = snapshot.value as Map<dynamic, dynamic>;
      int    totalVendors   = 0;
      double totalBills     = 0.0;
      double totalPayments  = 0.0;
      int    pendingCheques = 0;

      for (final entry in data.entries) {
        totalVendors++;
        final vendor =
            entry.value as Map<dynamic, dynamic>? ?? {};
        totalBills +=
            (vendor['openingBalance'] ?? 0.0).toDouble();
        final bills = vendor['bills'];
        if (bills != null && bills is Map) {
          for (final bill in
          (bills as Map<dynamic, dynamic>).values) {
            totalBills +=
                (bill['amount'] ?? 0.0).toDouble();
          }
        }
        final payments = vendor['payments'];
        if (payments != null && payments is Map) {
          for (final payment in
          (payments as Map<dynamic, dynamic>).values) {
            final method = payment['method'] ?? '';
            final status = payment['status'] ?? '';
            if (method != 'Cheque' || status == 'cleared') {
              totalPayments +=
                  (payment['amount'] ?? 0.0).toDouble();
            }
          }
        }
      }
      final chSnap = await FirebaseDatabase.instance
          .ref('vendorCheques').get();
      if (chSnap.value != null) {
        for (final c in
        (chSnap.value as Map<dynamic, dynamic>).values) {
          if ((c['status'] ?? '') == 'pending')
            pendingCheques++;
        }
      }
      return {
        'totalVendors': totalVendors,
        'totalBills': totalBills,
        'totalPayments': totalPayments,
        'pendingCheques': pendingCheques,
      };
    } catch (e) {
      debugPrint('Vendor stats error: $e');
      return {
        'totalVendors': 0, 'totalBills': 0.0,
        'totalPayments': 0.0, 'pendingCheques': 0
      };
    }
  }

  Future<Map<String, dynamic>> _loadItemStats() async {
    try {
      final snap =
      await FirebaseDatabase.instance.ref('items').get();
      if (snap.value == null) return {'totalItems': 0};
      return {
        'totalItems':
        (snap.value as Map<dynamic, dynamic>).length
      };
    } catch (e) {
      return {'totalItems': 0};
    }
  }

  // ── Godown stats ─────────────────────────────────────────────
  Future<Map<String, dynamic>> _loadGodownStats() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('godown_transfers').get();
      if (snap.value == null) {
        return {'totalTransfers': 0, 'totalQty': 0, 'todayQty': 0};
      }
      final data = snap.value as Map<dynamic, dynamic>;
      int totalTransfers = 0;
      int totalQty       = 0;
      int todayQty       = 0;
      final now = DateTime.now();

      for (final v in data.values) {
        totalTransfers++;
        final qty = (v['qty'] ?? 0) is int
            ? v['qty'] as int
            : int.tryParse(v['qty'].toString()) ?? 0;
        totalQty += qty;
        final dt = DateTime.tryParse(
            v['transferredAt']?.toString() ?? '');
        if (dt != null &&
            dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day) {
          todayQty += qty;
        }
      }
      return {
        'totalTransfers': totalTransfers,
        'totalQty': totalQty,
        'todayQty': todayQty,
      };
    } catch (e) {
      debugPrint('Godown stats error: $e');
      return {'totalTransfers': 0, 'totalQty': 0, 'todayQty': 0};
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: _isLoading
          ? Center(
          child: CircularProgressIndicator(
              color: _accentOrange, strokeWidth: 2))
          : FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),

                  // ── Employee Section ──────────
                  _buildSectionHeader(
                      'Employee Management',
                      Icons.people_outline,
                      _accentOrange),
                  const SizedBox(height: 16),
                  _buildEmployeeStats(),
                  const SizedBox(height: 16),
                  _buildEmployeeActions(),

                  const SizedBox(height: 32),

                  // ── Vendor Section ────────────
                  _buildSectionHeader(
                      'Vendor Management',
                      Icons.storefront_outlined,
                      _accentTeal),
                  const SizedBox(height: 16),
                  _buildVendorStats(),
                  const SizedBox(height: 16),
                  _buildVendorActions(),

                  const SizedBox(height: 32),

                  // ── Item Section ──────────────
                  _buildSectionHeader(
                      'Item Management',
                      Icons.inventory_2_outlined,
                      _accentPurple),
                  const SizedBox(height: 16),
                  _buildItemStats(),
                  const SizedBox(height: 16),
                  _buildItemActions(),

                  const SizedBox(height: 32),

                  // ── Godown Section ────────────  ← NEW
                  _buildSectionHeader(
                      'Godown Transfers',
                      Icons.local_shipping_outlined,
                      _accentTeal),
                  const SizedBox(height: 16),
                  _buildGodownStats(),
                  const SizedBox(height: 16),
                  _buildGodownActions(),

                  const SizedBox(height: 32),

                  // ── Financial Summary ─────────
                  _buildSummaryCards(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sliver App Bar ───────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _bgSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: _shadowColor,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _borderColor),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          color: _bgSecondary,
          child: Padding(
            padding:
            const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [
                            _accentOrange,
                            _accentAmber
                          ]),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('AK',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text('Al-Karam Hosiery',
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text('Management Dashboard',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13)),
                    ],
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      title: Row(children: [
        Container(
          width: 3, height: 18,
          decoration: BoxDecoration(
              color: _accentOrange,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        const Text('Dashboard',
            style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
      ]),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded,
              color: _textSecondary, size: 20),
          onPressed: () {
            setState(() => _isLoading = true);
            _fadeController.reset();
            _loadStatistics();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Section Header ───────────────────────────────────────────
  Widget _buildSectionHeader(
      String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Text(title,
          style: const TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600)),
      const Spacer(),
      Container(height: 1, width: 60, color: _borderColor),
    ]);
  }

  // ── Employee Stats ───────────────────────────────────────────
  Widget _buildEmployeeStats() {
    final stats = [
      _StatConfig(label: 'Total',     value: _employeeStats['total'].toString(),   icon: Icons.groups,         color: _accentOrange),
      _StatConfig(label: 'Monthly',   value: _employeeStats['monthly'].toString(), icon: Icons.calendar_month, color: _accentTeal),
      _StatConfig(label: 'Daily',     value: _employeeStats['daily'].toString(),   icon: Icons.today,          color: _accentGreen),
      _StatConfig(label: 'Per Piece', value: _employeeStats['perPiece'].toString(),icon: Icons.inventory,      color: _accentPurple),
      _StatConfig(label: 'Per Dozen', value: (_employeeStats['perDozen'] ?? 0).toString(), icon: Icons.grid_view, color: _accentBlue),
    ];
    final cardWidth =
        (MediaQuery.of(context).size.width - 40 - 48) / 4;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats
          .map((s) => SizedBox(
          width: cardWidth,
          child: _buildCompactStatCard(s)))
          .toList(),
    );
  }

  // ── Vendor Stats ─────────────────────────────────────────────
  Widget _buildVendorStats() {
    return Row(children: [
      Expanded(child: _buildInfoCard('Vendors',  _vendorStats['totalVendors'].toString(),   Icons.store,           _accentTeal)),
      const SizedBox(width: 12),
      Expanded(child: _buildInfoCard('Bills (Rs)', (_vendorStats['totalBills'] as double).toStringAsFixed(0), Icons.receipt, _accentPurple)),
      const SizedBox(width: 12),
      Expanded(child: _buildInfoCard('Paid (Rs)',  (_vendorStats['totalPayments'] as double).toStringAsFixed(0), Icons.payment, _accentGreen)),
      const SizedBox(width: 12),
      Expanded(child: _buildInfoCard('Pend. Cheques', _vendorStats['pendingCheques'].toString(), Icons.pending_actions, _accentOrange)),
    ]);
  }

  // ── Item Stats ───────────────────────────────────────────────
  Widget _buildItemStats() {
    return Row(children: [
      Expanded(child: _buildInfoCard('Total Items', _itemStats['totalItems'].toString(), Icons.inventory_2, _accentPurple)),
    ]);
  }

  // ── Godown Stats ─────────────────────────────────────────────  ← NEW
  Widget _buildGodownStats() {
    return Row(children: [
      Expanded(child: _buildInfoCard(
          'Transfers',
          _godownStats['totalTransfers'].toString(),
          Icons.swap_horiz,
          _accentTeal)),
      const SizedBox(width: 12),
      Expanded(child: _buildInfoCard(
          'Total Qty',
          _godownStats['totalQty'].toString(),
          Icons.inventory_2,
          _accentPurple)),
      const SizedBox(width: 12),
      Expanded(child: _buildInfoCard(
          "Today's Qty",
          _godownStats['todayQty'].toString(),
          Icons.today,
          _accentGreen)),
    ]);
  }

  // ── Godown Actions ───────────────────────────────────────────  ← NEW
  Widget _buildGodownActions() {
    final actions = [
      _ActionConfig(
          title: 'All Transfers',
          icon: Icons.list_alt,
          color: _accentTeal,
          page: const GodownTransferPage()),
      _ActionConfig(
          title: 'New Transfer',
          icon: Icons.local_shipping,
          color: _accentGreen,
          page: const GodownTransferPage()),
      _ActionConfig(
          title: 'Reports',
          icon: Icons.bar_chart,
          color: _accentPurple,
          page: const GodownTransferPage()),
    ];
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            _buildCompactActionChip(actions[i]),
      ),
    );
  }

  // ── Item Actions ─────────────────────────────────────────────
  Widget _buildItemActions() {
    final actions = [
      _ActionConfig(title: 'All Items', icon: Icons.inventory_2, color: _accentPurple, page: const ItemManagementPage()),
      _ActionConfig(title: 'Add Item',  icon: Icons.add_box,     color: _accentGreen,  page: const ItemManagementPage()),
    ];
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            _buildCompactActionChip(actions[i]),
      ),
    );
  }

  // ── Compact stat card ────────────────────────────────────────
  Widget _buildCompactStatCard(_StatConfig stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(stat.icon, color: stat.color, size: 20),
        const SizedBox(height: 8),
        Text(stat.value,
            style: TextStyle(color: stat.color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(stat.label,
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ]),
    );
  }

  // ── Info card ────────────────────────────────────────────────
  Widget _buildInfoCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Employee Actions ─────────────────────────────────────────
  Widget _buildEmployeeActions() {
    final actions = [
      _ActionConfig(title: 'All Employees', icon: Icons.people,         color: _accentOrange, page: EmployeeManagementPage(initialTab: 0)),
      _ActionConfig(title: 'Monthly',       icon: Icons.calendar_month, color: _accentTeal,   page: EmployeeManagementPage(initialTab: 1)),
      _ActionConfig(title: 'Daily',         icon: Icons.today,          color: _accentGreen,  page: EmployeeManagementPage(initialTab: 2)),
      _ActionConfig(title: 'Per Piece',     icon: Icons.inventory,      color: _accentPurple, page: EmployeeManagementPage(initialTab: 3)),
    ];
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            _buildCompactActionChip(actions[i]),
      ),
    );
  }

  // ── Vendor Actions ───────────────────────────────────────────
  Widget _buildVendorActions() {
    final actions = [
      _ActionConfig(title: 'View Vendors',    icon: Icons.store,         color: _accentTeal,   page: const ViewVendorsPage()),
      _ActionConfig(title: 'Add Vendor',      icon: Icons.add_business,  color: _accentGreen,  page: const AddVendorPage()),
      _ActionConfig(title: 'Pending Cheques', icon: Icons.pending,       color: _accentOrange, page: const VendorChequesPage()),
      _ActionConfig(title: 'All Bills',       icon: Icons.receipt_long,  color: _accentPurple, page: null),
    ];
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            _buildCompactActionChip(actions[i]),
      ),
    );
  }

  // ── Action chip ──────────────────────────────────────────────
  Widget _buildCompactActionChip(_ActionConfig action) {
    return Material(
      color: _bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.page != null
            ? () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => action.page!))
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Icon(action.icon, color: action.color, size: 18),
            const SizedBox(width: 8),
            Text(action.title,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  // ── Financial Summary ────────────────────────────────────────
  Widget _buildSummaryCards() {
    final outstanding = (_vendorStats['totalBills'] as double) -
        (_vendorStats['totalPayments'] as double);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.analytics,
                color: _accentOrange),
          ),
          const SizedBox(width: 12),
          const Text('Financial Summary',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: _buildSummaryItem('Total Employees',     _employeeStats['total'].toString(),  Icons.people,       _accentOrange)),
          Expanded(child: _buildSummaryItem('Total Vendors',       _vendorStats['totalVendors'].toString(), Icons.store,    _accentTeal)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildSummaryItem('Total Bills',    'Rs ${(_vendorStats['totalBills'] as double).toStringAsFixed(0)}',    Icons.receipt, _accentPurple)),
          Expanded(child: _buildSummaryItem('Total Paid',     'Rs ${(_vendorStats['totalPayments'] as double).toStringAsFixed(0)}', Icons.payment, _accentGreen)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildSummaryItem('Total Items',       _itemStats['totalItems'].toString(),           Icons.inventory_2,    _accentBlue)),
          Expanded(child: _buildSummaryItem('Godown Transfers',  _godownStats['totalTransfers'].toString(),     Icons.local_shipping, _accentTeal)),   // ← NEW
        ]),
        const SizedBox(height: 16),

        // Outstanding balance
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: outstanding >= 0
                ? _accentOrange.withOpacity(0.1)
                : _accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Outstanding Balance',
                  style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w500)),
              Text(
                'Rs ${outstanding.toStringAsFixed(2)}',
                style: TextStyle(
                    color: outstanding >= 0
                        ? _accentOrange
                        : _accentGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: _textSecondary, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
    ]);
  }
}

// ── Helper models ────────────────────────────────────────────
class _StatConfig {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatConfig({required this.label, required this.value, required this.icon, required this.color});
}

class _ActionConfig {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? page;
  const _ActionConfig({required this.title, required this.icon, required this.color, this.page});
}