import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_completion_screen.dart';
import 'order_history_screen.dart';

class DriverPanelScreen extends StatefulWidget {
  const DriverPanelScreen({Key? key}) : super(key: key);

  @override
  State<DriverPanelScreen> createState() => _DriverPanelScreenState();
}

class _DriverPanelScreenState extends State<DriverPanelScreen> {
  bool _isOnline = true;

  Future<void> _acceptOrder(String orderId, String? driverUid) async {
    if (driverUid == null) return;

    try {
      await FirebaseFirestore.instance.collection('water_orders').doc(orderId).update({
        'assignedDriverId': driverUid,
        'status': 'ACCEPTED',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pedido asignado a tu camión!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar pedido: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AguApp - Chofer Camión Aljibe'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey.shade700,
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
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          // Barra de estado En Línea / Offline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: _isOnline ? Colors.green.shade50 : Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isOnline ? "ESTÁS EN LÍNEA (Disponible)" : "DESCONECTADO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _isOnline ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
                Switch(
                  value: _isOnline,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => _isOnline = val),
                ),
              ],
            ),
          ),

          // Lista de Pedidos en Tiempo Real
          Expanded(
            child: !_isOnline
                ? const Center(
                    child: Text(
                      "Ponte en línea para recibir solicitudes de agua.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('water_orders')
                        .where('status', whereIn: ['PENDING', 'ACCEPTED'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text("Error al cargar datos: ${snapshot.error}"));
                      }

                      final docs = snapshot.data?.docs ?? [];

                      // Filtrar pedidos visibles para este chofer
                      final visibleOrders = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'];
                        final assignedDriverId = data['assignedDriverId'];

                        // Mostrar si está PENDING o si está ACCEPTED por este mismo chofer
                        if (status == 'PENDING') return true;
                        if (status == 'ACCEPTED' && assignedDriverId == driverUid) return true;
                        return false;
                      }).toList();

                      if (visibleOrders.isEmpty) {
                        return const Center(
                          child: Text(
                            "No hay solicitudes pendientes en tu zona.",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleOrders.length,
                        // ... dentro de tu ListView.builder en DriverPanelScreen
                        itemBuilder: (context, index) {
                          final orderData = visibleOrders[index].data() as Map<String, dynamic>;
                          final orderId = visibleOrders[index].id;
                          final status = orderData['status'] ?? 'PENDING';
                          final requestedLiters = orderData['requestedLiters'] ?? 2000;
                          final isMyAcceptedOrder = status == 'ACCEPTED';

                          // Coordenadas fijadas por el cliente en el mapa (H8)
                          final double lat = orderData['deliveryLocation']?['lat'] ?? -33.4560;
                          final double lng = orderData['deliveryLocation']?['lng'] ?? -70.6480;

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Datos del Pedido
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        avatar: const Icon(Icons.water_drop, color: Colors.white, size: 16),
                                        label: Text("$requestedLiters L", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        backgroundColor: Colors.blueAccent,
                                      ),
                                      Text(
                                        isMyAcceptedOrder ? "EN CURSO" : "DISPONIBLE",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isMyAcceptedOrder ? Colors.blue.shade800 : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text("Dirección: ${orderData['deliveryLocation']?['addressText'] ?? 'N/I'}"),
                                  const SizedBox(height: 16),

                                  // -----------------------------------------------------------------
                                  // BLOQUE DE ACCIONES SEGÚN ESTADO (AQUÍ VA LA NAVEGACIÓN GPS)
   // ... dentro de la Column de la Card en DriverPanelScreen
          if (status == 'PENDING')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _acceptOrder(orderId, driverUid),
                child: const Text("Tomar Pedido", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          else if (isMyAcceptedOrder) ...[
            // 1. NAVEGACIÓN GPS (H8)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_outlined, color: Colors.white),
                label: const Text("Navegar con GPS", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final double lat = orderData['deliveryLocation']?['lat'] ?? -33.4560;
                  final double lng = orderData['deliveryLocation']?['lng'] ?? -70.6480;
                  final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
                  // Abrir enlace a Google Maps
                },
              ),
            ),
            const SizedBox(height: 10),

            // 2. FINALIZAR Y COBRAR (H3)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text("Finalizar y Cobrar", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                         // -----------------------------------------------------------------



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