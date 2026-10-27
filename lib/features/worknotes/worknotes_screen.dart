import 'package:flutter/material.dart';

import '../../data/content/work_notes_repository.dart';
import '../../l10n/app_localizations.dart';

/// Admin-only free-form running notes, reachable from the overflow menu.
///
/// Mirrors the Notes editor on the Notes & Pricing screen, but keeps a single,
/// larger body of text that is never shown to customers.
class WorkNotesScreen extends StatefulWidget {
  const WorkNotesScreen({super.key, required this.repository});

  final WorkNotesRepository repository;

  @override
  State<WorkNotesScreen> createState() => _WorkNotesScreenState();
}

class _WorkNotesScreenState extends State<WorkNotesScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String _notesToSave = '';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final localizations = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    try {
      await widget.repository.saveWorkNotes(_notesToSave);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(localizations.workNotesSaved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.workNotesSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    const defaultNotes = '';

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: StreamBuilder<WorkNotes>(
          stream: widget.repository.watchWorkNotes(defaultNotes: defaultNotes),
          initialData: const WorkNotes(notes: defaultNotes),
          builder: (context, snapshot) {
            final content = snapshot.data ?? const WorkNotes(notes: '');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                key: const ValueKey('work-notes-card'),
                margin: EdgeInsets.zero,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                // The screen title lives in the shell's app bar, so the card is
                // only the editor itself.
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: ValueKey(
                            'work-notes-editor-${content.notes.hashCode}',
                          ),
                          initialValue: content.notes,
                          enabled: !_isSaving,
                          minLines: 10,
                          maxLines: null,
                          maxLength: 32000,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: localizations.workNotes,
                            hintText: localizations.workNotesHint,
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? localizations.contentRequired
                              : null,
                          onSaved: (value) => _notesToSave = value!.trim(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('save-work-notes'),
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? localizations.saving
                                : localizations.save,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
