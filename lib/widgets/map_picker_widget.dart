import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
  double _currentZoom = 15.0; // Preserva el zoom seleccionado por el usuario
  GoogleMapController? _mapController;
  bool _isLoadingGPS = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
  }

  Future<void> _getUserCurrentLocation() async {
    setState(() => _isLoadingGPS = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingGPS = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
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

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        _currentPosition = userLatLng;
        _currentZoom = 15.0; // Zoom adecuado al ubicar por GPS
        _isLoadingGPS = false;
        setState(() {});

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(userLatLng, _currentZoom),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGPS = false);
    }
  }

  // Controles de Zoom que actualizan la variable interna
  Future<void> _zoomIn() async {
    if (_mapController != null) {
      _currentZoom += 1.0;
      await _mapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  Future<void> _zoomOut() async {
    if (_mapController != null) {
      _currentZoom -= 1.0;
      await _mapController!.animateCamera(CameraUpdate.zoomOut());
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
                zoom: _currentZoom,
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
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              // Guarda tanto las coordenadas como el zoom exacto donde el usuario soltó la cámara
              onCameraMove: (position) {
                _currentPosition = position.target;
                _currentZoom = position.zoom; 
              },
              onCameraIdle: () {
                final String lat = _currentPosition.latitude.toStringAsFixed(5);
                final String lng = _currentPosition.longitude.toStringAsFixed(5);
                widget.onPositionSelected(
                  _currentPosition,
                  "Estanque fijado ($lat, $lng)",
                );
              },
            ),

            // Pin Fijo en el Centro (Estilo Uber)
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

            // Botón GPS
            Positioned(
              left: 14,
              bottom: 14,
              child: FloatingActionButton.small(
                heroTag: "btn_gps_location",
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: _getUserCurrentLocation,
                child: const Icon(Icons.my_location, color: Colors.blueAccent),
              ),
            ),

            // Botones Zoom
            Positioned(
              right: 14,
              bottom: 14,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: "btn_zoom_in",
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _zoomIn,
                    child: const Icon(Icons.add, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: "btn_zoom_out",
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _zoomOut,
                    child: const Icon(Icons.remove, color: Colors.blueAccent),
                  ),
                ],
              ),
            ),

            if (_isLoadingGPS)
              Positioned(
                top: 10,
                left: 10,
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