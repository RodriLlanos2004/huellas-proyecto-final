import 'package:flutter/material.dart';

import '../../../core/dependencias.dart';
import '../../../core/errores.dart';
import '../../../core/fechas.dart';
import '../../../core/rutas.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../comunidad/presentation/widgets/dialogo_alias.dart';
import '../../seguridad/data/servicio_biometrico.dart';

/// Ajustes: bloqueo biométrico, comunidad (servidor y alias), respaldo JSON y permisos.
class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  late final Dependencias _dep = AppScope.of(context);
  bool _exportando = false;
  bool _probando = false;

  void _avisar(String mensaje) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  /// Cambiar el bloqueo exige autenticarse: así nadie lo desactiva con el teléfono ajeno.
  Future<void> _cambiarBloqueo(bool activar) async {
    if (activar &&
        await _dep.biometria.disponibilidad() == DisponibilidadBiometrica.ninguna) {
      _avisar('Configura una huella o un PIN en el dispositivo para activar el bloqueo.');
      return;
    }
    final resultado = await _dep.biometria.autenticar(
        activar ? 'Confirma para activar el bloqueo' : 'Confirma para desactivar el bloqueo');
    if (!mounted) return;
    if (resultado != ResultadoAutenticacion.exito) {
      _avisar('No se cambió el ajuste porque no se completó la autenticación.');
      return;
    }
    await _dep.preferencias.guardarBloqueoActivo(activar);
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- Comunidad

  static String? _validarUrl(String? v) {
    final uri = Uri.tryParse(v?.trim() ?? '');
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'Escribe una dirección como http://10.0.2.2:8000';
    }
    return null;
  }

  Future<void> _editarServidor() async {
    final control = TextEditingController(text: _dep.preferencias.servidorUrl);
    final clave = GlobalKey<FormState>();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.dns_outlined),
        title: const Text('Servidor de la comunidad'),
        content: Form(
          key: clave,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('En el emulador, la computadora es 10.0.2.2. En un teléfono real, '
                  'usa la IP de la computadora en tu red Wi-Fi.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: control,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'URL del servicio web'),
                validator: _validarUrl,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (clave.currentState!.validate()) Navigator.pop(context, control.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    control.dispose();
    if (url == null) return;
    await _dep.preferencias.guardarServidorUrl(url);
    if (mounted) setState(() {});
  }

  Future<void> _elegirAlias() async {
    if (await mostrarDialogoAlias(context) && mounted) {
      setState(() {});
      _avisar('Listo, ahora eres @${_dep.preferencias.alias}');
    }
  }

  Future<void> _probarConexion() async {
    setState(() => _probando = true);
    try {
      final version = await _dep.comunidad.probarConexion();
      if (mounted) _avisar('Conectado. El servidor usa MySQL $version');
    } on FallaApp catch (f) {
      if (mounted) _avisar(f.mensaje);
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  // ---------------------------------------------------------------- Respaldo

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      final r = await _dep.respaldo.exportar();
      await _dep.preferencias.guardarUltimoRespaldo(DateTime.now());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.data_object),
          title: Text('Respaldo creado (${r.total} entradas)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(r.ruta, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      r.json.length > 900 ? '${r.json.substring(0, 900)}\n…' : r.json,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
          ],
        ),
      );
    } on FallaApp catch (f) {
      if (mounted) _avisar(f.mensaje);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultimo = _dep.preferencias.ultimoRespaldo;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      drawer: const AppDrawer(rutaActual: Rutas.ajustes),
      body: ListView(
        children: [
          const _Seccion('Seguridad'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Bloqueo con huella o PIN'),
            subtitle: const Text('Al abrir la app y al volver después de 1 minuto'),
            value: _dep.preferencias.bloqueoActivo,
            onChanged: _cambiarBloqueo,
          ),
          const _Seccion('Huellas Comunidad'),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text(_dep.preferencias.alias == null
                ? 'Elegir mi alias'
                : '@${_dep.preferencias.alias}'),
            subtitle: Text(_dep.preferencias.usuarioRemotoId == null
                ? 'Sin registrar en este servidor'
                : 'Usuario #${_dep.preferencias.usuarioRemotoId} en MySQL'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _elegirAlias,
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Servidor'),
            subtitle: Text(_dep.preferencias.servidorUrl),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _editarServidor,
          ),
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: const Text('Probar conexión'),
            subtitle: const Text('GET /api/salud'),
            trailing: _probando
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _probando ? null : _probarConexion,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial de sincronización'),
            subtitle: const Text('Tabla en SQLite y archivo plano de bitácora'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Rutas.sincronizaciones),
          ),
          const _Seccion('Datos'),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Exportar respaldo JSON'),
            subtitle: Text(ultimo == null
                ? 'Aún no has creado un respaldo'
                : 'Último: ${Fechas.corta(ultimo)}, ${Fechas.hora(ultimo)}'),
            trailing: _exportando
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _exportando ? null : _exportar,
          ),
          const _Seccion('Permisos'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Permisos de cámara, micrófono y ubicación'),
            subtitle: const Text('Abrir los ajustes del sistema para esta app'),
            onTap: () => _dep.permisos.abrirAjustesApp(),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Huellas',
            applicationVersion: '2.0.0',
            applicationIcon: Image(image: AssetImage('assets/images/logo_huellas.png'), width: 48),
            aboutBoxChildren: [
              Text('Diario personal con foto, dictado por voz, ubicación GPS y comunidad web.\n\n'
                  'Proyecto de Programación de Dispositivos Móviles, Universidad Anáhuac Mayab.'),
            ],
            child: Text('Acerca de Huellas'),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);
  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(titulo,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
