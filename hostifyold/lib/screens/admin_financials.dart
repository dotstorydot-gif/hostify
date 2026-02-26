import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostify/providers/property_provider.dart';
import 'package:hostify/providers/expense_provider.dart';
import 'package:hostify/providers/app_state_provider.dart';

class AdminFinancials extends StatefulWidget {
  const AdminFinancials({super.key});

  @override
  State<AdminFinancials> createState() => _AdminFinancialsState();
}

class _AdminFinancialsState extends State<AdminFinancials> {
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  DateTime _selectedMonth = DateTime.now();
  String _dateRangeMode = 'Month'; // 'Month', 'Year', 'YTD', 'All'
  int _selectedYear = DateTime.now().year;
  
  double _revenue = 0;
  int _nights = 0;
  double _managementFeePercent = 15.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final props = context.read<PropertyProvider>().properties;
      final user = context.read<AppStateProvider>().currentUser;
      final isAdmin = user?.role == 'admin';

      if (props.isNotEmpty && _selectedPropertyId == null) {
        setState(() {
          _selectedPropertyId = props.first['id'];
          _selectedPropertyName = props.first['name'];
        });
        _fetchFinancials();
      }
    });
  }

  Future<void> _fetchFinancials() async {
    if (_selectedPropertyId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      DateTime startDate;
      DateTime endDate;
      
      // Calculate date range based on mode
      if (_dateRangeMode == 'Month') {
        startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      } else if (_dateRangeMode == 'Year') {
        startDate = DateTime(_selectedYear, 1, 1);
        endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
      } else if (_dateRangeMode == 'YTD') {
        startDate = DateTime(DateTime.now().year, 1, 1);
        endDate = DateTime.now();
      } else { // 'All'
        startDate = DateTime(2020, 1, 1);
        endDate = DateTime.now().add(const Duration(days: 365));
      }

      // Fetch property details for revenue fallback
      final propertyResp = await Supabase.instance.client
          .from('property-images')
          .select('price_per_night')
          .eq('id', _selectedPropertyId!)
          .maybeSingle();
      final double propertyPrice = (propertyResp?['price_per_night'] as num?)?.toDouble() ?? 150.0;
      final double effectivePrice = propertyPrice > 0 ? propertyPrice : 150.0;

      // Fetch bookings for this property and date range
      final bookingsResponse = await Supabase.instance.client
          .from('bookings')
          .select('total_price, nights, check_in')
          .eq('property_id', _selectedPropertyId!)
          .gte('check_in', startDate.toIso8601String().substring(0, 10))
          .lte('check_in', endDate.toIso8601String().substring(0, 10))
          .filter('status', 'in', '(confirmed,completed,active)');
      
      double totalRevenue = 0;
      int totalNights = 0;
      
      for (final booking in bookingsResponse) {
        final double bPrice = (booking['total_price'] as num?)?.toDouble() ?? 0;
        final int bNights = (booking['nights'] as num?)?.toInt() ?? 0;
        
        if (bPrice > 0) {
           totalRevenue += bPrice;
        } else {
           totalRevenue += (bNights * effectivePrice);
        }
        totalNights += bNights;
      }
      
      // Fetch management fee setting
      final settingsResponse = await Supabase.instance.client
          .from('property_settings')
          .select('management_fee_percentage')
          .eq('property_id', _selectedPropertyId!)
          .maybeSingle();
      
      double feePercent = 15.0;
      if (settingsResponse != null) {
        feePercent = (settingsResponse['management_fee_percentage'] as num?)?.toDouble() ?? 15.0;
      }
      
      // Fetch expenses for this date range
      if (mounted) {
        context.read<ExpenseProvider>().fetchExpenses(
          propertyId: _selectedPropertyId,
          startDate: startDate,
          endDate: endDate,
        );
      }
      
      setState(() {
        _revenue = totalRevenue;
        _nights = totalNights;
        _managementFeePercent = feePercent;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    int pickingYear = _selectedMonth.year;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Month', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                   IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () => setDialogState(() => pickingYear--),
                  ),
                  Text(pickingYear.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                   IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () => setDialogState(() => pickingYear++),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = _selectedMonth.month == month && _selectedMonth.year == pickingYear;
                
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMonth = DateTime(pickingYear, month, 1);
                    });
                    _fetchFinancials();
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(
                        _getMonthName(month).substring(0, 3),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addManualRevenue() async {
    final priceController = TextEditingController();
    final nightsController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Manual Revenue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Revenue Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nightsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nights',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text) ?? 0;
              final nights = int.tryParse(nightsController.text) ?? 1;
              
              if (price > 0) {
                try {
                  await Supabase.instance.client.from('bookings').insert({
                    'property_id': _selectedPropertyId,
                    'check_in': DateTime.now().toIso8601String(),
                    'check_out': DateTime.now().add(Duration(days: nights)).toIso8601String(),
                    'nights': nights,
                    'total_price': price,
                    'status': 'confirmed',
                    'booking_source': 'walk_in',
                    'unit_name': 'Walk-in',
                    'room_number': '1',
                  });
                  
                  Navigator.pop(context);
                  _fetchFinancials();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Revenue added')),
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateManagementFee() async {
    final controller = TextEditingController(text: _managementFeePercent.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Management Fee'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Fee Percentage',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newFee = double.tryParse(controller.text) ?? 15.0;
              
              try {
                // Check if setting exists
                final existing = await Supabase.instance.client
                    .from('property_settings')
                    .select('id')
                    .eq('property_id', _selectedPropertyId!)
                    .maybeSingle();
                
                if (existing != null) {
                  await Supabase.instance.client
                      .from('property_settings')
                      .update({'management_fee_percentage': newFee})
                      .eq('property_id', _selectedPropertyId!);
                } else {
                  await Supabase.instance.client.from('property_settings').insert({
                    'property_id': _selectedPropertyId,
                    'management_fee_percentage': newFee,
                  });
                }
                
                Navigator.pop(context);
                _fetchFinancials();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fee updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Financial Management'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<PropertyProvider>(
        builder: (context, propertyProvider, _) {
          if (propertyProvider.properties.isEmpty) {
            return const Center(child: Text('No properties found'));
          }
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property & Month Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Property:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPropertyId,
                                  isExpanded: true,
                                  items: propertyProvider.properties.map((property) {
                                    return DropdownMenuItem<String>(
                                      value: property['id'],
                                      child: Text(property['name'] ?? 'Unknown'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPropertyId = value;
                                      _selectedPropertyName = propertyProvider.properties
                                          .firstWhere((p) => p['id'] == value)['name'];
                                    });
                                    _fetchFinancials();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Range:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _dateRangeMode,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Month', child: Text('Month')),
                                    DropdownMenuItem(value: 'Year', child: Text('Year')),
                                    DropdownMenuItem(value: 'YTD', child: Text('Year to Date')),
                                    DropdownMenuItem(value: 'All', child: Text('All Time')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _dateRangeMode = value!);
                                    _fetchFinancials();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_dateRangeMode == 'Month')
                        Row(
                          children: [
                            const Text(
                              'Month:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showMonthPicker(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const Icon(Icons.calendar_month, color: Color(0xFFFFD700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_dateRangeMode == 'Year')
                        Row(
                          children: [
                            const Text(
                              'Year:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedYear,
                                    isExpanded: true,
                                    items: List.generate(6, (index) {
                                      final year = DateTime.now().year - 2 + index;
                                      return DropdownMenuItem(value: year, child: Text(year.toString()));
                                    }),
                                    onChanged: (value) {
                                      setState(() => _selectedYear = value!);
                                      _fetchFinancials();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                else
                  Consumer<ExpenseProvider>(
                    builder: (context, expenseProvider, _) {
                      final expenses = expenseProvider.expenses;
                      final totalExpenses = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
                      final managementFee = _revenue * (_managementFeePercent / 100);
                      final landlordShare = _revenue - managementFee;
                      final netProfit = landlordShare - totalExpenses;

                      return Column(
                        children: [
                          // Financial Summary Cards
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEditableCard(
                                        'Revenue',
                                        '\$${_revenue.toStringAsFixed(0)}',
                                        Icons.attach_money,
                                        const Color(0xFFFF6B9D),
                                        _addManualRevenue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Nights',
                                        _nights.toString(),
                                        '',
                                        Icons.nightlight_round,
                                        const Color(0xFFFF9A56),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEditableCard(
                                        'Management Fee',
                                        '\$${managementFee.toStringAsFixed(0)}',
                                        Icons.business_center,
                                        const Color(0xFF9B5DE5),
                                        _updateManagementFee,
                                        subtitle: '${_managementFeePercent.toStringAsFixed(0)}%',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Landlord Share',
                                        '\$${landlordShare.toStringAsFixed(0)}',
                                        'After fee',
                                        Icons.account_balance_wallet,
                                        const Color(0xFF4FC3F7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Total Expenses',
                                        '\$${totalExpenses.toStringAsFixed(0)}',
                                        '${expenses.length} items',
                                        Icons.receipt_long,
                                        const Color(0xFF4ECDC4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Net Profit',
                                        '\$${netProfit.toStringAsFixed(0)}',
                                        netProfit >= 0 ? 'Profit' : 'Loss',
                                        Icons.trending_up,
                                        netProfit >= 0 ? const Color(0xFF44A08D) : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Expenses Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Expenses',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _addExpense(expenseProvider),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Expense'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Expenses List
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: expenses.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                                          const SizedBox(height: 8),
                                          Text('No expenses yet', style: TextStyle(color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: expenses.length,
                                    itemBuilder: (context, index) {
                                      final expense = expenses[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.receipt, color: Colors.red),
                                          ),
                                          title: Text(
                                            expense['category'],
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text(expense['expense_date'] ?? ''),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '\$${(expense['amount'] as num).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              PopupMenuButton(
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                                ],
                                                onSelected: (value) async {
                                                  if (value == 'delete') {
                                                    await expenseProvider.deleteExpense(expense['id']);
                                                    _fetchFinancials();
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addExpense(ExpenseProvider provider) {
    final amountController = TextEditingController();
    String category = 'cleaning';
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cleaning', child: Text('Cleaning')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'utilities', child: Text('Utilities')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setDialogState(() => category = value!);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && _selectedPropertyId != null) {
                  await provider.addExpense(
                    propertyId: _selectedPropertyId!,
                    amount: amount,
                    category: category,
                    description: descriptionController.text,
                    expenseDate: DateTime.now(),
                  );
                  Navigator.pop(context);
                  _fetchFinancials();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCard(String label, String value, IconData icon, Color color, VoidCallback onEdit, {String? subtitle}) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
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
                Icon(icon, color: Colors.white, size: 24),
                const Icon(Icons.edit, color: Colors.white, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
