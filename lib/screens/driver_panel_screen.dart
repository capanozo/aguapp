 import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverPanelScreen extends StatefulWidget {
  const DriverPanelScreen({Key? key}) : super(key: key);

  @override
  State<DriverPanelScreen> createState() => _DriverPanelScreenState();
}

class _DriverPanelScreenState extends State<DriverPanelScreen> {
  bool _isOnline = true;

  @override
  Widget build(BuildContext context) {
    final driverUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AguApp - Chofer Camión Aljibe'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: _isOnline ? Colors.green.shade50 : Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isOnline ? "EN LÍNEA (Disponible)" : "DESCONECTADO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
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
          Expanded(
            child: !_isOnline
                ? const Center(child: Text("Ponte en línea para recibir solicitudes."))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('water_orders')
                        .where('status', isEqualTo: 'PENDING')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text("No hay solicitudes pendientes."));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final orderData = docs[index].data() as Map<String, dynamic>;
                          final orderId = docs[index].id;

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        avatar: const Icon(Icons.water_drop, color: Colors.white, size: 16),
                                        label: Text("${orderData['requestedLiters']} L", style: const TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.blueAccent,
                                      ),
                                      const Text("\$44.000 CLP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Dirección: ${orderData['deliveryLocation']['addressText']}"),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () => _acceptOrder(orderId, driverUid),
                                      child: const Text("Tomar Pedido", style: TextStyle(color: Colors.white)),
                                    ),
                                  )
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

  Future<void> _acceptOrder(String orderId, String? driverUid) async {
    if (driverUid == null) return;

    try {
      await FirebaseFirestore.instance.collection('water_orders').doc(orderId).update({
        'assignedDriverId': driverUid,
        'status': 'ACCEPTED',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pedido asignado!')),
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
}
