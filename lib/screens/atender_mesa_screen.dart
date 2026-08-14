import 'package:flutter/material.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import 'add_mesa_screen.dart';
import 'mesa_detalle_screen.dart';

class AtenderMesaScreen extends StatefulWidget {
  const AtenderMesaScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<AtenderMesaScreen> createState() => _AtenderMesaScreenState();
}

class _AtenderMesaScreenState extends State<AtenderMesaScreen> {
  List<Mesa>  _mesas     = [];
  Set<String> _atendidas = {}; // mesaIds con todos los ítems listos
  bool        _loading   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mesas     = await MockAtenderMesaApi.getMesas(widget.restaurant.id);
    final atendidas =
        await MockPedidosApi.getMesasAtendidas(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _mesas     = mesas;
      _atendidas = atendidas;
      _loading   = false;
    });
  }

  Future<void> _goToAddMesa() async {
    final result = await Navigator.push<AddMesaResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMesaScreen(
          restaurant: widget.restaurant,
          user:       widget.user,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _mesas = [..._mesas, result.mesa]);

    // Si ya venía con ítems en la orden, ir directo al detalle de la mesa
    if (result.orden.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MesaDetalleScreen(
            mesa:         result.mesa,
            restaurant:   widget.restaurant,
            user:         widget.user,
            ordenInicial: result.orden,
          ),
        ),
      );
    }
  }

  Future<void> _onTapMesa(Mesa mesa) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MesaDetalleScreen(
          mesa:       mesa,
          restaurant: widget.restaurant,
          user:       widget.user,
        ),
      ),
    );
    // Al volver, recargar siempre: la mesa pudo cobrarse (desaparece) o
    // cambiar de estado (la orden se editó).
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Atender mesa', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.naranjaAccion))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Usuario + sucursal
                  RestaurantHeader(
                      restaurant: widget.restaurant, user: widget.user),
                  const SizedBox(height: 24),

                  // Grid mesas + añadir
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:   2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing:  14,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _mesas.length + 1, // +1 para el botón añadir
                    itemBuilder: (_, i) {
                      if (i < _mesas.length) {
                        return _MesaCard(
                          mesa:     _mesas[i],
                          atendida: _atendidas.contains(_mesas[i].id),
                          onTap:    () => _onTapMesa(_mesas[i]),
                        );
                      }
                      return _AnadirCard(onTap: _goToAddMesa);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de mesa
// ---------------------------------------------------------------------------

class _MesaCard extends StatelessWidget {
  const _MesaCard({
    required this.mesa,
    required this.atendida,
    required this.onTap,
  });

  final Mesa         mesa;
  final bool         atendida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = atendida ? AppColors.verdeExito : AppColors.naranjaAccion;

    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Número de orden
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF60A5FA)
                              .withValues(alpha: 0.55)),
                    ),
                    child: Text(
                      'Orden #${mesa.orden}',
                      style: AppTypography.caption.copyWith(
                          color: const Color(0xFF93C5FD),
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Número de mesa (grande)
              Text(
                'Mesa ${mesa.numero}',
                style: AppTypography.titleLarge.copyWith(color: color),
              ),
              const SizedBox(height: 4),

              // Nombre del cliente
              Text(
                mesa.nombre,
                style: AppTypography.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Estado
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width:  6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        atendida ? 'Atendida' : 'Abierta',
                        style: AppTypography.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta añadir
// ---------------------------------------------------------------------------

class _AnadirCard extends StatelessWidget {
  const _AnadirCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.naranjaAccion.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.naranjaAccion.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width:  52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.naranjaAccion.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add,
                    color: AppColors.naranjaAccion, size: 28),
              ),
              const SizedBox(height: 12),
              Text('Añadir mesa',
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.naranjaAccion)),
            ],
          ),
        ),
      ),
    );
  }
}

