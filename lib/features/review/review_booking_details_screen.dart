import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../data/appointments/appointment_repository.dart';
import '../../features/service_area/service_area_map.dart';
import '../../l10n/app_localizations.dart';

/// The four bookable times of a working day, in display order.
enum _DetailsTimeSlot { morning, midday, afternoon, evening }

/// Admin-only schedule for a single day, reached from the Review overview.
///
/// The day itself is owned by the shell so the shared AppBar back button can
/// return to the overview showing the day the admin was last looking at. Each
/// of the four time slots renders as a card: customer bookings show their
/// contact details, a photo and the status control, blocked-off slots are
/// labelled, and free slots stay empty.
class ReviewBookingDetailsScreen extends StatefulWidget {
  const ReviewBookingDetailsScreen({
    super.key,
    required this.date,
    required this.onDateChanged,
    required this.appointmentRepository,
    required this.blockedOffTimes,
  });

  /// The day currently on screen; always date-only.
  final DateTime date;

  /// Called when the admin steps to another day.
  final ValueChanged<DateTime> onDateChanged;

  final AppointmentRepository appointmentRepository;

  /// Blocked-off slots across all dates, filtered to [date] when displayed.
  final Stream<List<BlockedOffTime>> blockedOffTimes;

  @override
  State<ReviewBookingDetailsScreen> createState() =>
      _ReviewBookingDetailsScreenState();
}

class _ReviewBookingDetailsScreenState
    extends State<ReviewBookingDetailsScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());

  late Stream<List<AppointmentRecord>> _appointments;

  /// Download URLs are fetched once per appointment, not on every rebuild.
  final Map<String, Future<String?>> _photoUrls = {};

  /// Set while a status change is in flight so the controls stay disabled.
  String? _updatingAppointmentId;

  @override
  void initState() {
    super.initState();
    _appointments = widget.appointmentRepository.watchAppointmentsByDate(
      widget.date,
    );
  }

  @override
  void didUpdateWidget(ReviewBookingDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(widget.date, oldWidget.date)) {
      _appointments = widget.appointmentRepository.watchAppointmentsByDate(
        widget.date,
      );
    }
  }

  DateTime get _previousDay => DateUtils.addDaysToDate(widget.date, -1);

  DateTime get _nextDay => DateUtils.addDaysToDate(widget.date, 1);

  /// Going back is always allowed (the admin reviews past days too); going
  /// forward stops at the last date the booking calendar offers.
  bool get _canGoToNextDay =>
      !_nextDay.isAfter(BookingSchedule.lastBookableDate(_today));

  String _slotLabel(AppLocalizations localizations, _DetailsTimeSlot timeSlot) {
    return switch (timeSlot) {
      _DetailsTimeSlot.morning => localizations.timeSlotMorning,
      _DetailsTimeSlot.midday => localizations.timeSlotMidday,
      _DetailsTimeSlot.afternoon => localizations.timeSlotAfternoon,
      _DetailsTimeSlot.evening => localizations.timeSlotEvening,
    };
  }

  String _statusLabel(AppLocalizations localizations, String status) {
    return switch (status) {
      'scheduled' => localizations.appointmentStatusScheduled,
      'cancelled' => localizations.appointmentStatusCancelled,
      'completed' => localizations.appointmentStatusCompleted,
      _ => status,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'cancelled' => Icons.cancel_outlined,
      'completed' => Icons.task_alt,
      _ => Icons.schedule,
    };
  }

  Future<void> _updateStatus(
    AppLocalizations localizations,
    AppointmentRecord appointment,
    Set<String> selection,
  ) async {
    // De-selecting a segment (emptySelectionAllowed) means "no change".
    if (selection.isEmpty || _updatingAppointmentId != null) return;
    final status = selection.first;
    if (status == appointment.status) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _updatingAppointmentId = appointment.id);
    try {
      await widget.appointmentRepository.updateAppointmentStatus(
        appointment.id,
        status,
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizations.statusUpdateFailed)),
        );
    } finally {
      if (mounted) setState(() => _updatingAppointmentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<AppointmentRecord>>(
      stream: _appointments,
      builder: (context, appointmentsSnapshot) {
        return StreamBuilder<List<BlockedOffTime>>(
          stream: widget.blockedOffTimes,
          builder: (context, blockedSnapshot) {
            final blockedSlots = {
              for (final entry
                  in blockedSnapshot.data ?? const <BlockedOffTime>[])
                if (DateUtils.isSameDay(entry.date, widget.date))
                  entry.timeSlot,
            };
            final appointmentsBySlot = {
              for (final appointment
                  in appointmentsSnapshot.data ?? const <AppointmentRecord>[])
                if (DateUtils.isSameDay(
                  appointment.appointmentDate,
                  widget.date,
                ))
                  appointment.timeSlot: appointment,
            };
            final isLoading =
                appointmentsSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !appointmentsSnapshot.hasData;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDateHeader(localizations),
                        const SizedBox(height: 16),
                        if (appointmentsSnapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              localizations.reviewDetailsLoadFailed,
                              textAlign: TextAlign.center,
                            ),
                          )
                        else if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          for (final timeSlot in _DetailsTimeSlot.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildSlotCard(
                                localizations,
                                timeSlot,
                                blockedSlots: blockedSlots,
                                appointment:
                                    appointmentsBySlot[_slotLabel(
                                      localizations,
                                      timeSlot,
                                    )],
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

  Widget _buildDateHeader(AppLocalizations localizations) {
    final theme = Theme.of(context);

    return Row(
      children: [
        FloatingActionButton.small(
          key: const ValueKey('review-details-previous-day'),
          // Two arrows on one route would otherwise share a hero tag.
          heroTag: null,
          tooltip: localizations.previousDay,
          onPressed: () => widget.onDateChanged(_previousDay),
          child: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              MaterialLocalizations.of(context).formatFullDate(widget.date),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
        FloatingActionButton.small(
          key: const ValueKey('review-details-next-day'),
          heroTag: null,
          tooltip: localizations.nextDay,
          onPressed: _canGoToNextDay
              ? () => widget.onDateChanged(_nextDay)
              : null,
          child: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildSlotCard(
    AppLocalizations localizations,
    _DetailsTimeSlot timeSlot, {
    required Set<String> blockedSlots,
    required AppointmentRecord? appointment,
  }) {
    final label = _slotLabel(localizations, timeSlot);
    final isBlocked = blockedSlots.contains(label);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey('review-details-slot-${timeSlot.name}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isBlocked
                      ? Icons.event_busy_outlined
                      : appointment == null
                      ? Icons.event_available_outlined
                      : Icons.person_pin_circle_outlined,
                  // Held and booked slots both use the primary accent; only a
                  // free slot stays muted.
                  color: isBlocked || appointment != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusPill(
                  localizations,
                  isBlocked: isBlocked,
                  appointment: appointment,
                ),
              ],
            ),
            if (isBlocked) ...[
              const SizedBox(height: 8),
              Text(
                localizations.timeSlotUnavailable,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (appointment != null) ...[
              ..._buildBookingDetails(localizations, appointment),
              const SizedBox(height: 8),
              _buildStatusControl(localizations, timeSlot, appointment),
              const SizedBox(height: 4),
              _AdminNoteEditor(
                key: ValueKey('review-note-${timeSlot.name}'),
                appointment: appointment,
                onSave: (note) => widget.appointmentRepository
                    .updateAppointmentNote(appointment.id, note),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(
    AppLocalizations localizations, {
    required bool isBlocked,
    required AppointmentRecord? appointment,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // A blocked-off slot is a temporary admin hold, so it shares the primary
    // accent with booked slots; a cancellation is a recorded negative outcome
    // and uses the error tone instead.
    final (
      String label,
      IconData icon,
      Color background,
      Color foreground,
    ) = isBlocked
        ? (
            localizations.blockedOffStatus,
            Icons.event_busy_outlined,
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
          )
        : appointment == null
        ? (
            localizations.free,
            Icons.check_circle_outline,
            colorScheme.surfaceContainerHighest,
            colorScheme.onSurfaceVariant,
          )
        : appointment.status == 'cancelled'
        ? (
            _statusLabel(localizations, appointment.status),
            _statusIcon(appointment.status),
            colorScheme.errorContainer,
            colorScheme.onErrorContainer,
          )
        : (
            _statusLabel(localizations, appointment.status),
            _statusIcon(appointment.status),
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
          );

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _buildBookingDetails(
    AppLocalizations localizations,
    AppointmentRecord appointment,
  ) {
    // Empty fields are skipped so legacy bookings don't show blank rows.
    final address = [
      appointment.streetAddress.trim(),
      appointment.city.trim(),
      appointment.postalCode.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    return [
      const Divider(height: 24),
      if (appointment.serviceType.trim().isNotEmpty)
        _infoRow(
          localizations.typeOfService,
          serviceTypeLabel(appointment.serviceType),
        ),
      if (appointment.customerName.trim().isNotEmpty)
        _infoRow(localizations.customerName, appointment.customerName.trim()),
      if (appointment.phone.trim().isNotEmpty)
        _infoRow(localizations.phone, appointment.phone.trim()),
      if (address.isNotEmpty) _infoRow(localizations.address, address),
      if (appointment.issueDescription.trim().isNotEmpty)
        _infoRow(
          localizations.natureOfIssue,
          appointment.issueDescription.trim(),
        ),
      if (appointment.photoPath != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _buildPhotoThumbnail(localizations, appointment),
          ),
        ),
    ];
  }

  Widget _infoRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStatusControl(
    AppLocalizations localizations,
    _DetailsTimeSlot timeSlot,
    AppointmentRecord appointment,
  ) {
    const selectableStatuses = {'scheduled', 'completed', 'cancelled'};
    final isUpdating = _updatingAppointmentId == appointment.id;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SegmentedButton<String>(
        key: ValueKey('review-status-${timeSlot.name}'),
        segments: [
          ButtonSegment(
            value: 'completed',
            icon: const Icon(Icons.task_alt),
            label: Text(localizations.markCompleted),
          ),
          // Lets the admin undo an accidental Complete/Cancel.
          ButtonSegment(
            value: 'scheduled',
            icon: const Icon(Icons.schedule),
            label: Text(localizations.markScheduled),
          ),
          ButtonSegment(
            value: 'cancelled',
            icon: const Icon(Icons.cancel_outlined),
            label: Text(localizations.markCancelled),
          ),
        ],
        // Show the status the booking is currently in; statuses the app does
        // not know about leave the control empty.
        selected: selectableStatuses.contains(appointment.status)
            ? {appointment.status}
            : const <String>{},
        // Tapping the current choice clears it instead of re-saving the status.
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        onSelectionChanged: isUpdating
            ? null
            : (selection) =>
                  _updateStatus(localizations, appointment, selection),
      ),
    );
  }

  Future<String?> _photoUrl(AppointmentRecord appointment) {
    final path = appointment.photoPath!;
    return _photoUrls.putIfAbsent(
      appointment.id,
      () => widget.appointmentRepository.appointmentPhotoUrl(path),
    );
  }

  Widget _buildPhotoThumbnail(
    AppLocalizations localizations,
    AppointmentRecord appointment,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<String?>(
      future: _photoUrl(appointment),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) {
          return Container(
            key: ValueKey('review-photo-missing-${appointment.id}'),
            width: 96,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              snapshot.connectionState == ConnectionState.waiting
                  ? Icons.image_outlined
                  : Icons.image_not_supported_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          );
        }

        return InkWell(
          key: ValueKey('review-photo-${appointment.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showPhotoDialog(localizations, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, width: 96, height: 72, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  void _showPhotoDialog(AppLocalizations localizations, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('review-photo-dialog'),
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Theme.of(dialogContext)
            .colorScheme
            .surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  key: const ValueKey('review-photo-dialog-close'),
                  tooltip: localizations.close,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Admin-only free-text note attached to a single booking.
///
/// Collapsed behind an "Add comment" button so the booking card stays
/// compact; tapping it rolls a multiline editor open below the button.
class _AdminNoteEditor extends StatefulWidget {
  const _AdminNoteEditor({
    super.key,
    required this.appointment,
    required this.onSave,
  });

  final AppointmentRecord appointment;

  /// Persists [note] for this appointment; throws when the write fails.
  final Future<void> Function(String note) onSave;

  @override
  State<_AdminNoteEditor> createState() => _AdminNoteEditorState();
}

class _AdminNoteEditorState extends State<_AdminNoteEditor> {
  late final TextEditingController _controller;

  /// The note the screen last saw stored. Kept locally so the collapsed
  /// summary updates immediately, without waiting for the day's appointments
  /// stream to deliver the write.
  late String _savedNote = widget.appointment.adminNote.trim();

  bool _expanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _savedNote);
  }

  @override
  void didUpdateWidget(_AdminNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final note = widget.appointment.adminNote.trim();
    if (note == _savedNote) return;
    _savedNote = note;
    // Never clobber a draft the admin is still typing.
    if (!_expanded) _controller.text = note;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    _controller.text = _savedNote;
    setState(() => _expanded = true);
  }

  void _close() {
    _controller.text = _savedNote;
    setState(() => _expanded = false);
  }

  Future<void> _save() async {
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final note = _controller.text.trim();
    setState(() => _saving = true);

    try {
      await widget.onSave(note);
      if (!mounted) return;
      setState(() {
        _savedNote = note;
        _expanded = false;
        _saving = false;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(localizations.commentSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizations.commentSaveFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasNote = _savedNote.isNotEmpty;
    final id = widget.appointment.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: ValueKey('review-note-toggle-$id'),
            onPressed: _saving ? null : (_expanded ? _close : _open),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.add_comment_outlined,
            ),
            label: Text(
              hasNote ? localizations.editComment : localizations.addComment,
            ),
          ),
        ),
        if (hasNote && !_expanded)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 4),
            child: Text(
              _savedNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // The zero-height placeholder lets AnimatedSize roll the editor open
        // and closed instead of snapping the card to its new height.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: AlignmentDirectional.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: ValueKey('review-note-field-$id'),
                        controller: _controller,
                        autofocus: true,
                        enabled: !_saving,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: localizations.commentHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            key: ValueKey('review-note-cancel-$id'),
                            onPressed: _saving ? null : _close,
                            child: Text(localizations.cancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            key: ValueKey('review-note-save-$id'),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(localizations.save),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
