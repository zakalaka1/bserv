import 'package:flutter/material.dart';

import '../../data/content/business_content_repository.dart';
import '../../l10n/app_localizations.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    required this.isAdmin,
    required this.contentRepository,
  });

  final bool isAdmin;
  final BusinessContentRepository contentRepository;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String _notesToSave = '';
  String _pricingToSave = '';

  Widget _sectionCard({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String title,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: key,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isSaving = true);
    final localizations = AppLocalizations.of(context)!;

    try {
      await widget.contentRepository.saveContent(
        notes: _notesToSave,
        pricing: _pricingToSave,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(localizations.contentSaved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.contentSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAdminEditor(
    BuildContext context,
    AppLocalizations localizations,
    BusinessContent content,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizations.updateNotesAndPricing,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey('notes-editor-${content.notes.hashCode}'),
                initialValue: content.notes,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: localizations.notes,
                  hintText: localizations.notesHint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? localizations.contentRequired
                    : null,
                onSaved: (value) => _notesToSave = value!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('pricing-editor-${content.pricing.hashCode}'),
                initialValue: content.pricing,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: localizations.pricing,
                  hintText: localizations.pricingHint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? localizations.contentRequired
                    : null,
                onSaved: (value) => _pricingToSave = value!.trim(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('save-notes-and-pricing'),
                onPressed: _isSaving ? null : _saveContent,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? localizations.saving : localizations.save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final defaultContent = BusinessContent(
      notes:
          '${localizations.announcementHeading}\n\n${localizations.announcementMessage}',
      pricing: localizations.pricingNotAvailable,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: StreamBuilder<BusinessContent>(
          stream: widget.contentRepository.watchContent(
            defaultNotes: defaultContent.notes,
            defaultPricing: defaultContent.pricing,
          ),
          initialData: defaultContent,
          builder: (context, snapshot) {
            final content = snapshot.data ?? defaultContent;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: const ValueKey('announcements-screen'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionCard(
                    context: context,
                    key: const ValueKey('notes-section'),
                    icon: Icons.sticky_note_2_outlined,
                    title: localizations.notes,
                    text: content.notes,
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    context: context,
                    key: const ValueKey('pricing-section'),
                    icon: Icons.sell_outlined,
                    title: localizations.pricing,
                    text: content.pricing,
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 16),
                    _buildAdminEditor(context, localizations, content),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
