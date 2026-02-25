import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/employee_models.dart';

class AddEmployeePage extends StatefulWidget {
  final Employee? employeeToEdit;

  const AddEmployeePage({super.key, this.employeeToEdit});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();

  // Common controllers for all employee types
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();

  // Type-specific controllers
  final _monthlySalaryController = TextEditingController();
  final _dailyRateController = TextEditingController();
  final _perPieceRateController = TextEditingController();

  String _employeeType = 'Monthly';
  DateTime _joiningDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isEditing = false;

  List<String> get _employeeTypes => ['Monthly', 'Daily', 'Per Piece'];

  @override
  void initState() {
    super.initState();
    if (widget.employeeToEdit != null) {
      _isEditing = true;
      _loadEmployeeData();
    }
  }

  void _loadEmployeeData() {
    final employee = widget.employeeToEdit!;

    _nameController.text = employee.name;
    _phoneController.text = employee.phone;
    _positionController.text = employee.position;
    _joiningDate = employee.joiningDate;
    _employeeType = employee.getTypeDisplay();

    if (employee is MonthlyEmployee) {
      _monthlySalaryController.text = employee.monthlySalary.toString();
    } else if (employee is DailyEmployee) {
      _dailyRateController.text = employee.dailyRate.toString();
    } else if (employee is PerPieceEmployee) {
      _perPieceRateController.text = employee.ratePerPiece.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add Employee'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Type Selection
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Employee Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      IgnorePointer(
                        ignoring: _isEditing,
                        child: Opacity(
                          opacity: _isEditing ? 0.6 : 1.0,
                          child: SegmentedButton<String>(
                            segments: _employeeTypes.map((type) {
                              return ButtonSegment<String>(
                                value: type,
                                label: Text(type),
                                icon: Icon(_getTypeIcon(type)),
                              );
                            }).toList(),
                            selected: {_employeeType},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _employeeType = newSelection.first;
                                _clearTypeSpecificControllers();
                              });
                            },
                          ),
                        ),
                      ),
                      if (_isEditing)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Employee type cannot be changed after creation',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Personal Information
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _positionController,
                        decoration: const InputDecoration(
                          labelText: 'Position *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter position';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Joining Date *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _dateFormat.format(_joiningDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payment Details
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Details (${_employeeType})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_employeeType == 'Monthly')
                        _buildMonthlyFields(),
                      if (_employeeType == 'Daily')
                        _buildDailyFields(),
                      if (_employeeType == 'Per Piece')
                        _buildPerPieceFields(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update Employee' : 'Add Employee',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyFields() {
    return Column(
      children: [
        TextFormField(
          controller: _monthlySalaryController,
          decoration: const InputDecoration(
            labelText: 'Monthly Salary *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            hintText: 'Enter monthly salary amount',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter monthly salary';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(value) <= 0) {
              return 'Salary must be greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDailyFields() {
    return Column(
      children: [
        TextFormField(
          controller: _dailyRateController,
          decoration: const InputDecoration(
            labelText: 'Daily Rate *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            hintText: 'Enter rate per day',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter daily rate';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(value) <= 0) {
              return 'Daily rate must be greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPerPieceFields() {
    return Column(
      children: [
        TextFormField(
          controller: _perPieceRateController,
          decoration: const InputDecoration(
            labelText: 'Rate per Piece *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            hintText: 'Enter rate per piece',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter rate per piece';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(value) <= 0) {
              return 'Rate per piece must be greater than 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Monthly':
        return Icons.calendar_month;
      case 'Daily':
        return Icons.today;
      case 'Per Piece':
        return Icons.build;
      default:
        return Icons.person;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _joiningDate) {
      setState(() {
        _joiningDate = picked;
      });
    }
  }

  void _clearTypeSpecificControllers() {
    _monthlySalaryController.clear();
    _dailyRateController.clear();
    _perPieceRateController.clear();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final id = _isEditing
          ? widget.employeeToEdit!.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      Employee employee;

      try {
        switch (_employeeType) {
          case 'Monthly':
            employee = MonthlyEmployee(
              id: id,
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              position: _positionController.text.trim(),
              joiningDate: _joiningDate,
              monthlySalary: double.parse(_monthlySalaryController.text),
            );
            break;

          case 'Daily':
            int daysWorked = 0;
            if (_isEditing && widget.employeeToEdit is DailyEmployee) {
              daysWorked = (widget.employeeToEdit as DailyEmployee).daysWorked;
            }
            employee = DailyEmployee(
              id: id,
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              position: _positionController.text.trim(),
              joiningDate: _joiningDate,
              dailyRate: double.parse(_dailyRateController.text),
              daysWorked: daysWorked,
            );
            break;

          case 'Per Piece':
            int piecesCompleted = 0;
            if (_isEditing && widget.employeeToEdit is PerPieceEmployee) {
              piecesCompleted = (widget.employeeToEdit as PerPieceEmployee).piecesCompleted;
            }
            employee = PerPieceEmployee(
              id: id,
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              position: _positionController.text.trim(),
              joiningDate: _joiningDate,
              ratePerPiece: double.parse(_perPieceRateController.text),
              piecesCompleted: piecesCompleted,
            );
            break;

          default:
            return;
        }

        Navigator.pop(context, employee);
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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _monthlySalaryController.dispose();
    _dailyRateController.dispose();
    _perPieceRateController.dispose();
    super.dispose();
  }
}