 import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderCompletionScreen extends StatefulWidget {
  final String orderId;
  final int requestedLiters;
  final String clientName;

  const OrderCompletionScreen({
    Key? key,
    required this.orderId,
    required this.requestedLiters,
    required this.clientName,
  }) : super(key: key);

  @override
  State<OrderCompletionScreen> createState() => _OrderCompletionScreenState();
}

class _OrderCompletionScreenState extends State<OrderCompletionScreen> {
  late int _deliveredLiters;
  final int _pricePerLiter = 22; // $22 CLP por litro ($44.000 CLP los 2.000L)
  String _paymentMethod = 'CASH'; // 'CASH', 'TRANSFER', 'QR'
  int _rating = 5;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _deliveredLiters = widget.requestedLiters;
  }

  int get _totalAmount => _deliveredLiters * _pricePerLiter;

  Future<void> _completeOrder() async {
    setState(() => _isCompleting = true);

    try {
      await FirebaseFirestore.instance.collection('water_orders').doc(widget.orderId).update({
        'actualDeliveredLiters': _deliveredLiters,
        'totalAmountCLP': _totalAmount,
        'paymentMethod': _paymentMethod,
        'driverRating': _rating,
        'status': 'COMPLETED',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Entrega completada y cobro registrado exitosamente!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar el servicio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalizar Entrega de Agua'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Cliente
                Text("Cliente: ${widget.clientName}", 
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // 1. Ajuste de Litros Reales Inyectados
                const Text("Volumen Real Inyectado (Litros)", 
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 36, color: Colors.blueAccent),
                      onPressed: _deliveredLiters > 500
                          ? () => setState(() => _deliveredLiters -= 100)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        "$_deliveredLiters L",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 36, color: Colors.blueAccent),
                      onPressed: () => setState(() => _deliveredLiters += 100),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // 2. Cálculo Total en CLP
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total a Cobrar:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        "\$${_totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} CLP",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Medio de Pago
                const Text("Medio de Pago", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                RadioListTile<String>(
                  title: const Text("Efectivo"),
                  secondary: const Icon(Icons.payments_outlined, color: Colors.green),
                  value: 'CASH',
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                RadioListTile<String>(
                  title: const Text("Transferencia Bancaria"),
                  secondary: const Icon(Icons.account_balance_outlined, color: Colors.blue),
                  value: 'TRANSFER',
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                RadioListTile<String>(
                  title: const Text("Cobro mediante Código QR / Banco"),
                  secondary: const Icon(Icons.qr_code_2, color: Colors.purple),
                  value: 'QR',
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                const Divider(height: 32),

                // 4. Calificación
                const Text("Calificar Atención del Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 38,
                      ),
                      onPressed: () => setState(() => _rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Botón Cierre de Servicio
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _isCompleting ? null : _completeOrder,
                    child: _isCompleting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirmar Cobro y Finalizar', style: TextStyle(fontSize: 18, color: Colors.white)),
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