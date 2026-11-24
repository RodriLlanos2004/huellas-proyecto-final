/// Categoría de una entrada del diario (segunda entidad de SQLite).
///
/// El catálogo es fijo y sus id coinciden con la tabla `categorias` de MySQL
/// en el servidor, así una entrada publicada conserva su categoría.
class Categoria {
  const Categoria({required this.id, required this.nombre, required this.icono, required this.color});

  final int id;
  final String nombre;

  /// Clave del ícono; la capa de presentación la traduce a un `IconData`.
  final String icono;

  /// Color ARGB, por ejemplo 0xFF00796B.
  final int color;

  static const idOtro = 6;

  static const predeterminadas = <Categoria>[
    Categoria(id: 1, nombre: 'Viajes', icono: 'flight', color: 0xFF00796B),
    Categoria(id: 2, nombre: 'Comida', icono: 'restaurant', color: 0xFFE07A4F),
    Categoria(id: 3, nombre: 'Escuela', icono: 'school', color: 0xFF3F51B5),
    Categoria(id: 4, nombre: 'Familia', icono: 'family', color: 0xFFC2185B),
    Categoria(id: 5, nombre: 'Deporte', icono: 'sports', color: 0xFF2E7D32),
    Categoria(id: idOtro, nombre: 'Otro', icono: 'bookmark', color: 0xFF6D4C41),
  ];

  /// Busca en el catálogo; si el id no existe devuelve "Otro".
  static Categoria porId(int? id) =>
      predeterminadas.firstWhere((c) => c.id == id, orElse: () => predeterminadas.last);

  Map<String, Object?> toMap() => {'id': id, 'nombre': nombre, 'icono': icono, 'color': color};

  factory Categoria.fromMap(Map<String, Object?> mapa) => Categoria(
        id: mapa['id'] as int,
        nombre: mapa['nombre'] as String,
        icono: mapa['icono'] as String,
        color: mapa['color'] as int,
      );

  @override
  bool operator ==(Object other) => other is Categoria && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
