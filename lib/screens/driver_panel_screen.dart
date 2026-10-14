import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_completion_screen.dart';
import 'order_history_screen.dart';

class DriverPanelScreen extends StatefulWidget {
  const DriverPanelScreen({Key? key}) : super(key: key);

  @override
  State<DriverPanelScreen> createState() => _DriverPanelScreenState();
}

class _DriverPanelScreenState extends State<DriverPanelScreen> {
  bool _isOnline = true;

  Future<void> _acceptOrder(String orderId, String driverUid) async {
    try {
      await FirebaseFirestore.instance.collection('water_orders').doc(orderId).update({
        'status': 'ACCEPTED',
        'assignedDriverId': driverUid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido asignado! Inicia el traslado al domicilio.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al tomar el pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = FirebaseAuth.instance.currentUser;
    final driverUid = driver?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AguApp - Panel Chofer'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de Servicios',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryScreen(userRole: 'driver'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Cerrar Sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Switch de Disponibilidad (Estilo Uber Driver)
          Container(
            color: _isOnline ? Colors.green.shade50 : Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: _isOnline ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isOnline ? "EN LÍNEA - Recibiendo Pedidos" : "FUERA DE SERVICIO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _isOnline ? Colors.green.shade900 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isOnline,
                  activeColor: Colors.green.shade700,
                  onChanged: (val) => setState(() => _isOnline = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Pedidos en Tiempo Real
          Expanded(
            child: !_isOnline
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_settings_new, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          "Ponte 'EN LÍNEA' para recibir solicitudes de agua.",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('water_orders')
                        .where('status', whereIn: ['PENDING', 'ACCEPTED', 'IN_TRANSIT'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text("Error al cargar pedidos: ${snapshot.error}"),
                        );
                      }

                      final allOrders = snapshot.data?.docs ?? [];

                      // Filtrar pedidos:
                      // 1. Pedidos PENDING (Disponibles para cualquier chofer)
                      // 2. Pedidos ACCEPTED/IN_TRANSIT asignados explícitamente a ESTE chofer
                      final visibleOrders = allOrders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'];
                        final assignedDriverId = data['assignedDriverId'];

                        if (status == 'PENDING') return true;
                        if ((status == 'ACCEPTED' || status == 'IN_TRANSIT') &&
                            assignedDriverId == driverUid) {
                          return true;
                        }
                        return false;
                      }).toList();

                      if (visibleOrders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                "No hay pedidos pendientes en tu zona.",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleOrders.length,
                        itemBuilder: (context, index) {
                          final orderData = visibleOrders[index].data() as Map<String, dynamic>;
                          final orderId = visibleOrders[index].id;
                          final status = orderData['status'] ?? 'PENDING';
                          final requestedLiters = orderData['requestedLiters'] ?? 2000;
                          final isMyAcceptedOrder = (status == 'ACCEPTED' || status == 'IN_TRANSIT');

                          final double lat = (orderData['deliveryLocation']?['lat'] as num?)?.toDouble() ?? -33.4560;
                          final double lng = (orderData['deliveryLocation']?['lng'] as num?)?.toDouble() ?? -70.6480;
                          final String addressText = orderData['deliveryLocation']?['addressText'] ?? 'Ñuñoa, Santiago';

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Encabezado con Litros y Estado
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        avatar: const Icon(Icons.water_drop, color: Colors.white, size: 16),
                                        label: Text(
                                          "$requestedLiters L",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: Colors.blueAccent,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isMyAcceptedOrder ? Colors.blue.shade100 : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isMyAcceptedOrder ? "EN CURSO" : "DISPONIBLE",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isMyAcceptedOrder ? Colors.blue.shade900 : Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Dirección
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          addressText,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Botones de Acción
                                  if (status == 'PENDING')
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () => _acceptOrder(orderId, driverUid),
                                        child: const Text(
                                          "Tomar Pedido",
                                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    )
                                  else if (isMyAcceptedOrder) ...[
                                    // 1. Navegación GPS (Google Maps)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.navigation_outlined, color: Colors.white),
                                        label: const Text(
                                          "Navegar con GPS",
                                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade900,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          final Uri googleMapsUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
                                          // Se puede abrir directo vía URL launcher
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // 2. Finalizar y Cobrar (H3)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                                        label: const Text(
                                          "Finalizar y Cobrar",
                                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => OrderCompletionScreen(
                                                orderId: orderId,
                                                requestedLiters: requestedLiters,
                                                clientName: "Cliente AguApp",
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 