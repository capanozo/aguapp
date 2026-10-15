 import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package0:google_maps_flutter/google_maps_flutter.dart';

class MapPickerWidget extends StatefulWidget {
  final LatLng initialPosition;
  final Function(LatLng position, String address) onPositionSelected;

  const MapPickerWidget({
    Key? key,
    required this.initialPosition,
    required this.onPositionSelected,
  }) : super(key: key);

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  late LatLng _currentPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Mapa con captura inmediata de gestos para Web y Móvil
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 15.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              // OBLIGATORIO EN WEB: Evita que el scroll de la página bloquee el arrastre del mapa
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onCameraMove: (position) {
                _currentPosition = position.target;
              },
              onCameraIdle: () {
                final String lat = _currentPosition.latitude.toStringAsFixed(5);
                final String lng = _currentPosition.longitude.toStringAsFixed(5);
                final String locationLabel = "Estanque fijado ($lat, $lng)";
                
                // Notifica al formulario del cliente la nueva ubicación exacta
                widget.onPositionSelected(_currentPosition, locationLabel);
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),

            // Pin Fijo en el Centro (Estilo Uber)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 48,
                ),
              ),
            ),

            // Botón de Controles de Zoom para facil uso en Web
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: "zoom_in",
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.add, color: Colors.blueAccent),
                    onPressed: () {
                      _mapController?.animateCamera(CameraUpdate.zoomIn());
                    },
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: "zoom_out",
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.remove, color: Colors.blueAccent),
                    onPressed: () {
                      _mapController?.animateCamera(CameraUpdate.zoomOut());
                    },
                  ),
                ],
              ),
            ),

            // Banner indicativo superior
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app, size: 16, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Mueve el mapa hasta centrar el estanque de tu casa",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}