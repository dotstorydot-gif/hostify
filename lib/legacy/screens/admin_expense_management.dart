import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/expense_provider.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:intl/intl.dart';

class AdminExpenseManagement extends StatefulWidget {
  const AdminExpenseManagement({super.key});

  @override
  State<AdminExpenseManagement> createState() => _AdminExpenseManagementState();
}

class _AdminExpenseManagementState extends State<AdminExpenseManagement> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedPropertyId;
  String _selectedCategory = 'cleaning';
  DateTime _selectedDate = DateTime.now();
  
  List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _loadExpenses();
  }

  Future<void> _loadProperties() async {
    final user = context.read<AppStateProvider>().currentUser;
    if (user != null) {
      await context.read<PropertyProvider>().fetchLandlordProperties(user.id);
      setState(() {
        _properties = context.read<PropertyProvider>().properties;
        if (_properties.isNotEmpty) {
          _selectedPropertyId = _properties.first['id'];
        }
      });
    }
  }

  Future<void> _loadExpenses() async {
    await context.read<ExpenseProvider>().fetchExpenses();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFF000000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Expense Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add Expense Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Expense',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Property Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedPropertyId,
                            isExpanded: true, // Fix horizontal overflow
                            decoration: const InputDecoration(
                              labelText: 'Property',
                              border: OutlineInputBorder(),
                            ),
                            items: _properties.map((property) {
                              return DropdownMenuItem<String>(
                                value: property['id'],
                                child: Text(
                                  property['name'] ?? 'Unknown',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPropertyId = value);
                            },
                            validator: (value) {
                              if (value == null) return 'Please select a property';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: ExpenseProvider.categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  _capitalizeCategory(category),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedCategory = value!);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount Field
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Amount (USD)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Date Picker
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: const Color(0xFFFFD700),
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFFFFD700),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Expense Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description Field
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description/Comment (Optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submitExpense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add Expense',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Expenses List
                  const Text(
                    'Recent Expenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Consumer<ExpenseProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.expenses.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No expenses yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.expenses.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(provider.expenses[index]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final categoryColor = _getCategoryColor(expense['category']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(_getCategoryIcon(expense['category']), color: categoryColor),
          ),
        ),
        title: Text(
          _capitalizeCategory(expense['category']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense['property']?['name'] ?? 'Unknown Property'),
            if (expense['description'] != null && expense['description'].isNotEmpty)
              Text(
                expense['description'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Text(
              DateFormat('MMM dd, yyyy').format(DateTime.parse(expense['expense_date'])),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${expense['amount']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteExpense(expense['id']),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitExpense() async {
    if (_formKey.currentState!.validate()) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()),
        );

        await context.read<ExpenseProvider>().addExpense(
          propertyId: _selectedPropertyId!,
          amount: double.parse(_amountController.text),
          category: _selectedCategory,
          expenseDate: _selectedDate,
          description: _descriptionController.text.isEmpty 
              ? null 
              : _descriptionController.text,
        );

        if (mounted) Navigator.pop(context); // Close loading

        // Reset form
        _amountController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedDate = DateTime.now();
          _selectedCategory = 'cleaning';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully')),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context); // Close loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<ExpenseProvider>().deleteExpense(expenseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _capitalizeCategory(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'cleaning': return Colors.blue;
      case 'maintenance': return Colors.orange;
      case 'problem': return Colors.red;
      case 'enhancement': return Colors.green;
      case 'plumbing': return Colors.purple;
      case 'electricity': return Colors.amber;
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'cleaning': return Icons.cleaning_services;
      case 'maintenance': return Icons.build;
      case 'problem': return Icons.warning;
      case 'enhancement': return Icons.upgrade;
      case 'plumbing': return Icons.plumbing;
      case 'electricity': return Icons.electrical_services;
      case 'door': return Icons.door_front_door;
      case 'floor': return Icons.layers;
      case 'wall': return Icons.square;
      case 'decoration': return Icons.palette;
      case 'room': return Icons.bed;
      default: return Icons.receipt;
    }
  }
}
