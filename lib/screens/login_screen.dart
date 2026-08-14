import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/app_text_field.dart';
import 'auth_flow.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await MockAuthApi.login(username, password);
      if (!mounted) return;

      final screen = await resolveHomeScreen(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.isUnauthorized ? 'Usuario o contraseña incorrectos' : e.message;
        _loading = false;
      });
    } on NoAccessException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo conectar con el servidor';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const _LogoPlaceholder(),
                  const SizedBox(height: 40),
                  Text('Iniciar sesión', style: AppTypography.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Entra para empezar tu turno',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    label: 'Usuario',
                    controller: _userCtrl,
                    hintText: 'abc123',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Contraseña',
                    controller: _passCtrl,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onSubmit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _loading ? null : _onSubmit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textoClaroAlto,
                            ),
                          )
                        : const Text('Entrar'),
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

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.azulControl.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.azulControl.withValues(alpha: 0.6),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'Comanda',
        style: AppTypography.plusJakarta(
          size: 26,
          weight: FontWeight.w800,
          color: AppColors.textoClaroAlto,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rojoAlerta.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.rojoAlerta.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.rojoAlerta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textoClaroAlto,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
