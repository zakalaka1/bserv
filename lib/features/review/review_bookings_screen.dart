import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../data/appointments/appointment_repository.dart';
import '../../l10n/app_localizations.dart';

/// The four bookable times of a working day, in display order.
enum _ReviewTimeSlot { morning, midday, afternoon, evening }

/// Admin-only overview of one day's bookings.
///
/// The layout mirrors `BlockoffTimeScreen`: a calendar plus one row per time
/// slot. Slots held by a customer offer the standard Material 3 "Details"
/// button; blocked-off slots are labelled but not actionable, and free slots
/// show only their time.
class ReviewBookingsScreen extends StatefulWidget {
  const ReviewBookingsScreen({
    super.key,
    required this.blockedOffTimes,
    required this.bookedSlots,
    required this.onOpenDetails,
    required this.isLeftHanded,
    this.initialDate,
  });

  /// Slots the admin has closed for a date.
  final Stream<List<BlockedOffTime>> blockedOffTimes;

  /// All unavailable slots; those not blocked off belong to customers.
  final Stream<List<BookedSlot>> bookedSlots;

  /// Opens the review details for one customer booking.
  final void Function(DateTime date, String timeSlot) onOpenDetails;

  /// Mirrors each slot row so the Details button moves to the leading edge
  /// and the hour label to the trailing edge, keeping the actionable control
  /// under a left thumb.
  final bool isLeftHanded;

  /// The day to open on; defaults to today. The overview is often reopened
  /// after the details screen, which hands back the day last reviewed.
  final DateTime? initialDate;

  @override
  State<ReviewBookingsScreen> createState() => _ReviewBookingsScreenState();
}

class _ReviewBookingsScreenState extends State<ReviewBookingsScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());

  /// Never null: the overview loads today's bookings as soon as it opens.
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Today, or the closest selectable day to the previously reviewed date.
    _selectedDate = _nearestSelectableDate(widget.initialDate ?? _today);
  }

  bool _isSelectableDate(DateTime date) =>
      BookingSchedule.isWorkingDate(DateUtils.dateOnly(date), today: _today);

  /// Clamps [date] into the calendar's range and moves it to the nearest
  /// selectable working day, so the initial date is always valid.
  DateTime _nearestSelectableDate(DateTime date) {
    final last = BookingSchedule.lastBookableDate(_today);
    var day = DateUtils.dateOnly(date);
    if (day.isBefore(_today)) day = _today;
    if (day.isAfter(last)) day = last;

    for (var offset = 0; offset <= 6; offset++) {
      final candidate = DateUtils.addDaysToDate(day, offset);
      if (candidate.isAfter(last)) break;
      if (_isSelectableDate(candidate)) return candidate;
    }
    for (var offset = 1; offset <= 6; offset++) {
      final candidate = DateUtils.addDaysToDate(day, -offset);
      if (candidate.isBefore(_today)) break;
      if (_isSelectableDate(candidate)) return candidate;
    }
    return BookingSchedule.firstWorkingDate(_today);
  }

  String _slotLabel(AppLocalizations localizations, _ReviewTimeSlot timeSlot) {
    return switch (timeSlot) {
      _ReviewTimeSlot.morning => localizations.timeSlotMorning,
      _ReviewTimeSlot.midday => localizations.timeSlotMidday,
      _ReviewTimeSlot.afternoon => localizations.timeSlotAfternoon,
      _ReviewTimeSlot.evening => localizations.timeSlotEvening,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<BlockedOffTime>>(
      stream: widget.blockedOffTimes,
      builder: (context, blockedSnapshot) {
        final blockedSlots = {
          for (final entry in blockedSnapshot.data ?? const <BlockedOffTime>[])
            if (DateUtils.isSameDay(entry.date, _selectedDate)) entry.timeSlot,
        };

        return StreamBuilder<List<BookedSlot>>(
          stream: widget.bookedSlots,
          builder: (context, bookedSnapshot) {
            // Booked but not blocked off means a customer holds the slot.
            final customerBooked = {
              for (final slot in bookedSnapshot.data ?? const <BookedSlot>[])
                if (DateUtils.isSameDay(slot.date, _selectedDate) &&
                    !blockedSlots.contains(slot.timeSlot))
                  slot.timeSlot,
            };

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
                              key: const ValueKey('review-calendar'),
                              initialDate: _selectedDate,
                              firstDate: _today,
                              lastDate: BookingSchedule.lastBookableDate(
                                _today,
                              ),
                              currentDate: _today,
                              selectableDayPredicate: _isSelectableDate,
                              onDateChanged: (date) =>
                                  setState(() => _selectedDate = date),
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
                                for (final timeSlot in _ReviewTimeSlot.values)
                                  _buildSlotRow(
                                    localizations,
                                    timeSlot,
                                    blockedSlots,
                                    customerBooked,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSlotRow(
    AppLocalizations localizations,
    _ReviewTimeSlot timeSlot,
    Set<String> blockedSlots,
    Set<String> customerBooked,
  ) {
    final label = _slotLabel(localizations, timeSlot);
    final isBlocked = blockedSlots.contains(label);
    final isBooked = customerBooked.contains(label);
    final detailsButton = isBooked
        ? FilledButton.tonal(
            key: ValueKey('review-details-${timeSlot.name}'),
            onPressed: () => widget.onOpenDetails(_selectedDate, label),
            child: Text(localizations.details),
          )
        : null;

    if (widget.isLeftHanded) {
      // Left-handed: swap the two columns so the button sits on the leading
      // edge and the hour label, with any blocked-off note beneath it, runs
      // out to the trailing edge.
      return ListTile(
        key: ValueKey('review-slot-${timeSlot.name}'),
        leading: detailsButton,
        title: Text(label, textAlign: TextAlign.end),
        subtitle: isBlocked
            ? Text(localizations.blockedOffStatus, textAlign: TextAlign.end)
            : null,
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      );
    }

    return ListTile(
      key: ValueKey('review-slot-${timeSlot.name}'),
      title: Text(label),
      subtitle: isBlocked ? Text(localizations.blockedOffStatus) : null,
      trailing: detailsButton,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 16),
    );
  }
}
