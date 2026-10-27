import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_config.dart';
import '../../data/appointments/appointment_repository.dart';
import '../../features/service_area/service_area_map.dart';
import '../../l10n/app_localizations.dart';

class LatestAppointmentScreen extends StatefulWidget {
  const LatestAppointmentScreen({
    super.key,
    required this.isAuthenticated,
    required this.appointmentRepository,
    required this.onLoginRequested,
    required this.onBookRequested,
  });

  final bool isAuthenticated;
  final AppointmentRepository appointmentRepository;
  final VoidCallback onLoginRequested;
  final VoidCallback onBookRequested;

  @override
  State<LatestAppointmentScreen> createState() =>
      _LatestAppointmentScreenState();
}

class _LatestAppointmentScreenState extends State<LatestAppointmentScreen> {
  /// Set while a cancellation is in flight so the button cannot be tapped twice.
  bool _isCancelling = false;

  final _nameController = TextEditingController();
  final _issueController = TextEditingController();
  final _imagePicker = ImagePicker();

  /// The row whose inline editor is open; only one row is edited at a time.
  _EditableField? _editing;

  /// A picked photo waiting for the customer to confirm or discard it.
  XFile? _pickedPhoto;

  bool _isPickingPhoto = false;
  bool _isSaving = false;

  static final _allowedDescriptionCharacters = RegExp(
    r"""[\p{L}\p{N}\s/'"#().:_&*@!?,;|\-]""",
    unicode: true,
  );

  /// True while a write is in flight or a picked photo is pending confirmation,
  /// so starting another editor cannot silently discard the first change.
  bool get _isBusy => _isSaving || _isPickingPhoto || _pickedPhoto != null;

  /// Re-read on every build so the deadline stays correct across midnight.
  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _nameController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  List<TextInputFormatter> _descriptionFormatters(int maxLength) => [
    FilteringTextInputFormatter.allow(_allowedDescriptionCharacters),
    LengthLimitingTextInputFormatter(maxLength),
  ];

  /// Seeds the inline editor for [field] from the current appointment.
  void _startEditing(_EditableField field, AppointmentRecord appointment) {
    setState(() {
      _editing = field;
      _isSaving = false;
      _pickedPhoto = null;
      if (field == _EditableField.name) {
        _nameController.text = appointment.customerName;
      } else {
        _issueController.text = appointment.issueDescription;
      }
    });
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _editing = null;
      _isSaving = false;
      _pickedPhoto = null;
    });
  }

  Future<void> _saveField(
    _EditableField field,
    AppointmentRecord appointment,
  ) async {
    if (_isSaving) return;

    if (field == _EditableField.name) {
      final value = _nameController.text;
      if (value.trim() == appointment.customerName.trim()) {
        _cancelEditing();
        return;
      }
      await _persist(appointment, customerName: value);
      return;
    }

    final value = _issueController.text;
    if (value.trim() == appointment.issueDescription.trim()) {
      _cancelEditing();
      return;
    }
    await _persist(appointment, issueDescription: value);
  }

  Future<void> _savePhoto(AppointmentRecord appointment) async {
    final photo = _pickedPhoto;
    if (photo == null || _isSaving) return;
    await _persist(appointment, photo: photo);
  }

  /// Writes the provided fields through the repository and reports the result.
  Future<void> _persist(
    AppointmentRecord appointment, {
    String? customerName,
    String? issueDescription,
    XFile? photo,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await widget.appointmentRepository.updateOwnAppointment(
        appointment.id,
        customerName: customerName,
        issueDescription: issueDescription,
        photo: photo,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _editing = null;
        _isSaving = false;
        _pickedPhoto = null;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizations.appointmentUpdated)),
        );
    } catch (_) {
      if (!mounted) return;
      // Keep the editor (or the picked photo) open so the customer can retry.
      setState(() => _isSaving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizations.appointmentUpdateFailed)),
        );
    }
  }

  Future<void> _pickPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (mounted && photo != null) {
        setState(() => _pickedPhoto = photo);
      }
    } catch (_) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.photoPickerFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
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

  /// Matches the status pill used on the admin Review Appointment Details
  /// screen: a cancellation is a negative outcome (error tone), while active
  /// and completed bookings use the primary accent.
  Widget _statusPill(AppLocalizations localizations, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCancelled = status == 'cancelled';
    final foreground = isCancelled
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Chip(
      avatar: Icon(_statusIcon(status), size: 18, color: foreground),
      label: Text(
        _statusLabel(localizations, status),
        style: TextStyle(color: foreground),
      ),
      backgroundColor: isCancelled
          ? colorScheme.errorContainer
          : colorScheme.primaryContainer,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Asks for confirmation before cancelling; the slot is released afterwards.
  Future<void> _confirmCancel(AppointmentRecord appointment) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.cancelAppointmentPrompt),
        content: Text(localizations.cancelAppointmentMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCancelling = true);
    try {
      await widget.appointmentRepository.cancelAppointment(appointment);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizations.appointmentCancelled)),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(localizations.appointmentCancelFailed)),
        );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _cancelButton(
    AppLocalizations localizations,
    AppointmentRecord appointment,
  ) {
    return OutlinedButton.icon(
      key: const ValueKey('cancel-appointment'),
      onPressed: _isCancelling ? null : () => _confirmCancel(appointment),
      icon: _isCancelling
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cancel_outlined),
      label: Text(localizations.cancelAppointment),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// A detail row that can be edited inline: a pencil opens the field, then a
  /// check saves and a close button discards the change. The name and the issue
  /// are optional, so an empty value is accepted.
  Widget _editableDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    required _EditableField field,
    required AppointmentRecord appointment,
    required TextEditingController controller,
    required bool canEdit,
    int minLines = 1,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final localizations = AppLocalizations.of(context)!;
    final isEditing = canEdit && _editing == field;
    final canStartEditing = canEdit && !_isBusy && _editing == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          if (isEditing)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${field.name}-editor'),
                    controller: controller,
                    autofocus: true,
                    inputFormatters: _descriptionFormatters(
                      field == _EditableField.name ? 30 : 300,
                    ),
                    minLines: minLines,
                    maxLines: maxLines,
                    textCapitalization: textCapitalization,
                    textInputAction: maxLines == 1
                        ? TextInputAction.done
                        : TextInputAction.newline,
                    onFieldSubmitted: maxLines == 1
                        ? (_) => _saveField(field, appointment)
                        : null,
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                IconButton(
                  key: ValueKey('cancel-${field.name}'),
                  onPressed: _isSaving ? null : _cancelEditing,
                  tooltip: localizations.cancel,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  key: ValueKey('save-${field.name}'),
                  onPressed: _isSaving
                      ? null
                      : () => _saveField(field, appointment),
                  tooltip: localizations.save,
                  visualDensity: VisualDensity.compact,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (canEdit)
                  IconButton(
                    key: ValueKey('edit-${field.name}'),
                    onPressed: canStartEditing
                        ? () => _startEditing(field, appointment)
                        : null,
                    tooltip: localizations.edit,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// The photo row: read-only once a photo is stored, otherwise the customer
  /// can attach one. A picked photo is previewed and needs a check to upload.
  Widget _photoRow(
    BuildContext context,
    AppLocalizations localizations,
    AppointmentRecord appointment,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = appointment.status == 'scheduled';
    final pickedPhoto = _pickedPhoto;
    final canPickPhoto =
        canEdit &&
        appointment.photoPath == null &&
        pickedPhoto == null &&
        !_isBusy &&
        _editing == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              appointment.photoPath == null
                  ? Icons.image_not_supported_outlined
                  : Icons.verified_user_outlined,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appointment.photoPath == null
                    ? localizations.noAppointmentPhoto
                    : localizations.appointmentPhotoStored,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (canEdit && appointment.photoPath == null && pickedPhoto == null)
              IconButton(
                key: const ValueKey('add-appointment-photo'),
                onPressed: canPickPhoto ? _pickPhoto : null,
                tooltip: localizations.addPhotoAttachment,
                visualDensity: VisualDensity.compact,
                icon: _isPickingPhoto
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
              ),
          ],
        ),
        if (pickedPhoto != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List>(
              future: pickedPhoto.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Image.memory(
                  snapshot.data!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: const ValueKey('cancel-appointment-photo'),
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _pickedPhoto = null),
                tooltip: localizations.cancel,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
              ),
              IconButton(
                key: const ValueKey('save-appointment-photo'),
                onPressed: _isSaving ? null : () => _savePhoto(appointment),
                tooltip: localizations.save,
                visualDensity: VisualDensity.compact,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (!widget.isAuthenticated) {
      return _emptyState(
        context,
        message: localizations.signInToSeeLatestAppointment,
        actionLabel: localizations.login,
        onAction: widget.onLoginRequested,
      );
    }

    return StreamBuilder<AppointmentRecord?>(
      stream: widget.appointmentRepository.watchLatestAppointment(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                localizations.latestAppointmentLoadFailed,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointment = snapshot.data;
        if (appointment == null) {
          return _emptyState(
            context,
            message: localizations.noLatestAppointment,
            actionLabel: localizations.book,
            onAction: widget.onBookRequested,
          );
        }

        final dateText = MaterialLocalizations.of(context)
            .formatMediumDate(appointment.appointmentDate);
        final colorScheme = Theme.of(context).colorScheme;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _statusPill(localizations, appointment.status),
                      ),
                      const SizedBox(height: 8),
                      if (appointment.serviceType.trim().isNotEmpty)
                        _detailRow(
                          context,
                          label: localizations.typeOfService,
                          value: serviceTypeLabel(appointment.serviceType),
                        ),
                      _detailRow(
                        context,
                        label: localizations.appointmentDateLabel,
                        value: dateText,
                      ),
                      _detailRow(
                        context,
                        label: localizations.appointmentTimeLabel,
                        value: appointment.timeSlot,
                      ),
                      _editableDetailRow(
                        context,
                        label: localizations.customerName,
                        value: appointment.customerName,
                        field: _EditableField.name,
                        appointment: appointment,
                        controller: _nameController,
                        canEdit: appointment.status == 'scheduled',
                        textCapitalization: TextCapitalization.words,
                      ),
                      _detailRow(
                        context,
                        label: localizations.followUpPhoneRequired,
                        value: appointment.phone,
                      ),
                      _detailRow(
                        context,
                        label: localizations.numberAndStreet,
                        value: appointment.streetAddress,
                      ),
                      _detailRow(
                        context,
                        label: localizations.city,
                        value: appointment.city,
                      ),
                      _detailRow(
                        context,
                        label: localizations.postalCodeRequired,
                        value: appointment.postalCode,
                      ),
                      _editableDetailRow(
                        context,
                        label: localizations.natureOfIssue,
                        value: appointment.issueDescription,
                        field: _EditableField.issue,
                        appointment: appointment,
                        controller: _issueController,
                        canEdit: appointment.status == 'scheduled',
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const Divider(height: 24),
                      _photoRow(context, localizations, appointment),
                      if (appointment.status == 'scheduled' &&
                          BookingSchedule.isCancellableOn(
                            appointment.appointmentDate,
                            today: _today,
                          ))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _cancelButton(localizations, appointment),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rows on the latest appointment that support inline editing.
enum _EditableField { name, issue }
