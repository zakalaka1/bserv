import 'package:flutter/material.dart';

import '../../data/appointments/appointment_repository.dart';
import '../../features/service_area/service_area_map.dart';
import '../../l10n/app_localizations.dart';
import '../../app/app_config.dart';

enum _BookingTimeSlot { morning, midday, afternoon, evening }

class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({
    super.key,
    required this.serviceArea,
    required this.bookedSlots,
    this.initialDate,
    this.initialTimeSlot,
    required this.onBack,
    required this.onContinue,
  });

  final ServiceArea serviceArea;

  /// Slots already booked by customers or blocked off by the admin.
  final Stream<List<BookedSlot>> bookedSlots;
  final DateTime? initialDate;
  final String? initialTimeSlot;
  final VoidCallback onBack;
  final void Function(DateTime date, String timeSlot) onContinue;

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  DateTime? _selectedDate;
  _BookingTimeSlot? _selectedTimeSlot;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    for (final slot in _BookingTimeSlot.values) {
      if (slot.name == widget.initialTimeSlot) {
        _selectedTimeSlot = slot;
        break;
      }
    }
  }

  bool _isAvailable(DateTime date) =>
      BookingSchedule.isBookableDate(DateUtils.dateOnly(date), today: _today);

  // Slot labels are what customers and the admin store in timeSlot.
  bool _isTimeSlotAvailable(
    AppLocalizations localizations,
    Set<String> takenLabels,
    _BookingTimeSlot slot,
  ) => !takenLabels.contains(_timeSlotLabel(localizations, slot));

  String _timeSlotLabel(AppLocalizations localizations, _BookingTimeSlot slot) {
    return switch (slot) {
      _BookingTimeSlot.morning => localizations.timeSlotMorning,
      _BookingTimeSlot.midday => localizations.timeSlotMidday,
      _BookingTimeSlot.afternoon => localizations.timeSlotAfternoon,
      _BookingTimeSlot.evening => localizations.timeSlotEvening,
    };
  }

  void _continue() {
    final selectedDate = _selectedDate;
    final selectedTimeSlot = _selectedTimeSlot;
    if (selectedDate == null || selectedTimeSlot == null) return;

    final localizations = AppLocalizations.of(context)!;
    widget.onContinue(
      selectedDate,
      _timeSlotLabel(localizations, selectedTimeSlot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BookedSlot>>(
      stream: widget.bookedSlots,
      builder: (context, snapshot) {
        final selectedDate = _selectedDate;
        final takenLabels = <String>{
          for (final slot in snapshot.data ?? const <BookedSlot>[])
            if (selectedDate != null &&
                DateUtils.isSameDay(slot.date, selectedDate))
              slot.timeSlot,
        };
        return _buildContent(context, takenLabels);
      },
    );
  }

  Widget _buildContent(BuildContext context, Set<String> takenLabels) {
    final localizations = AppLocalizations.of(context)!;
    final selectedDate = _selectedDate;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.chooseAppointmentDateAndTime,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  localizations.serviceAreaForBooking(
                    widget.serviceArea.name(localizations),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('change-service-area'),
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(localizations.changeServiceArea),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: CalendarDatePicker(
                      key: const ValueKey('booking-calendar'),
                      initialDate:
                          selectedDate ??
                          BookingSchedule.firstBookableDate(_today),
                      firstDate: _today,
                      lastDate: BookingSchedule.lastBookableDate(_today),
                      currentDate: _today,
                      selectableDayPredicate: _isAvailable,
                      onDateChanged: (date) => setState(() {
                        if (_selectedDate != date) {
                          _selectedTimeSlot = null;
                        }
                        _selectedDate = date;
                      }),
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: RadioGroup<_BookingTimeSlot>(
                      groupValue: _selectedTimeSlot,
                      onChanged: (slot) =>
                          setState(() => _selectedTimeSlot = slot),
                      child: Column(
                        children: [
                          for (final slot in _BookingTimeSlot.values)
                            RadioListTile<_BookingTimeSlot>(
                              key: ValueKey('booking-slot-${slot.name}'),
                              value: slot,
                              enabled:
                                  selectedDate != null &&
                                  _isTimeSlotAvailable(
                                    localizations,
                                    takenLabels,
                                    slot,
                                  ),
                              title: Text(_timeSlotLabel(localizations, slot)),
                              subtitle: selectedDate == null
                                  ? Text(localizations.selectDateForTimes)
                                  : !_isTimeSlotAvailable(
                                      localizations,
                                      takenLabels,
                                      slot,
                                    )
                                  ? Text(localizations.timeSlotUnavailable)
                                  : null,
                              contentPadding: const EdgeInsetsDirectional.only(
                                start: 16,
                                end: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('continue-selected-slot'),
                  onPressed:
                      selectedDate != null &&
                          _selectedTimeSlot != null &&
                          _isTimeSlotAvailable(
                            localizations,
                            takenLabels,
                            _selectedTimeSlot!,
                          )
                      ? _continue
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(localizations.continueBooking),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
