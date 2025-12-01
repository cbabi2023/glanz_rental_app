import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Order Date Time Widget
/// 
/// Allows selecting rental start and end dates/times
class OrderDateTimeWidget extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?) onStartDateChanged;
  final Function(DateTime?) onEndDateChanged;

  const OrderDateTimeWidget({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime?) onDateSelected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    DateTime? initialDateTime,
    Function(DateTime?) onDateTimeSelected,
  ) async {
    final initialTime = initialDateTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );
    if (picked != null) {
      final newDateTime = DateTime(
        initialTime.year,
        initialTime.month,
        initialTime.day,
        picked.hour,
        picked.minute,
      );
      onDateTimeSelected(newDateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rental Dates & Times',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Start Date/Time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Date *'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(
                      context,
                      startDate,
                      (date) {
                        if (date != null) {
                          final time = startDate ?? DateTime.now();
                          onStartDateChanged(DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ));
                        }
                      },
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startDate != null
                                ? DateFormat('dd MMM yyyy').format(startDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: startDate != null
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Time'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectTime(
                      context,
                      startDate,
                      onStartDateChanged,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startDate != null
                                ? DateFormat('HH:mm').format(startDate!)
                                : 'Select time',
                            style: TextStyle(
                              color: startDate != null
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const Icon(Icons.access_time, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // End Date/Time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Date *'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(
                      context,
                      endDate,
                      (date) {
                        if (date != null) {
                          final time = endDate ?? DateTime.now();
                          onEndDateChanged(DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ));
                        }
                      },
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            endDate != null
                                ? DateFormat('dd MMM yyyy').format(endDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: endDate != null
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Time'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectTime(
                      context,
                      endDate,
                      onEndDateChanged,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            endDate != null
                                ? DateFormat('HH:mm').format(endDate!)
                                : 'Select time',
                            style: TextStyle(
                              color: endDate != null
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const Icon(Icons.access_time, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

