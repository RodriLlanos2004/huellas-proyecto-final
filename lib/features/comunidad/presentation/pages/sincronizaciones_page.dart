import 'package:flutter/material.dart';

import '../../../../core/dependencias.dart';
import '../../../../core/errores.dart';
import '../../../../core/fechas.dart';
import '../../../../core/widgets/estados_vista.dart';
import '../../../diario/domain/registro_sincronizacion.dart';
import '../../data/bitacora_sincronizacion.dart';

/// Historial de sincronizaciones: lee la tabla `sincronizaciones` de SQLite
/// y permite ver el archivo plano de bitácora con el mismo contenido.
class SincronizacionesPage extends StatefulWidget {
  const SincronizacionesPage({super.key});

  @override
  State<SincronizacionesPage> createState() => _SincronizacionesPageState();
}

class _SincronizacionesPageState extends State<SincronizacionesPage> {
  late final Dependencias _dep = AppScope.of(context);
  late Future<List<RegistroSincronizacion>> _registros = _dep.repositorio.obtenerSincronizaciones();

  void _recargar() => setState(() => _registros = _dep.repositorio.obtenerSincronizaciones());

  Future<void> _verArchivo() async {
    String contenido;
    try {
      contenido = await _dep.bitacora.leer();
    } on FallaApp catch (f) {
      contenido = f.mensaje;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.description_outlined),
        title: const Text(BitacoraSincronizacion.nombreArchivo),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: SelectableText(
                contenido.isEmpty ? '(El archivo aún no existe)' : contenido,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de sincronización'),
        actions: [
          IconButton(
            tooltip: 'Ver archivo plano',
            icon: const Icon(Icons.description_outlined),
            onPressed: _verArchivo,
          ),
        ],
      ),
      body: FutureBuilder<List<RegistroSincronizacion>>(
        future: _registros,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EstadoCargando(mensaje: 'Leyendo el historial…');
          }
          if (snapshot.hasError) {
            return EstadoError(mensaje: mensajeDeError(snapshot.error), alReintentar: _recargar);
          }
          final registros = snapshot.data!;
          if (registros.isEmpty) {
            return const EstadoVacio(
              icono: Icons.history,
              titulo: 'Sin sincronizaciones',
              mensaje: 'Cada vez que publiques en la comunidad quedará un registro aquí.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: registros.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = registros[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        r.exitosa ? tema.colorScheme.primaryContainer : tema.colorScheme.errorContainer,
                    child: Icon(r.exitosa ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                        color: r.exitosa
                            ? tema.colorScheme.onPrimaryContainer
                            : tema.colorScheme.onErrorContainer),
                  ),
                  title: Text('${r.enviadas} enviadas · ${r.fallidas} fallidas'),
                  subtitle: Text('${Fechas.corta(r.fecha)}, ${Fechas.hora(r.fecha)} · ${r.servidor}\n'
                      '${r.detalle}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
