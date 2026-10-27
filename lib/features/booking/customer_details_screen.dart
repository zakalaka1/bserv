import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_config.dart';
import '../../data/appointments/appointment_repository.dart';
import '../../features/service_area/service_area_map.dart';
import '../../l10n/app_localizations.dart';

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.serviceArea,
    required this.serviceType,
    required this.appointmentDate,
    required this.timeSlot,
    required this.onBook,
  });

  final ServiceArea serviceArea;
  final ServiceType serviceType;
  final DateTime appointmentDate;
  final String timeSlot;
  final Future<void> Function(AppointmentDraft draft) onBook;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _issueController = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _photo;
  bool _isPickingPhoto = false;
  bool _isSaving = false;

  static final _allowedDescriptionCharacters = RegExp(
    r"""[\p{L}\p{N}\s/'"#().:_&*@!?,;|\-]""",
    unicode: true,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (mounted && photo != null) {
        setState(() => _photo = photo);
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

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final localizations = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await widget.onBook(
        AppointmentDraft(
          appointmentDate: widget.appointmentDate,
          timeSlot: widget.timeSlot,
          serviceType: widget.serviceType.storageValue,
          customerName: _nameController.text,
          phone: _phoneController.text,
          streetAddress: _streetController.text,
          city: _cityController.text,
          postalCode: _postalCodeController.text,
          issueDescription: _issueController.text,
          photo: _photo,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.bookingSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validatePhone(String? value, AppLocalizations localizations) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return localizations.phoneRequired;
    if (!RegExp(r'^(?:\d{10}|\d{3}-\d{3}-\d{4}|\d{3}-\d{7})$')
        .hasMatch(phone)) {
      return localizations.phoneInvalid;
    }
    return null;
  }

  String? _validatePostalCode(String? value, AppLocalizations localizations) {
    final postalCode = value?.trim() ?? '';
    if (postalCode.isEmpty) return localizations.postalCodeRequiredError;
    if (!RegExp(r'^[A-Za-z]\d[A-Za-z] ?\d[A-Za-z]\d$').hasMatch(postalCode)) {
      return localizations.postalCodeInvalid;
    }
    if (!ServiceAreaCoverage.isServicedPostalCode(postalCode)) {
      return localizations.postalCodeOutsideServiceArea;
    }
    return null;
  }

  List<TextInputFormatter> _descriptionFormatters(int maxLength) => [
    FilteringTextInputFormatter.allow(_allowedDescriptionCharacters),
    LengthLimitingTextInputFormatter(maxLength),
  ];

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final dateText = MaterialLocalizations.of(context)
        .formatMediumDate(widget.appointmentDate);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    localizations.customerDetailsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.appointmentSummary,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            localizations.serviceAreaForBooking(
                              widget.serviceArea.name,
                            ),
                          ),
                          Text(
                            localizations.serviceTypeForBooking(
                              widget.serviceType.label,
                            ),
                          ),
                          Text(
                            localizations.bookingDateTime(
                              dateText,
                              widget.timeSlot,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('customer-name'),
                    controller: _nameController,
                    inputFormatters: _descriptionFormatters(30),
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(
                      labelText: localizations.customerName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customer-phone'),
                    controller: _phoneController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                      labelText: localizations.followUpPhoneRequired,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => _validatePhone(value, localizations),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customer-street'),
                    controller: _streetController,
                    inputFormatters: _descriptionFormatters(50),
                    maxLength: 50,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: localizations.numberAndStreet,
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customer-city'),
                    controller: _cityController,
                    inputFormatters: _descriptionFormatters(30),
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: localizations.city,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customer-postal-code'),
                    controller: _postalCodeController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.postalCode],
                    decoration: InputDecoration(
                      labelText: localizations.postalCodeRequired,
                      prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                    ),
                    inputFormatters: [LengthLimitingTextInputFormatter(7)],
                    validator: (value) =>
                        _validatePostalCode(value, localizations),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customer-issue'),
                    controller: _issueController,
                    inputFormatters: _descriptionFormatters(300),
                    maxLength: 300,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: localizations.natureOfIssue,
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 44),
                        child: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_photo case final photo?) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FutureBuilder(
                        future: photo.readAsBytes(),
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
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        key: const ValueKey('remove-customer-photo'),
                        onPressed: () => setState(() => _photo = null),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(localizations.removePhoto),
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      key: const ValueKey('add-customer-photo'),
                      onPressed: _isPickingPhoto ? null : _addPhoto,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _isPickingPhoto
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file),
                      label: Text(localizations.addPhotoAttachment),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('book-customer-details'),
                    onPressed: _isSaving ? null : _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      _isSaving
                          ? localizations.savingBooking
                          : localizations.book,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
