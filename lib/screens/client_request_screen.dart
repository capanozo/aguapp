import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/map_picker_widget.dart';
import 'order_history_screen.dart';

class ClientRequestScreen extends StatefulWidget {
  const ClientRequestScreen({Key? key}) : super(key: key);

  @override
  State<ClientRequestScreen> createState() => _ClientRequestScreenState();
}

class _ClientRequestScreenState extends State<ClientRequestScreen> {
  // Variables de Ubicación y Estado
  LatLng _selectedLatLng = const LatLng(-33.4560, -70.6480);
  String _addressText = "Ubicación fijada en el mapa";

  int _selectedLiters = 2000;
  bool _isImmediate = true;
  DateTime _scheduledDateTime = DateTime.now().add(const Duration(hours: 2));
  bool _isSubmitting = false;

  // Evita el bucle infinito de re-renderizado al mover el mapa
  void _updateSelectedPosition(LatLng position, String address) {
    if ((_selectedLatLng.latitude - position.latitude).abs() < 0.00001 &&
        (_selectedLatLng.longitude - position.longitude).abs() < 0.00001 &&
        _addressText == address) {
      return;
    }

    setState(() {
      _selectedLatLng = position;
      _addressText = address;
    });
  }

  Future<void> _selectScheduledDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _scheduledDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _createOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('water_orders').add({
        'clientId': user.uid,
        'requestedLiters': _selectedLiters,
        'actualDeliveredLiters': _selectedLiters,
        'deliveryLocation': {
          'addressText': _addressText,
          'lat': _selectedLatLng.latitude,
          'lng': _selectedLatLng.longitude,
        },
        'isImmediate': _isImmediate,
        'scheduledFor': _isImmediate
            ? DateTime.now().toIso8601String()
            : _scheduledDateTime.toIso8601String(),
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud de agua enviada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('water_orders').doc(orderId).update({
        'status': 'CANCELLED_BY_CLIENT',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AguApp - Cliente'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de Pedidos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryScreen(userRole: 'client'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Cerrar Sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('water_orders')
            .where('clientId', isEqualTo: user?.uid)
            .where('status', whereIn: ['PENDING', 'ACCEPTED', 'IN_TRANSIT'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeOrders = snapshot.data?.docs ?? [];

          // Si hay un pedido activo -> Vista de Seguimiento en Tiempo Real (Uber Style)
          if (activeOrders.isNotEmpty) {
            final activeOrder = activeOrders.first;
            final orderData = activeOrder.data() as Map<String, dynamic>;
            return _buildTrackingView(activeOrder.id, orderData);
          }

          // Si no hay pedido activo -> Formulario de Solicitud
          return _buildNewOrderForm();
        },
      ),
    );
  }

  // Vista de Seguimiento en Vivo
  Widget _buildTrackingView(String orderId, Map<String, dynamic> data) {
    final String status = data['status'] ?? 'PENDING';
    final int liters = data['requestedLiters'] ?? 2000;
    final String address = data['deliveryLocation']?['addressText'] ?? 'Estanque fijado en mapa';

    String statusTitle = "Buscando Camión Aljibe...";
    String statusSubtitle = "Estamos asignando el camión más cercano a tu ubicación.";
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.search;

    if (status == 'ACCEPTED') {
      statusTitle = "¡Camión Aljibe Asignado!";
      statusSubtitle = "El chofer aceptó tu servicio y va en camino al estanque.";
      statusColor = Colors.blue;
      statusIcon = Icons.local_shipping;
    } else if (status == 'IN_TRANSIT') {
      statusTitle = "Descargando Agua";
      statusSubtitle = "El camión está inyectando agua en tu estanque.";
      statusColor = Colors.green;
      statusIcon = Icons.water_drop;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: statusColor.withOpacity(0.15),
                        child: Icon(statusIcon, color: statusColor, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        statusTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusSubtitle,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Volumen Pedido:", style: TextStyle(color: Colors.grey)),
                          Text("$liters L", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Dirección:", style: TextStyle(color: Colors.grey)),
                          Expanded(
                            child: Text(
                              address,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (status == 'PENDING')
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _cancelOrder(orderId),
                    child: const Text('Cancelar Solicitud', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Formulario con Selección de Estanque en Mapa y Agendamiento
  Widget _buildNewOrderForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Ubicación del Estanque en el Mapa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              
              // Dentro de _buildNewOrderForm() en client_request_screen.dart:
              MapPickerWidget(
                key: const ValueKey('aguapp_persistent_map_picker'), // <--- Clave fija que congela el estado del mapa en memoria
                initialPosition: _selectedLatLng,
                onPositionSelected: _updateSelectedPosition,
              ),
            
              const SizedBox(height: 16),

              const Text("Cantidad de Agua (Litros)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [2000, 5000, 10000].map((liters) {
                  final isSelected = _selectedLiters == liters;
                  return ChoiceChip(
                    label: Text(
                      "$liters L",
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedLiters = liters);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              const Text("¿Cuándo necesitas la entrega?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              RadioListTile<bool>(
                title: const Text("Lo antes posible (Inmediato)"),
                value: true,
                groupValue: _isImmediate,
                onChanged: (bool? val) {
                  if (val != null) setState(() => _isImmediate = val);
                },
              ),
              RadioListTile<bool>(
                title: const Text("Programar fecha y hora"),
                value: false,
                groupValue: _isImmediate,
                onChanged: (bool? val) {
                  if (val != null) setState(() => _isImmediate = val);
                },
              ),

              if (!_isImmediate) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                    title: Text(
                      "Programado para: ${_scheduledDateTime.day}/${_scheduledDateTime.month}/${_scheduledDateTime.year} - ${_scheduledDateTime.hour}:${_scheduledDateTime.minute.toString().padLeft(2, '0')} hrs",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: TextButton(
                      onPressed: _selectScheduledDateTime,
                      child: const Text("Cambiar"),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSubmitting ? null : _createOrder,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirmar Pedido', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}