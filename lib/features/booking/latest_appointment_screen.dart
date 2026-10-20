import 'package:flutter/material.dart';

import '../../data/appointments/appointment_repository.dart';
import '../../l10n/app_localizations.dart';

class LatestAppointmentScreen extends StatelessWidget {
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

  String _statusLabel(AppLocalizations localizations, String status) {
    return switch (status) {
      'scheduled' => localizations.appointmentStatusScheduled,
      'cancelled' => localizations.appointmentStatusCancelled,
      'completed' => localizations.appointmentStatusCompleted,
      _ => status,
    };
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (!isAuthenticated) {
      return _emptyState(
        context,
        message: localizations.signInToSeeLatestAppointment,
        actionLabel: localizations.login,
        onAction: onLoginRequested,
      );
    }

    return StreamBuilder<AppointmentRecord?>(
      stream: appointmentRepository.watchLatestAppointment(),
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
            onAction: onBookRequested,
          );
        }

        final dateText = MaterialLocalizations.of(context)
            .formatMediumDate(appointment.appointmentDate);
        final statusLabel = _statusLabel(localizations, appointment.status);
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
                        child: Chip(
                          avatar: const Icon(Icons.event_available_outlined),
                          label: Text(statusLabel),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      _detailRow(
                        context,
                        label: localizations.customerName,
                        value: appointment.customerName,
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
                      _detailRow(
                        context,
                        label: localizations.natureOfIssue,
                        value: appointment.issueDescription,
                      ),
                      const Divider(height: 24),
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
                        ],
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
