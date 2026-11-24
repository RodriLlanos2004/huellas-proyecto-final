/// Tercera entidad de SQLite: cada intento de publicar en la comunidad
/// queda registrado (cuándo, cuántas entradas se enviaron y si falló).
class RegistroSincronizacion {
  const RegistroSincronizacion({
    this.id,
    required this.fecha,
    required this.enviadas,
    required this.fallidas,
    required this.servidor,
    this.detalle = '',
  });

  final int? id;
  final DateTime fecha;
  final int enviadas;
  final int fallidas;
  final String servidor;
  final String detalle;

  bool get exitosa => fallidas == 0;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'fecha': fecha.millisecondsSinceEpoch,
        'enviadas': enviadas,
        'fallidas': fallidas,
        'servidor': servidor,
        'detalle': detalle,
      };

  factory RegistroSincronizacion.fromMap(Map<String, Object?> mapa) => RegistroSincronizacion(
        id: mapa['id'] as int?,
        fecha: DateTime.fromMillisecondsSinceEpoch(mapa['fecha'] as int),
        enviadas: mapa['enviadas'] as int,
        fallidas: mapa['fallidas'] as int,
        servidor: mapa['servidor'] as String,
        detalle: mapa['detalle'] as String? ?? '',
      );

  /// Línea para el archivo plano de bitácora (valores separados por `;`).
  String aLineaBitacora() => [
        fecha.toIso8601String(),
        enviadas,
        fallidas,
        exitosa ? 'OK' : 'CON_ERRORES',
        servidor,
        detalle.replaceAll(RegExp(r'[;\n\r]'), ' '),
      ].join(';');

  static const encabezadoBitacora = 'fecha;enviadas;fallidas;resultado;servidor;detalle';
}
