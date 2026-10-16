import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // <--- Import del GPS

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
  bool _isLoadingGPS = true;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _getUserCurrentLocation(); // <--- Obtener posición inicial vía GPS
  }

  // Función para obtener las coordenadas actuales del dispositivo
  Future<void> _getUserCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verificar si los servicios de ubicación están habilitados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingGPS = false);
      return;
    }

    // 2. Gestionar Permisos de Geolocalización
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingGPS = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingGPS = false);
      return;
    }

    // 3. Obtener Posición Actual del GPS
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = userLatLng;
          _isLoadingGPS = false;
        });

        // Mover la cámara del mapa con animación suave
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(userLatLng, 16.0),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGPS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.shade200, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 15.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              },
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomControlsEnabled: false,
              myLocationEnabled: true, // Muestra el punto azul de ubicación actual
              myLocationButtonEnabled: false,
              onCameraMove: (position) {
                _currentPosition = position.target;
              },
              onCameraIdle: () {
                final String lat = _currentPosition.latitude.toStringAsFixed(5);
                final String lng = _currentPosition.longitude.toStringAsFixed(5);
                widget.onPositionSelected(_currentPosition, "Estanque fijado ($lat, $lng)");
              },
            ),

            // Pin Fijo en el Centro estilo Uber
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 38),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Punto de Entrega",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.location_on, color: Colors.redAccent, size: 46),
                  ],
                ),
              ),
            ),

            // Botón estilo Uber para "Centrar en mi ubicación actual"
            Positioned(
              left: 14,
              bottom: 14,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                  tooltip: "Ubicación actual",
                  onPressed: _getUserCurrentLocation,
                ),
              ),
            ),

            // Botones de Zoom (+ / -)
            Positioned(
              right: 14,
              bottom: 14,
              child: Column(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.blueAccent),
                      onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: IconButton(
                      icon: const Icon(Icons.remove, color: Colors.blueAccent),
                      onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                    ),
                  ),
                ],
              ),
            ),

            // Indicador discreto mientras el GPS posiciona
            if (_isLoadingGPS)
              Positioned(
                top: 50,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text("Obteniendo GPS...", style: TextStyle(color: Colors.white, fontSize: 11)),
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