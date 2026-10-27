import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_config.dart';
import '../../l10n/app_localizations.dart';

/// Where the map attribution link opens. The OpenStreetMap tile usage policy
/// requires the attribution to be linked to this page.
/// See https://operations.osmfoundation.org/policies/tiles/
const _osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

class ServiceArea {
  const ServiceArea({
    required this.id,
    required this.center,
    required this.name,
  });

  final String id;

  /// Fallback marker anchor, used when no outline is configured for the area;
  /// see [markerAnchor].
  final LatLng center;

  /// The name shown for the area on the map and in the booking flow.
  final String name;

  /// The area outline configured in [ServiceAreaCoverage.areaBoundaries].
  /// Empty when no boundary has been configured for this area.
  List<LatLng> get boundary => [
    for (final corner
        in ServiceAreaCoverage.areaBoundaries[id] ?? const <List<double>>[])
      LatLng(corner[0], corner[1]),
  ];

  /// The point the map marker is drawn at: the middle of the outline corners,
  /// so the circle sits on the drawn shape instead of drifting to wherever a
  /// hand-written [center] happens to be. Falls back to [center] when the area
  /// has no drawable outline.
  LatLng get markerAnchor {
    final outline = boundary;
    if (outline.length < 3) return center;
    var latitude = 0.0;
    var longitude = 0.0;
    for (final corner in outline) {
      latitude += corner.latitude;
      longitude += corner.longitude;
    }
    return LatLng(latitude / outline.length, longitude / outline.length);
  }
}

/// The service areas shown on the map, built from the configuration in
/// [ServiceAreaCoverage.serviceAreas]. Adding or removing an area happens in
/// `app_config.dart`; this list follows automatically.
final serviceAreas = List<ServiceArea>.unmodifiable([
  for (final area in ServiceAreaCoverage.serviceAreas.entries)
    ServiceArea(
      id: area.key,
      center: LatLng(area.value.latitude, area.value.longitude),
      name: area.value.name,
    ),
]);

/// A service the business offers. [storageValue] is what is written to the
/// appointment document, while [label] is what customers and admins see.
class ServiceType {
  const ServiceType({
    required this.id,
    required this.storageValue,
    required this.label,
  });

  final String id;
  final String storageValue;
  final String label;
}

/// The service types a booking can be started for, built from the configuration
/// in [ServiceCatalog.serviceTypes]. Adding or removing a type happens in
/// `app_config.dart`; this list follows automatically, and its first entry is
/// the default shown on the landing page.
final serviceTypes = List<ServiceType>.unmodifiable([
  for (final serviceType in ServiceCatalog.serviceTypes.entries)
    ServiceType(
      id: serviceType.key,
      storageValue: serviceType.value.storageValue,
      label: serviceType.value.label,
    ),
]);

/// Resolves a stored service-type value back to its display label. Values that
/// predate the service-type field (or that this build doesn't know) are shown
/// as they were stored.
String serviceTypeLabel(String? storageValue) {
  final value = storageValue?.trim() ?? '';
  for (final serviceType in serviceTypes) {
    if (serviceType.storageValue == value) {
      return serviceType.label;
    }
  }
  return value;
}

class ServiceAreaMap extends StatefulWidget {
  const ServiceAreaMap({
    super.key,
    required this.selectedArea,
    required this.onAreaSelected,
    required this.onContinue,
  });

  final ServiceArea? selectedArea;

  /// Called with the tapped area, or with `null` when the map is tapped away
  /// from every area so the current selection is cleared.
  final ValueChanged<ServiceArea?> onAreaSelected;
  final void Function(ServiceArea area, ServiceType serviceType) onContinue;

  @override
  State<ServiceAreaMap> createState() => _ServiceAreaMapState();
}

class _ServiceAreaMapState extends State<ServiceAreaMap> {
  ServiceType _serviceType = serviceTypes.first;

  /// Emits the [ServiceArea]s whose boundaries are under the pointer, so the
  /// drawn outlines are tappable and not just the centre markers.
  final LayerHitNotifier<ServiceArea> _boundaryHitNotifier =
      LayerHitNotifier<ServiceArea>(null);

  /// A tap that reached the map itself (rather than a marker or an outline)
  /// clears the selection.
  void _handleMapTap(TapPosition _, LatLng _) {
    widget.onAreaSelected(null);
  }

  @override
  void dispose() {
    _boundaryHitNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedId = widget.selectedArea?.id;

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(43.6900, -79.3900),
            initialZoom: ServiceAreaCoverage.mapInitialZoom,
            minZoom: 7,
            maxZoom: 18,
            onTap: _handleMapTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.bserv',
            ),
            GestureDetector(
              onTap: () {
                final hit = _boundaryHitNotifier.value;
                if (hit == null || hit.hitValues.isEmpty) return;
                widget.onAreaSelected(hit.hitValues.first);
              },
              child: PolygonLayer<ServiceArea>(
                key: const ValueKey('service-area-boundaries'),
                hitNotifier: _boundaryHitNotifier,
                polygons: [
                  for (final area in serviceAreas)
                    if (area.boundary.length >= 3)
                      Polygon<ServiceArea>(
                        points: area.boundary,
                        hitValue: area,
                        // The fill is deliberately opaque enough to read as a
                        // highlighted area, matching the marker circles.
                        color: colorScheme.primary.withValues(
                          alpha: selectedId == area.id ? 0.50 : 0.35,
                        ),
                        borderColor: colorScheme.primary,
                        borderStrokeWidth: selectedId == area.id ? 3.5 : 2,
                      ),
                ],
              ),
            ),
            MarkerLayer(
              markers: [
                for (final area in serviceAreas)
                  Marker(
                    key: ValueKey('service-area-${area.id}'),
                    point: area.markerAnchor,
                    width: 96,
                    height: 96,
                    child: _ServiceAreaHotspot(
                      area: area,
                      selected: widget.selectedArea?.id == area.id,
                      onTap: () => widget.onAreaSelected(area),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              // flutter_map asks only that its source copyright notice is
              // preserved, not for on-screen branding, so show just the
              // OpenStreetMap credit that the tile usage policy requires.
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution(
                  localizations.mapAttribution,
                  // The localized string already starts with '© ', which
                  // flutter_map would otherwise prepend a second time.
                  prependCopyright: false,
                  onTap: () =>
                      unawaited(launchUrl(Uri.parse(_osmCopyrightUrl))),
                ),
              ],
            ),
          ],
        ),
        PositionedDirectional(
          top: 16,
          start: 16,
          end: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('service-type-dropdown'),
                    initialValue: _serviceType.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizations.typeOfService,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final serviceType in serviceTypes)
                        DropdownMenuItem(
                          value: serviceType.id,
                          child: Text(
                            serviceType.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _serviceType = serviceTypes.firstWhere(
                          (serviceType) => serviceType.id == value,
                        );
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.selectedArea case final area?)
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 56,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          area.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('continue-service-area'),
                          onPressed: () =>
                              widget.onContinue(area, _serviceType),
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(localizations.continueBooking),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ServiceAreaHotspot extends StatelessWidget {
  const _ServiceAreaHotspot({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final ServiceArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor = selected
        ? colorScheme.primary.withValues(alpha: 0.38)
        : colorScheme.primaryContainer.withValues(alpha: 0.58);

    // A generous fixed-size Material target makes each service-area circle easy to tap.
    return Tooltip(
      message: area.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('hotspot-${area.id}'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 84 : 72,
              height: selected ? 84 : 72,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary,
                  width: selected ? 3 : 2,
                ),
              ),
              child: Icon(
                selected ? Icons.location_on : Icons.location_on_outlined,
                color: colorScheme.onPrimaryContainer,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
