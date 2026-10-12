import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderHistoryScreen extends StatelessWidget {
  final String userRole; // 'client' o 'driver'

  const OrderHistoryScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Consulta adaptativa según el rol del usuario
    final Query baseQuery = FirebaseFirestore.instance.collection('water_orders');
    final Query query = (userRole == 'driver')
        ? baseQuery.where('assignedDriverId', isEqualTo: user?.uid)
        : baseQuery.where('clientId', isEqualTo: user?.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(userRole == 'driver' ? 'Mis Servicios Entregados' : 'Mis Pedidos de Agua'),
        backgroundColor: userRole == 'driver' ? Colors.green.shade700 : Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Para ordenar por fecha en el historial se requiere un índice en Firestore.\nPuedes revisar la consola o aguardar la indexación.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Filtrar solo pedidos finalizados o cancelados (los activos van en la pantalla principal)
          final historyDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            return status == 'COMPLETED' || status.toString().startsWith('CANCELLED');
          }).toList();

          if (historyDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes pedidos registrados en tu historial.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyDocs.length,
            itemBuilder: (context, index) {
              final data = historyDocs[index].data() as Map<String, dynamic>;
              final String status = data['status'] ?? 'COMPLETED';
              final int liters = data['actualDeliveredLiters'] ?? data['requestedLiters'] ?? 2000;
              final int totalAmount = data['totalAmountCLP'] ?? (liters * 22);
              final String paymentMethod = data['paymentMethod'] ?? 'EFECTIVO';
              final Timestamp? createdAt = data['createdAt'] as Timestamp?;

              final bool isCompleted = status == 'COMPLETED';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle : Icons.cancel,
                                color: isCompleted ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isCompleted ? "ENTREGA COMPLETADA" : "CANCELADO",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "\$${totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} CLP",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water_drop, color: Colors.blueAccent, size: 18),
                              const SizedBox(width: 4),
                              Text("$liters Litros", style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.payment, color: Colors.grey, size: 18),
                              const SizedBox(width: 4),
                              Text("Pago: $paymentMethod", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['deliveryLocation']?['addressText'] ?? 'Ñuñoa, Santiago',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Fecha: ${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} - ${createdAt.toDate().hour}:${createdAt.toDate().minute.toString().padLeft(2, '0')} hrs",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
    );
  }
}