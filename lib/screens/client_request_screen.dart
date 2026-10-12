import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientRequestScreen extends StatefulWidget {
  const ClientRequestScreen({Key? key}) : super(key: key);

  @override
  State<ClientRequestScreen> createState() => _ClientRequestScreenState();
}

class _ClientRequestScreenState extends State<ClientRequestScreen> {
  int _selectedLiters = 2000;
  bool _isImmediate = true;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 2));
  final String _addressText = "Ñuñoa, Santiago (Ubicación de entrega)";
  bool _isSubmitting = false;

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
          'lat': -33.4560,
          'lng': -70.6480,
        },
        'isImmediate': _isImmediate,
        'scheduledFor': _isImmediate
            ? DateTime.now().toIso8601String()
            : _scheduledDate.toIso8601String(),
        'status': 'PENDING', // PENDING -> ACCEPTED -> IN_TRANSIT -> COMPLETED
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Solicitud de agua enviada con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar solicitud: $e')),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido cancelado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar el pedido: $e')),
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
            icon: const Icon(Icons.exit_to_app),
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

          // SI TIENE UN PEDIDO ACTIVO: Mostrar Pantalla de Seguimiento en Vivo (H6)
          if (activeOrders.isNotEmpty) {
            final activeOrder = activeOrders.first;
            final orderData = activeOrder.data() as Map<String, dynamic>;
            final String status = orderData['status'] ?? 'PENDING';
            final int liters = orderData['requestedLiters'] ?? 2000;

            return _buildActiveOrderView(activeOrder.id, status, liters, orderData);
          }

          // SI NO TIENE PEDIDOS ACTIVOS: Mostrar Formulario de Solicitud (H1)
          return _buildNewOrderForm();
        },
      ),
    );
  }

  // Vista H6: Tracking en Tiempo Real
  Widget _buildActiveOrderView(String orderId, String status, int liters, Map<String, dynamic> data) {
    String statusTitle = "Buscando Camión Aljibe...";
    String statusSubtitle = "Estamos asignando el camión más cercano a tu domicilio.";
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.search;

    if (status == 'ACCEPTED') {
      statusTitle = "¡Camión Aljibe Asignado!";
      statusSubtitle = "El chofer ha tomado tu pedido y va en camino.";
      statusColor = Colors.blue;
      statusIcon = Icons.local_shipping;
    } else if (status == 'IN_TRANSIT') {
      statusTitle = "Inyectando Agua en Estanque";
      statusSubtitle = "El camión está realizando la descarga en tu propiedad.";
      statusColor = Colors.green;
      statusIcon = Icons.water;
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
                          Text("$liters Litros", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Lugar de Entrega:", style: TextStyle(color: Colors.grey)),
                          Expanded(
                            child: Text(
                              _addressText,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Cancelación (Solo si aún está PENDING)
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

  // Vista H1: Formulario de Solicitud Inicial
  Widget _buildNewOrderForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Lugar de Entrega", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blueAccent),
                  title: Text(_addressText),
                ),
              ),
              const SizedBox(height: 24),

              const Text("Cantidad de Agua (Litros)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [2000, 5000, 10000].map((liters) {
                  final isSelected = _selectedLiters == liters;
                  return ChoiceChip(
                    label: Text("$liters L", style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedLiters = liters);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              const Text("¿Cuándo lo necesitas?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              RadioListTile<bool>(
                title: const Text("Lo antes posible"),
                value: true,
                groupValue: _isImmediate,
                onChanged: (val) => setState(() => _isImmediate = val!),
              ),
              RadioListTile<bool>(
                title: const Text("Programar entrega"),
                value: false,
                groupValue: _isImmediate,
                onChanged: (val) => setState(() => _isImmediate = val!),
              ),

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