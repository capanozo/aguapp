import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

class _MapPickerWidgetState extends State<MapPickerWidget> with AutomaticKeepAliveClientMixin {
  // Evita que Flutter destruya el widget al redibujar el formulario
  @override
  bool get wantKeepAlive => true;

  GoogleMapController? _mapController;

  // Estado del Mapa
  late LatLng _currentPosition;
  double _currentZoom = 15.0;
  
  // Banderas de control
  bool _hasUserDraggedMap = false;
  bool _hasInitialGpsCentered = false;
  bool _isLoadingGPS = false;
  bool _isSearching = false;

  LatLng? _lastNotifiedPosition;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _fetchGpsLocationOnce();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. GPS SOLAMENTE UNA VEZ AL INICIAR
  Future<void> _fetchGpsLocationOnce() async {
    if (_hasInitialGpsCentered || _hasUserDraggedMap) return;
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

      // Si el usuario no ha arrastrado el mapa manualmente, centramos
      if (mounted && !_hasUserDraggedMap && !_hasInitialGpsCentered) {
        _hasInitialGpsCentered = true;
        final userLatLng = LatLng(position.latitude, position.longitude);

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

  // 2. BÚSQUEDA POR TEXTO (GEOCODING)
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      // Uso de Geocoding libre de bloqueo CORS
      final String encodedAddress = Uri.encodeComponent(query);
      final Uri url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1",
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'AguApp_WaterDelivery_App'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat']);
          final double lng = double.parse(data[0]['lon']);
          final newLatLng = LatLng(lat, lng);

          _hasUserDraggedMap = true; // Bloquea sobreescrituras de GPS

          setState(() {
            _currentPosition = newLatLng;
            _currentZoom = 14.5;
          });

          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newLatLng, _currentZoom),
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se encontró la ubicación. Intenta con "Comuna, Ciudad" (ej: Tongoy)'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la búsqueda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // CONTROLES DE ZOOM
  void _zoomIn() {
    _hasUserDraggedMap = true;
    _currentZoom += 1.0;
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _hasUserDraggedMap = true;
    _currentZoom -= 1.0;
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin

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
              onCameraMoveStarted: () {
                // Marca inmediatamente que el usuario tomó el control manual del mapa
                _hasUserDraggedMap = true;
              },
              onCameraMove: (position) {
                _currentPosition = position.target;
                _currentZoom = position.zoom;
              },
              onCameraIdle: () {
                // Solo notifica al padre si el desplazamiento es mayor a la tolerancia de ruido
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

            // BARRA DE BÚSQUEDA DE CIUDAD O DIRECCIÓN
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
                          hintText: "Escribe ciudad o dirección (ej. Tongoy)...",
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

            // BOTÓN RE-CENTRAR GPS
            Positioned(
              left: 14,
              bottom: 14,
              child: FloatingActionButton.small(
                heroTag: "btn_gps_location",
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: () {
                  _hasUserDraggedMap = false;
                  _hasInitialGpsCentered = false;
                  _fetchGpsLocationOnce();
                },
                child: const Icon(Icons.my_location, color: Colors.blueAccent),
              ),
            ),

            // BOTONES DE ZOOM (+ / -)
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

            // INDICADOR DE CARGA GPS
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