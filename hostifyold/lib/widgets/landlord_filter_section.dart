import 'package:hostify/providers/property_provider.dart';
import 'package:hostify/core/theme/app_colors.dart';

class LandlordFilterSection extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(DateTime start, DateTime end, String? propertyId, String label) onFilterChanged;
  
  // Optional initial values if we want to restore state
  final String? initialPropertyId;
  final String? initialRangeMode;
  final int? initialYear;
  final DateTime? initialMonth;

  const LandlordFilterSection({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.onFilterChanged,
    this.initialPropertyId,
    this.initialRangeMode,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<LandlordFilterSection> createState() => _LandlordFilterSectionState();
}

class _LandlordFilterSectionState extends State<LandlordFilterSection> {
  late String? _selectedPropertyId;
  late String _rangeMode;
  late int _selectedYear;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    _selectedPropertyId = widget.initialPropertyId;
    _rangeMode = widget.initialRangeMode ?? 'Year';
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _selectedMonth = widget.initialMonth ?? DateTime.now();
    
    // If not provided, try to infer from Provider if logic allows?
    // For now, parent ensures correct init.
  }

  // Trigger update
  void _notifyChanged() {
    DateTime start, end;
    String label;
    final now = DateTime.now();

    if (_rangeMode == 'Year') {
      start = DateTime(_selectedYear, 1, 1);
      end = DateTime(_selectedYear, 12, 31);
      label = '$_selectedYear';
    } else if (_rangeMode == 'Month') {
      start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      label = DateFormat('MMM yyyy').format(_selectedMonth);
    } else { // YTD
      start = DateTime(now.year, 1, 1);
      end = now;
      label = 'YTD';
    }

    widget.onFilterChanged(start, end, _selectedPropertyId, label);
  }

  Future<void> _showMonthPicker() async {
    // We need state inside the dialog to update the year view
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setStateDialog(() => _selectedYear--);
                    },
                  ),
                  Text("$_selectedYear"),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setStateDialog(() => _selectedYear++);
                    },
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
                    final date = DateTime(_selectedYear, index + 1);
                    final isSelected = _selectedMonth.year == _selectedYear && _selectedMonth.month == index + 1;
                    return InkWell(
                      onTap: () {
                        // Update parent state
                        setState(() {
                          _selectedYear = date.year; // Ensure parent year matches dialog year
                          _selectedMonth = date;
                        });
                        Navigator.pop(context);
                        _notifyChanged(); // Notify after selection
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.yellow : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                                ? Colors.white 
                                : AppColors.darkGrey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isExpanded) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
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
                const Text('Filter Data', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.yellow, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: widget.onToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Property
            Row(children: [
               const SizedBox(width: 80, child: Text('Property:', style: TextStyle(fontWeight: FontWeight.w600))),
               Expanded(
                 child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedPropertyId,
                        isExpanded: true,
                        hint: const Text('All Properties'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Properties', style: TextStyle(fontSize: 14))),
                          ...context.read<PropertyProvider>().properties.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name'] ?? 'Unknown', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPropertyId = val);
                          _notifyChanged();
                        },
                      ),
                    ),
                 ),
               ),
            ]),
            const SizedBox(height: 8),
            // Range
            Row(children: [
               const SizedBox(width: 80, child: Text('Range:', style: TextStyle(fontWeight: FontWeight.w600))),
               Expanded(
                 child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _rangeMode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'Year', child: Text('Year')),
                          DropdownMenuItem(value: 'Month', child: Text('Month')),
                          DropdownMenuItem(value: 'YTD', child: Text('Year to Date')),
                        ],
                        onChanged: (val) {
                          setState(() => _rangeMode = val!);
                          _notifyChanged();
                        },
                      ),
                    ),
                 ),
               ),
            ]),
            const SizedBox(height: 8),
            // Year or Month
             if (_rangeMode == 'Year')
               Row(children: [
                 const SizedBox(width: 80, child: Text('Year:', style: TextStyle(fontWeight: FontWeight.w600))),
                 Expanded(
                   child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isExpanded: true,
                          items: [2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                          onChanged: (val) {
                              setState(() => _selectedYear = val!);
                              _notifyChanged();
                          },
                        ),
                      ),
                   ),
                 ),
               ]),
             if (_rangeMode == 'Month')
               Row(children: [
                 const SizedBox(width: 80, child: Text('Month:', style: TextStyle(fontWeight: FontWeight.w600))),
                 Expanded(
                   child: InkWell(
                     onTap: _showMonthPicker,
                     child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                            const Icon(Icons.calendar_month, size: 20),
                          ],
                        ),
                     ),
                   ),
                 ),
               ]),
         ],
      ),
    );
  }
}
