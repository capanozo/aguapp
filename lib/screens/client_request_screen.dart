
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
  String _addressText = "Ñuñoa, Santiago (Ubicación de entrega)";
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
        'status': 'PENDING', // PENDING -> ACCEPTED -> COMPLETED
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AguApp - Solicitar Agua'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: SingleChildScrollView(
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
                      label: Text("$liters L", style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: _isSubmitting ? null : _createOrder,
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirmar Pedido', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}