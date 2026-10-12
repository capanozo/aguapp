import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedTab = 0; // 0: Pedidos, 1: Flota/Choferes, 2: Métricas

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AguApp - Torre de Control / Admin'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Row(
        children: [
          // Menú Lateral de Operaciones
          NavigationRail(
            selectedIndex: _selectedTab,
            onDestinationSelected: (int index) {
              setState(() => _selectedTab = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.blueGrey.shade50,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping, color: Colors.blueAccent),
                label: Text('Pedidos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge, color: Colors.blueAccent),
                label: Text('Flota / Choferes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart, color: Colors.blueAccent),
                label: Text('Métricas'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Vistas Principales
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildOrdersView(),
                _buildDriversView(),
                _buildMetricsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Monitor de Pedidos en Vivo
  Widget _buildOrdersView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('water_orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No existen registros de pedidos aún."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'PENDING';

            Color statusColor = Colors.orange;
            if (status == 'ACCEPTED') statusColor = Colors.blue;
            if (status == 'COMPLETED') statusColor = Colors.green;
            if (status.toString().startsWith('CANCELLED')) statusColor = Colors.red;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(Icons.water_drop, color: statusColor),
                ),
                title: Text("Pedido #${docs[index].id.substring(0, 6)} - ${data['requestedLiters'] ?? 2000} L"),
                subtitle: Text("Estado: $status | Dirección: ${data['deliveryLocation']?['addressText'] ?? 'N/I'}"),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'CANCEL') {
                      FirebaseFirestore.instance
                          .collection('water_orders')
                          .doc(docs[index].id)
                          .update({'status': 'CANCELLED_BY_ADMIN'});
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'CANCEL',
                      child: Text('Anular Pedido (Admin)', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Control de Flota y Choferes
  Widget _buildDriversView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final drivers = snapshot.data!.docs;

        if (drivers.isEmpty) {
          return const Center(child: Text("No hay choferes registrados en la plataforma."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blueGrey),
                title: Text(driver['name'] ?? 'Chofer sin nombre'),
                subtitle: Text("Email: ${driver['email'] ?? 'N/I'}"),
                trailing: Chip(
                  label: Text("${driver['truckCapacityLiters'] ?? 2000} L"),
                  backgroundColor: Colors.blue.shade100,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. Métricas Financieras y de Operación
  Widget _buildMetricsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('water_orders')
          .where('status', isEqualTo: 'COMPLETED')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final completedOrders = snapshot.data!.docs;

        int totalLitersDelivered = 0;
        int totalRevenueCLP = 0;

        for (var doc in completedOrders) {
          final data = doc.data() as Map<String, dynamic>;
          totalLitersDelivered += (data['actualDeliveredLiters'] as int? ?? 0);
          totalRevenueCLP += (data['totalAmountCLP'] as int? ?? 0);
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Resumen Global de Operaciones", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _metricCard("Litros Despachados", "$totalLitersDelivered L", Icons.water, Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _metricCard("Ingresos Totales", "\$$totalRevenueCLP CLP", Icons.attach_money, Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _metricCard("Servicios Completados", "${completedOrders.length}", Icons.check_circle, Colors.purple),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}