import 'package:flutter/material.dart';

import '../../data/appointments/appointment_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../app/app_config.dart';

enum _BlockoffTimeSlot { morning, midday, afternoon, evening }

class BlockoffTimeScreen extends StatefulWidget {
  const BlockoffTimeScreen({
    super.key,
    required this.blockedOffTimes,
    required this.bookedSlots,
    required this.onSave,
  });

  /// Currently blocked-off slots, used to pre-check the boxes.
  final Stream<List<BlockedOffTime>> blockedOffTimes;

  /// All unavailable slots; those not blocked off belong to customers.
  final Stream<List<BookedSlot>> bookedSlots;

  /// Receives only the changes: slots to newly block and slots to unblock.
  final Future<void> Function(
    DateTime date,
    Set<String> block,
    Set<String> unblock,
  )
  onSave;

  @override
  State<BlockoffTimeScreen> createState() => _BlockoffTimeScreenState();
}

class _BlockoffTimeScreenState extends State<BlockoffTimeScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  DateTime? _selectedDate;
  // Null until the admin edits; then the checkboxes show these instead of the saved state.
  Set<String>? _editedSlots;
  Set<String> _savedSlotsForDate = {};
  bool _saving = false;

  bool _isSelectableDate(DateTime date) =>
      BookingSchedule.isWorkingDate(DateUtils.dateOnly(date), today: _today);

  String _slotLabel(
    AppLocalizations localizations,
    _BlockoffTimeSlot timeSlot,
  ) {
    return switch (timeSlot) {
      _BlockoffTimeSlot.morning => localizations.timeSlotMorning,
      _BlockoffTimeSlot.midday => localizations.timeSlotMidday,
      _BlockoffTimeSlot.afternoon => localizations.timeSlotAfternoon,
      _BlockoffTimeSlot.evening => localizations.timeSlotEvening,
    };
  }

  Future<void> _save() async {
    final date = _selectedDate;
    final edited = _editedSlots;
    if (date == null || edited == null || _saving) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(
        date,
        edited.difference(_savedSlotsForDate),
        _savedSlotsForDate.difference(edited),
      );
      if (mounted) _editedSlots = null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final selectedDate = _selectedDate;

    return StreamBuilder<List<BlockedOffTime>>(
      stream: widget.blockedOffTimes,
      builder: (context, snapshot) {
        final blocked = snapshot.data ?? const <BlockedOffTime>[];
        _savedSlotsForDate = {
          for (final entry in blocked)
            if (selectedDate != null &&
                DateUtils.isSameDay(entry.date, selectedDate))
              entry.timeSlot,
        };
        final selectedSlots = _editedSlots ?? _savedSlotsForDate;
        final hasChanges =
            selectedDate != null &&
            !(selectedSlots.length == _savedSlotsForDate.length &&
                selectedSlots.containsAll(_savedSlotsForDate));

        return StreamBuilder<List<BookedSlot>>(
          stream: widget.bookedSlots,
          builder: (context, bookedSnapshot) {
            // Booked but not blocked off means a customer holds the slot.
            final customerBooked = <String>{
              for (final slot in bookedSnapshot.data ?? const <BookedSlot>[])
                if (selectedDate != null &&
                    DateUtils.isSameDay(slot.date, selectedDate) &&
                    !_savedSlotsForDate.contains(slot.timeSlot))
                  slot.timeSlot,
            };
            return _buildContent(
              context,
              localizations,
              selectedDate,
              selectedSlots,
              customerBooked,
              hasChanges,
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations localizations,
    DateTime? selectedDate,
    Set<String> selectedSlots,
    Set<String> customerBooked,
    bool hasChanges,
  ) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: CalendarDatePicker(
                      key: const ValueKey('blockoff-calendar'),
                      initialDate:
                          selectedDate ??
                          BookingSchedule.firstWorkingDate(_today),
                      firstDate: _today,
                      lastDate: BookingSchedule.lastBookableDate(_today),
                      currentDate: _today,
                      selectableDayPredicate: _isSelectableDate,
                      onDateChanged: (date) => setState(() {
                        _selectedDate = date;
                        _editedSlots = null;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            16,
                            12,
                            16,
                            4,
                          ),
                          child: Text(
                            localizations.selectTimeSlotsToBlock,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        for (final timeSlot in _BlockoffTimeSlot.values)
                          CheckboxListTile(
                            key: ValueKey('blockoff-slot-${timeSlot.name}'),
                            value: selectedSlots.contains(
                              _slotLabel(localizations, timeSlot),
                            ),
                            onChanged:
                                selectedDate == null ||
                                    _saving ||
                                    customerBooked.contains(
                                      _slotLabel(localizations, timeSlot),
                                    )
                                ? null
                                : (selected) => setState(() {
                                    // Same label text customers store in timeSlot.
                                    final label = _slotLabel(
                                      localizations,
                                      timeSlot,
                                    );
                                    final next = {...selectedSlots};
                                    if (selected ?? false) {
                                      next.add(label);
                                    } else {
                                      next.remove(label);
                                    }
                                    _editedSlots = next;
                                  }),
                            title: Text(_slotLabel(localizations, timeSlot)),
                            subtitle: selectedDate == null
                                ? Text(localizations.selectDateToBlock)
                                : customerBooked.contains(
                                    _slotLabel(localizations, timeSlot),
                                  )
                                ? Text(localizations.timeSlotBookedByCustomer)
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
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('block-selected-times'),
                  onPressed: hasChanges && !_saving ? _save : null,
                  icon: const Icon(Icons.event_busy_outlined),
                  label: Text(localizations.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
