import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';

class ServiceArea {
  const ServiceArea({
    required this.id,
    required this.center,
    required this.name,
  });

  final String id;
  final LatLng center;
  final String Function(AppLocalizations localizations) name;
}

const serviceAreas = [
  ServiceArea(
    id: 'downtown',
    center: LatLng(43.6532, -79.3832),
    name: _downtownName,
  ),
  ServiceArea(
    id: 'etobicoke',
    center: LatLng(43.6205, -79.5132),
    name: _etobicokeName,
  ),
  ServiceArea(
    id: 'scarborough',
    center: LatLng(43.7731, -79.2578),
    name: _scarboroughName,
  ),
];

String _downtownName(AppLocalizations localizations) =>
    localizations.downtownServiceArea;

String _etobicokeName(AppLocalizations localizations) =>
    localizations.etobicokeServiceArea;

String _scarboroughName(AppLocalizations localizations) =>
    localizations.scarboroughServiceArea;

class ServiceAreaMap extends StatelessWidget {
  const ServiceAreaMap({
    super.key,
    required this.selectedArea,
    required this.onAreaSelected,
    required this.onContinue,
  });

  final ServiceArea? selectedArea;
  final ValueChanged<ServiceArea> onAreaSelected;
  final ValueChanged<ServiceArea> onContinue;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(43.6900, -79.3900),
            initialZoom: 10,
            minZoom: 7,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.bserv',
            ),
            MarkerLayer(
              markers: [
                for (final area in serviceAreas)
                  Marker(
                    key: ValueKey('service-area-${area.id}'),
                    point: area.center,
                    width: 96,
                    height: 96,
                    child: _ServiceAreaHotspot(
                      area: area,
                      selected: selectedArea?.id == area.id,
                      onTap: () => onAreaSelected(area),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(localizations.mapAttribution),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        localizations.selectServiceArea,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(localizations.tapServiceArea),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (selectedArea case final area?)
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
                          area.name(localizations),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('continue-service-area'),
                          onPressed: () => onContinue(area),
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
    final localizations = AppLocalizations.of(context)!;
    final fillColor = selected
        ? colorScheme.primary.withValues(alpha: 0.38)
        : colorScheme.primaryContainer.withValues(alpha: 0.58);

    // A generous fixed-size Material target makes each service-area circle easy to tap.
    return Tooltip(
      message: area.name(localizations),
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
