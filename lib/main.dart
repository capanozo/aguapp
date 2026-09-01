import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicialización de Firebase
  // Nota: Requiere configurar firebase_options.dart o la consola web
  runApp(const AguApp());
}

class AguApp extends StatelessWidget {
  const AguApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AguApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// Control de flujo de autenticación en vivo
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

// Pantalla de Login / Registro
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';
  String _name = '';
  String _phone = '';
  String _role = 'client'; // 'client' o 'driver'
  int _truckCapacity = 2000;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Iniciar Sesión
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.trim(),
          password: _password.trim(),
        );
      } else {
        // Registrar Nuevo Usuario
        UserCredential creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.trim(),
          password: _password.trim(),
        );

        // Guardar perfil detallado en Firestore
        await FirebaseFirestore.instance.collection('users').doc(creds.user!.uid).set({
          'uid': creds.user!.uid,
          'name': _name.trim(),
          'email': _email.trim(),
          'phone': _phone.trim(),
          'role': _role, // 'client' o 'driver'
          'truckCapacityLiters': _role == 'driver' ? _truckCapacity : null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error de autenticación')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.water_drop_rounded, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 8),
                  const Text(
                    "AguApp",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLogin ? "Bienvenido de vuelta" : "Crea tu cuenta de servicio",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  if (!_isLogin) ...[
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Nombre Completo", border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? "Ingresa tu nombre" : null,
                      onSaved: (v) => _name = v!,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Teléfono (+569...)", border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.isEmpty ? "Ingresa tu teléfono" : null,
                      onSaved: (v) => _phone = v!,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(labelText: "Tipo de Perfil", border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'client', child: Text("Cliente (Solicitar Agua)")),
                        DropdownMenuItem(value: 'driver', child: Text("Chofer / Repartidor (Camión Aljibe)")),
                      ],
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_role == 'driver') ...[
                      TextFormField(
                        initialValue: "2000",
                        decoration: const InputDecoration(labelText: "Capacidad del Estanque (Litros)", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _truckCapacity = int.tryParse(v ?? '2000') ?? 2000,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  TextFormField(
                    decoration: const InputDecoration(labelText: "Correo Electrónico", border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? "Correo inválido" : null,
                    onSaved: (v) => _email = v!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? "Mínimo 6 caracteres" : null,
                    onSaved: (v) => _password = v!,
                  ),
                  const SizedBox(height: 24),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _submit,
                          child: Text(_isLogin ? "Iniciar Sesión" : "Crear Cuenta", style: const TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                  
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? "¿No tienes cuenta? Regístrate aquí" : "¿Ya tienes cuenta? Inicia sesión"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla Principal (Placeholder según el Rol)
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AguApp"),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Perfil no encontrado."));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final bool isDriver = userData['role'] == 'driver';

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isDriver ? Icons.local_shipping : Icons.water_drop, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                Text("¡Hola, ${userData['name']}!", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("Perfil: ${isDriver ? 'Chofer de Camión Aljibe' : 'Cliente'}", style: const TextStyle(color: Colors.grey)),
                if (isDriver) Text("Capacidad: ${userData['truckCapacityLiters']} Litros"),
              ],
            ),
          );
        },
      ),
    );
  }
}
