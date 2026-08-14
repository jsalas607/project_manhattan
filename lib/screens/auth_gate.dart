import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../core/session.dart';
import '../mock/mock_api.dart';
import 'auth_flow.dart';
import 'login_screen.dart';

/// Pantalla inicial: si hay una sesión guardada y sigue siendo válida,
/// entra directo a la sucursal/lista correspondiente. Si no, muestra login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final hadSession = await Session.restore();
    if (!hadSession) {
      _goToLogin();
      return;
    }
    try {
      final user = await MockAuthApi.me();
      final screen = await resolveHomeScreen(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    } catch (_) {
      // Token vencido/ inválido o sin acceso: limpiar y pedir login de nuevo.
      await Session.clear();
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.naranjaAccion),
      ),
    );
  }
}
