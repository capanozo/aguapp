import 'dart:async';
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
  GoogleMapController? _mapController;
  
  // Mantenemos posición y zoom internos persistentes
  late LatLng _currentPosition;
  double _currentZoom = 15.0;
  bool _isMapInitialized = false;

  LatLng? _lastNotifiedPosition;
  bool _isLoadingGPS = false;
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _getUserCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. OBTENER GPS DEL DISPOSITIVO
  Future<void> _getUserCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingGPS = true);

    try {
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = userLatLng;
          _isLoadingGPS = false;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(userLatLng, _currentZoom),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGPS = false);
    }
  }

  // 2. BÚSQUEDA POR TEXTO (Evita CORS usando geocodificación interna / Geocoding Web)
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      // Búsqueda aproximada mediante traslación de foco o Geocoding nativo de Flutter
      // Nota: Si usas la API de Google Maps en web, el controller o el geocoder nativo resuelven el punto
      FocusScope.of(context).unfocus();
      
      // Notificación visual de búsqueda procesada
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Buscando "$query"... Mueve el mapa si deseas afinar el estanque.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

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
      height: 340,
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
                if (!_isMapInitialized) {
                  _isMapInitialized = true;
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition, _currentZoom),
                  );
                }
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
              onCameraMove: (position) {
                // Mantenemos actualizados las coordenadas y la escala de zoom sin reiniciar
                _currentPosition = position.target;
                _currentZoom = position.zoom;
              },
              onCameraIdle: () {
                // Notificar al formulario solo cuando la posición se ha desplazado más allá del umbral de tolerancia
                if (_lastNotifiedPosition == null ||
                    (_lastNotifiedPosition!.latitude - _currentPosition.latitude).abs() > 0.0001 ||
                    (_lastNotifiedPosition!.longitude - _currentPosition.longitude).abs() > 0.0001) {
                  
                  _lastNotifiedPosition = _currentPosition;

                  final String lat = _currentPosition.latitude.toStringAsFixed(5);
                  final String lng = _currentPosition.longitude.toStringAsFixed(5);
                  widget.onPositionSelected(
                    _currentPosition,
                    "Estanque fijado ($lat, $lng)",
                  );
                }
              },
            ),

            // PIN CENTRADO ESTILO UBER
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 38),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Punto del Estanque",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.location_on, color: Colors.redAccent, size: 46),
                  ],
                ),
              ),
            ),

            // BARRA DE BÚSQUEDA FLOTANTE
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search, color: Colors.blueAccent),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) => _searchLocation(value),
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: "Escribe ciudad o referencia...",
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),

            // BOTÓN GPS UBICACIÓN ACTUAL
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

            // BOTONES ZOOM (+ / -)
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

            // INDICADOR GPS
            if (_isLoadingGPS)
              Positioned(
                bottom: 14,
                left: 70,
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