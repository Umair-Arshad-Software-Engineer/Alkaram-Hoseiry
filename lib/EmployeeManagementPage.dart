import 'package:alkaram_hosiery/services/employee_services.dart';
import 'package:flutter/material.dart';
import 'AddEmployeePage.dart';
import 'models/employee_models.dart';
import 'production_tracking_page.dart';

class EmployeeManagementPage extends StatefulWidget {
  final int initialTab;

  const EmployeeManagementPage({super.key, this.initialTab = 0});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<Employee>> _getFilteredEmployeesStream(int tabIndex) {
    switch (tabIndex) {
      case 0: // All
        return _databaseService.getEmployees();
      case 1: // Monthly
        return _databaseService.getEmployeesByType('monthly');
      case 2: // Daily
        return _databaseService.getEmployeesByType('daily');
      case 3: // Per Piece
        return _databaseService.getEmployeesByType('perpiece');
      default:
        return _databaseService.getEmployees();
    }
  }

  Future<void> _handleAddOrEditEmployee({Employee? employeeToEdit}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmployeePage(
          employeeToEdit: employeeToEdit,
        ),
      ),
    );

    if (result != null && result is Employee) {
      try {
        await _databaseService.saveEmployee(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                employeeToEdit != null
                    ? 'Employee updated successfully'
                    : 'Employee added successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Employees'),
            Tab(text: 'Monthly'),
            Tab(text: 'Daily'),
            Tab(text: 'Per Piece'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmployeeList(0),
          _buildEmployeeList(1),
          _buildEmployeeList(2),
          _buildEmployeeList(3),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddOrEditEmployee(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmployeeList(int tabIndex) {
    return StreamBuilder<List<Employee>>(
      stream: _getFilteredEmployeesStream(tabIndex),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading employees',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final employees = snapshot.data ?? [];

        if (employees.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No employees found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to add an employee',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return Dismissible(
              key: Key(employee.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Employee'),
                    content: Text('Are you sure you want to delete ${employee.name}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) async {
                try {
                  await _databaseService.deleteEmployee(employee.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${employee.name} deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting employee: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: employee.getTypeColor().withOpacity(0.2),
                    child: Text(
                      employee.name[0].toUpperCase(),
                      style: TextStyle(
                        color: employee.getTypeColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Position: ${employee.position}'),
                      Text('Phone: ${employee.phone}'),
                      if (employee is MonthlyEmployee)
                        Text('Monthly Salary: ${employee.monthlySalary}'),
                      if (employee is DailyEmployee)
                        Text('Daily Rate: ${employee.dailyRate} | Days: ${employee.daysWorked}'),
                      if (employee is PerPieceEmployee)
                        Text('Rate/Piece: ${employee.ratePerPiece} | Pieces: ${employee.piecesCompleted}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (employee is PerPieceEmployee)
                        IconButton(
                          icon: const Icon(Icons.build_circle, color: Colors.purple),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductionTrackingPage(
                                  employee: employee,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Track Production',
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: employee.getTypeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          employee.getTypeDisplay(),
                          style: TextStyle(
                            color: employee.getTypeColor(),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    _showEmployeeDetails(employee);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmployeeDetails(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Position', employee.position),
              _buildDetailRow('Phone', employee.phone),
              _buildDetailRow('Joining Date',
                  '${employee.joiningDate.day}/${employee.joiningDate.month}/${employee.joiningDate.year}'),
              _buildDetailRow('Employee Type', employee.getTypeDisplay()),
              const Divider(),
              if (employee is MonthlyEmployee) ...[
                _buildDetailRow('Monthly Salary', '${employee.monthlySalary}'),
              ],
              if (employee is DailyEmployee) ...[
                _buildDetailRow('Daily Rate', '${employee.dailyRate}'),
                _buildDetailRow('Days Worked', '${employee.daysWorked}'),
                _buildDetailRow('Total Earnings', '${employee.totalEarnings}'),
              ],
              if (employee is PerPieceEmployee) ...[
                _buildDetailRow('Rate per Piece', '${employee.ratePerPiece}'),
                _buildDetailRow('Pieces Completed', '${employee.piecesCompleted}'),
                _buildDetailRow('Total Earnings', '${employee.totalEarnings}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddOrEditEmployee(employeeToEdit: employee);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}