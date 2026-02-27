import 'package:alkaram_hosiery/services/employee_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'AddEmployeePage.dart';
import 'ProductionRecordsPage.dart';
import 'EmployeeLedgerPage.dart';
import 'dozenproduction.dart';
import 'dozensproductionrecord.dart';
import 'models/employee_models.dart';
import 'production_tracking_page.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF0F3F8);
  static const border = Color(0xFFDDE3EE);

  static const amber = Color(0xFFE8900A);
  static const green = Color(0xFF0F9E74);
  static const blue = Color(0xFF2473CC);
  static const red = Color(0xFFD63B3B);
  static const purple = Color(0xFF7C3AED);

  static const textPrimary = Color(0xFF1A1F2E);
  static const textSecondary = Color(0xFF5A637A);
  static const textMuted = Color(0xFFA0ABBE);
}

// ─────────────────────────────────────────────────────────────
//  Employee Management Page
// ─────────────────────────────────────────────────────────────
class EmployeeManagementPage extends StatefulWidget {
  final int initialTab;
  const EmployeeManagementPage({super.key, this.initialTab = 0});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RealtimeDatabaseService _db = RealtimeDatabaseService();

  // Single stream for ALL employees — tabs filter from this
  late Stream<List<Employee>> _allEmployeesStream;

  // Track active tab for filtering
  int _currentTab = 0;

// In the _tabs list, add a new tab for Per Dozen
  final List<_TabInfo> _tabs = const [
    _TabInfo(label: 'All', type: null),
    _TabInfo(label: 'Monthly', type: 'monthly'),
    _TabInfo(label: 'Daily', type: 'daily'),
    _TabInfo(label: 'Per Piece', type: 'perpiece'),
    _TabInfo(label: 'Per Dozen', type: 'perdozen'), // New tab
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });

    // One stream, shared across all tabs
    _allEmployeesStream = _db.getEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Filter locally from the single stream ─────────────────
  List<Employee> _filterEmployees(List<Employee> all, String? type) {
    if (type == null) return all;
    return all.where((e) => e.employeeType == type).toList();
  }

  // ─── Add / Edit ─────────────────────────────────────────────
  Future<void> _handleAddOrEdit({Employee? employeeToEdit}) async {
    final result = await Navigator.push<Employee>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmployeePage(employeeToEdit: employeeToEdit),
      ),
    );

    if (result != null) {
      try {
        await _db.saveEmployee(result);
        _showSnack(
          employeeToEdit != null
              ? '${result.name} updated'
              : '${result.name} added',
          color: _C.green,
        );
      } catch (e) {
        _showSnack('Error: $e', color: _C.red);
      }
    }
  }

  // ─── Delete ─────────────────────────────────────────────────
  Future<bool> _confirmDelete(Employee employee) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Employee',
            style: TextStyle(
                color: _C.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete "${employee.name}"? '
              'This will also remove all their production records.',
          style: const TextStyle(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: _C.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ─── Snack ───────────────────────────────────────────────────
  void _showSnack(String msg, {Color color = _C.green}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Container(width: 4, height: 32, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: _C.textPrimary))),
        ]),
        backgroundColor: _C.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.light(primary: _C.blue),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Employees',
        style: TextStyle(
            color: _C.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49),
        child: Column(
          children: [
            Container(height: 1, color: _C.border),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _C.blue,
              unselectedLabelColor: _C.textSecondary,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              indicatorColor: _C.blue,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: _tabs
                  .map((t) => Tab(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(t.label),
                ),
              ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Single StreamBuilder — share data across tabs via filtering
    return StreamBuilder<List<Employee>>(
      stream: _allEmployeesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.blue));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: _C.red, size: 52),
                const SizedBox(height: 12),
                const Text('Error loading employees',
                    style: TextStyle(
                        color: _C.textSecondary, fontSize: 16)),
                const SizedBox(height: 6),
                Text(snapshot.error.toString(),
                    style: const TextStyle(
                        color: _C.textMuted, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final allEmployees = snapshot.data ?? [];

        // TabBarView uses the same data, just filtered per tab
        return TabBarView(
          controller: _tabController,
          children: _tabs
              .map((t) => _EmployeeListView(
            employees: _filterEmployees(allEmployees, t.type),
            onEdit: (e) => _handleAddOrEdit(employeeToEdit: e),
            onDelete: (e) async {
              final confirmed = await _confirmDelete(e);
              if (!confirmed) return;
              try {
                await _db.deleteEmployee(e.id);
                _showSnack('${e.name} deleted', color: _C.red);
                HapticFeedback.mediumImpact();
              } catch (err) {
                _showSnack('Error: $err', color: _C.red);
              }
            },

            onTrackProduction: (e) {
              if (e is PerDozenEmployee) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DozenProductionTrackingPage(employee: e),
                  ),
                );
              } else if (e is PerPieceEmployee) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductionTrackingPage(employee: e),
                  ),
                );
              }
            },
            // onViewRecords: (e) => Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (_) =>
            //         ProductionRecordsPage(employee: e),
            //   ),
            // ),
            onViewRecords: (e) {
              if (e is PerPieceEmployee) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductionRecordsPage(employee: e),
                  ),
                );
              } else if (e is PerDozenEmployee) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DozenProductionRecordsPage(employee: e),
                  ),
                );
              }
            },
            onViewLedger: (e) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmployeeLedgerPage(employee: e),
              ),
            ),
            onTap: (e) => _showEmployeeDetails(e),
          ))
              .toList(),
        );
      },
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () => _handleAddOrEdit(),
      backgroundColor: _C.blue,
      foregroundColor: Colors.white,
      elevation: 2,
      child: const Icon(Icons.person_add_outlined),
    );
  }

  // ─── Employee Detail Dialog ──────────────────────────────────
  void _showEmployeeDetails(Employee employee) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          _avatarCircle(employee, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(employee.name,
                style: const TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Position', employee.position),
              _detailRow('Phone', employee.phone),
              _detailRow('Joining Date',
                  '${employee.joiningDate.day}/${employee.joiningDate.month}/${employee.joiningDate.year}'),
              _detailRow('Type', employee.getTypeDisplay()),
              const Divider(color: _C.border, height: 20),
              if (employee is MonthlyEmployee)
                _detailRow('Monthly Salary',
                    'Rs ${employee.monthlySalary.toStringAsFixed(2)}'),
              if (employee is DailyEmployee) ...[
                _detailRow('Daily Rate',
                    'Rs ${employee.dailyRate.toStringAsFixed(2)}'),
                _detailRow('Days Worked', '${employee.daysWorked}'),
                _detailRow('Total Earnings',
                    'Rs ${employee.totalEarnings.toStringAsFixed(2)}'),
              ],
              if (employee is PerPieceEmployee) ...[
                _detailRow('Rate/Piece',
                    'Rs ${employee.ratePerPiece.toStringAsFixed(2)}'),
                _detailRow('Pieces Completed', '${employee.piecesCompleted}'),
                _detailRow('Total Earnings',
                    'Rs ${employee.totalEarnings.toStringAsFixed(2)}'),
              ],
              if (employee is PerDozenEmployee) ...[ // New block
                _detailRow('Rate/Dozen',
                    'Rs ${employee.ratePerDozen.toStringAsFixed(2)}'),
                _detailRow('Dozens Completed', '${employee.dozensCompleted}'),
                _detailRow('Total Pieces', '${employee.totalPieces}'),
                _detailRow('Total Earnings',
                    'Rs ${employee.totalEarnings.toStringAsFixed(2)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddOrEdit(employeeToEdit: employee);
            },
            child: const Text('Edit',
                style: TextStyle(
                    color: _C.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(
                    color: _C.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: _C.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _avatarCircle(Employee e, {double radius = 22}) {
    final color = _typeColor(e.employeeType);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        e.name[0].toUpperCase(),
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.9),
      ),
    );
  }

  // Update _typeColor method
  Color _typeColor(String type) {
    switch (type) {
      case 'monthly':
        return _C.green;
      case 'daily':
        return _C.amber;
      case 'perpiece':
        return _C.purple;
      case 'perdozen': // New case
        return Colors.teal;
      default:
        return _C.blue;
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Tab info helper
// ─────────────────────────────────────────────────────────────
class _TabInfo {
  final String label;
  final String? type; // null = all
  const _TabInfo({required this.label, required this.type});
}

// ─────────────────────────────────────────────────────────────
//  Employee List View (stateless, receives filtered list)
// ─────────────────────────────────────────────────────────────
class _EmployeeListView extends StatelessWidget {
  final List<Employee> employees;
  final void Function(Employee) onEdit;
  final void Function(Employee) onDelete;
  final void Function(dynamic) onTrackProduction;
  final void Function(dynamic) onViewRecords;
  final void Function(dynamic) onViewLedger;
  final void Function(Employee) onTap;

  const _EmployeeListView({
    required this.employees,
    required this.onEdit,
    required this.onDelete,
    required this.onTrackProduction,
    required this.onViewRecords,
    required this.onViewLedger,
    required this.onTap,
  });

  Color _typeColor(String type) {
    switch (type) {
      case 'monthly':
        return _C.green;
      case 'daily':
        return _C.amber;
      case 'perpiece':
        return _C.purple;
      default:
        return _C.blue;
    }
  }

  String _typeBadge(String type) {
    switch (type) {
      case 'monthly':
        return 'Monthly';
      case 'daily':
        return 'Daily';
      case 'perpiece':
        return 'Per Piece';
      default:
        return type;
    }
  }

  String _subtitleRate(Employee e) {
    if (e is MonthlyEmployee)
      return 'Rs ${e.monthlySalary.toStringAsFixed(0)}/month';
    if (e is DailyEmployee) return 'Rs ${e.dailyRate.toStringAsFixed(0)}/day';
    if (e is PerPieceEmployee)
      return 'Rs ${e.ratePerPiece.toStringAsFixed(2)}/pc · ${e.piecesCompleted} pcs';
    if (e is PerDozenEmployee) // New case
      return 'Rs ${e.ratePerDozen.toStringAsFixed(2)}/doz · ${e.dozensCompleted} doz (${e.totalPieces} pcs)';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: _C.surfaceElevated, shape: BoxShape.circle),
              child: const Icon(Icons.people_outline,
                  size: 36, color: _C.textMuted),
            ),
            const SizedBox(height: 16),
            const Text('No employees found',
                style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('Tap + to add an employee',
                style: TextStyle(color: _C.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        final color = _typeColor(employee.employeeType);

        return Dismissible(
          key: ValueKey(employee.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            // We let the parent handle the full confirm + delete
            onDelete(employee);
            return false; // prevent auto-dismiss; parent handles it
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _C.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text('Delete',
                    style: TextStyle(
                        color: _C.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, color: _C.red, size: 20),
                SizedBox(width: 4),
              ],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(employee),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        employee.name[0].toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(employee.name,
                                  style: const TextStyle(
                                      color: _C.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                            // Type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: color.withOpacity(0.25)),
                              ),
                              child: Text(
                                _typeBadge(employee.employeeType),
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 3),
                          Text(employee.position,
                              style: const TextStyle(
                                  color: _C.textSecondary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(_subtitleRate(employee),
                              style: const TextStyle(
                                  color: _C.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'Courier')),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit
                        _iconBtn(
                          icon: Icons.edit_outlined,
                          color: _C.blue,
                          onTap: () => onEdit(employee),
                          tooltip: 'Edit',
                        ),

                        // Production buttons for Per Piece employees
                        if (employee is PerPieceEmployee) ...[
                          const SizedBox(height: 4),
                          _iconBtn(
                            icon: Icons.add_chart_outlined,
                            color: _C.purple,
                            onTap: () => onTrackProduction(employee),
                            tooltip: 'Track Production (Pieces)',
                          ),
                          const SizedBox(height: 4),
                          _iconBtn(
                            icon: Icons.receipt_long_outlined,
                            color: _C.amber,
                            onTap: () => onViewRecords(employee),
                            tooltip: 'View Records',
                          ),
                          const SizedBox(height: 4),
                          _iconBtn(
                            icon: Icons.account_balance_outlined,
                            color: _C.green,
                            onTap: () => onViewLedger(employee),
                            tooltip: 'Ledger',
                          ),
                        ],

                        // Production buttons for Per Dozen employees
                        if (employee is PerDozenEmployee) ...[
                          const SizedBox(height: 4),
                          _iconBtn(
                            icon: Icons.add_chart_outlined,
                            color: Colors.teal, // Using teal color for Per Dozen
                            onTap: () => onTrackProduction(employee),
                            tooltip: 'Track Production (Dozens)',
                          ),
                          const SizedBox(height: 4),
                          _iconBtn(
                            icon: Icons.receipt_long_outlined,
                            color: _C.amber,
                            onTap: () => onViewRecords(employee),
                            tooltip: 'View Records',
                          ),
                          const SizedBox(height: 4),
                          _iconBtn(
                            icon: Icons.account_balance_outlined,
                            color: _C.green,
                            onTap: () => onViewLedger(employee),
                            tooltip: 'Ledger',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}