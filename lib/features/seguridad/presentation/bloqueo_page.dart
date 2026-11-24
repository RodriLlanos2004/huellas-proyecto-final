import 'package:flutter/material.dart';

import '../../../core/dependencias.dart';
import '../../../core/rutas.dart';
import '../data/servicio_biometrico.dart';

/// Pantalla de inicio de sesión biométrico.
///
/// Se muestra al abrir la app y cuando vuelve de segundo plano después de un
/// minuto. No se puede cerrar con el botón Atrás (PopScope con canPop: false),
/// así que la única salida es autenticarse.
class BloqueoPage extends StatefulWidget {
  const BloqueoPage({super.key, this.esReanudacion = false});

  /// true si se apiló encima de otra pantalla al volver de segundo plano.
  final bool esReanudacion;

  @override
  State<BloqueoPage> createState() => _BloqueoPageState();
}

class _BloqueoPageState extends State<BloqueoPage> {
  late final Dependencias _dep = AppScope.of(context);
  DisponibilidadBiometrica? _disponibilidad;
  bool _autenticando = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dep.bloqueoVisible.value = true;
      _verificarYAutenticar();
    });
  }

  @override
  void dispose() {
    _dep.bloqueoVisible.value = false;
    super.dispose();
  }

  Future<void> _verificarYAutenticar() async {
    final disponibilidad = await _dep.biometria.disponibilidad();
    if (!mounted) return;
    setState(() => _disponibilidad = disponibilidad);
    if (disponibilidad != DisponibilidadBiometrica.ninguna) await _autenticar();
  }

  Future<void> _autenticar() async {
    if (_autenticando) return;
    setState(() {
      _autenticando = true;
      _mensaje = null;
    });
    final resultado = await _dep.biometria.autenticar('Confirma tu identidad para abrir tu diario');
    if (!mounted) return;
    setState(() => _autenticando = false);
    switch (resultado) {
      case ResultadoAutenticacion.exito:
        _entrar();
      case ResultadoAutenticacion.cancelado:
        setState(() => _mensaje = 'Autenticación cancelada. Toca "Desbloquear" para intentarlo de nuevo.');
      case ResultadoAutenticacion.bloqueadoTemporal:
        setState(() => _mensaje =
            'Demasiados intentos fallidos. Espera unos segundos o usa el PIN del dispositivo.');
      case ResultadoAutenticacion.noDisponible:
        setState(() {
          _disponibilidad = DisponibilidadBiometrica.ninguna;
          _mensaje = 'No hay huella ni PIN configurados en este dispositivo.';
        });
      case ResultadoAutenticacion.error:
        setState(() => _mensaje = 'No se pudo verificar tu identidad. Intenta de nuevo.');
    }
  }

  void _entrar() {
    if (widget.esReanudacion) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, Rutas.lista);
    }
  }

  /// Solo se ofrece si el dispositivo no tiene ningún método de bloqueo.
  Future<void> _continuarSinProteccion() async {
    await _dep.preferencias.guardarBloqueoActivo(false);
    if (mounted) _entrar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sinMetodo = _disponibilidad == DisponibilidadBiometrica.ninguna;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          // Fondo: imagen propia de la app (asset) con un velo oscuro para dar contraste.
          decoration: const BoxDecoration(
            color: Color(0xFF0B3D36),
            image: DecorationImage(
              image: AssetImage('assets/images/fondo_huellas.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Color(0x33000000), BlendMode.darken),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Image.asset('assets/images/logo_huellas.png', width: 120, height: 120),
                    const SizedBox(height: 24),
                    Text('Huellas',
                        style: tema.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Tu diario está protegido',
                        style: tema.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 40),
                    if (_disponibilidad == null || _autenticando)
                      const CircularProgressIndicator(color: Colors.white)
                    else if (!sinMetodo)
                      FilledButton.icon(
                        onPressed: _autenticar,
                        style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Desbloquear'),
                      ),
                    if (_mensaje != null) ...[
                      const SizedBox(height: 16),
                      Text(_mensaje!,
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    ],
                    if (sinMetodo) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.info_outline),
                              const SizedBox(height: 8),
                              const Text(
                                'Este dispositivo no tiene huella, rostro ni PIN configurados, '
                                'así que no es posible proteger el diario. Configura un bloqueo '
                                'de pantalla para activar la protección.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _continuarSinProteccion,
                                child: const Text('Continuar sin protección'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
