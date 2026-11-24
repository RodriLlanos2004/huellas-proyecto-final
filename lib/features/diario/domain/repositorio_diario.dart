import 'categoria.dart';
import 'entrada_diario.dart';
import 'registro_sincronizacion.dart';

/// Contrato de acceso a los datos locales del diario.
///
/// La interfaz de usuario depende de esta abstracción y no de SQLite
/// (principio de inversión de dependencias). Cualquier error de las
/// implementaciones se reporta como `FallaAlmacenamiento`.
abstract interface class RepositorioDiario {
  // ---------- Entradas ----------

  /// Todas las entradas, de la más reciente a la más antigua.
  Future<List<EntradaDiario>> obtenerTodas();

  Future<EntradaDiario?> obtenerPorId(int id);

  /// Inserta la entrada si no tiene id o la actualiza si ya existe.
  /// Devuelve la entrada con su id asignado.
  Future<EntradaDiario> guardar(EntradaDiario entrada);

  Future<void> eliminar(int id);

  /// Entradas marcadas para publicar que aún no tienen id remoto.
  Future<List<EntradaDiario>> pendientesDePublicar();

  /// Guarda el id que asignó el servidor (la entrada ya no se vuelve a enviar).
  Future<void> marcarPublicada(int id, int remotoId);

  // ---------- Categorías ----------

  Future<List<Categoria>> obtenerCategorias();

  // ---------- Sincronizaciones ----------

  Future<RegistroSincronizacion> registrarSincronizacion(RegistroSincronizacion registro);

  /// Historial, del intento más reciente al más antiguo.
  Future<List<RegistroSincronizacion>> obtenerSincronizaciones();
}
