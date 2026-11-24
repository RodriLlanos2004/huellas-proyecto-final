import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes sencillos de la app. Se guardan con SharedPreferences porque son
/// pares clave-valor; los registros del diario van en SQLite.
abstract interface class PreferenciasApp {
  bool get bloqueoActivo;
  Future<void> guardarBloqueoActivo(bool activo);

  DateTime? get ultimoRespaldo;
  Future<void> guardarUltimoRespaldo(DateTime momento);

  // ---------- Huellas Comunidad ----------

  /// Dirección del servicio web, por ejemplo http://10.0.2.2:8000.
  String get servidorUrl;
  Future<void> guardarServidorUrl(String url);

  /// Identificador anónimo de este teléfono (se genera una sola vez).
  String get dispositivoId;

  /// Alias público y su id en MySQL; null mientras no se registra.
  String? get alias;
  int? get usuarioRemotoId;
  Future<void> guardarUsuario({required String alias, required int id});
}

class PreferenciasCompartidas implements PreferenciasApp {
  PreferenciasCompartidas._(this._prefs);

  static const _kBloqueo = 'bloqueo_activo';
  static const _kRespaldo = 'ultimo_respaldo';
  static const _kServidor = 'servidor_url';
  static const _kDispositivo = 'dispositivo_id';
  static const _kAlias = 'alias';
  static const _kUsuario = 'usuario_remoto_id';

  /// El emulador de Android ve la computadora anfitriona en 10.0.2.2.
  static const servidorPorDefecto = 'http://10.0.2.2:8000';

  final SharedPreferencesWithCache _prefs;

  static Future<PreferenciasCompartidas> cargar() async {
    final prefs = PreferenciasCompartidas._(
      await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {_kBloqueo, _kRespaldo, _kServidor, _kDispositivo, _kAlias, _kUsuario},
        ),
      ),
    );
    if (prefs._prefs.getString(_kDispositivo) == null) {
      await prefs._prefs.setString(_kDispositivo, generarIdDispositivo());
    }
    return prefs;
  }

  /// 32 caracteres hexadecimales aleatorios (no se usa ningún dato personal del teléfono).
  static String generarIdDispositivo([Random? azar]) {
    final r = azar ?? Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// Por seguridad, el bloqueo viene activado de fábrica.
  @override
  bool get bloqueoActivo => _prefs.getBool(_kBloqueo) ?? true;

  @override
  Future<void> guardarBloqueoActivo(bool activo) => _prefs.setBool(_kBloqueo, activo);

  @override
  DateTime? get ultimoRespaldo {
    final ms = _prefs.getInt(_kRespaldo);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> guardarUltimoRespaldo(DateTime momento) =>
      _prefs.setInt(_kRespaldo, momento.millisecondsSinceEpoch);

  @override
  String get servidorUrl => _prefs.getString(_kServidor) ?? servidorPorDefecto;

  @override
  Future<void> guardarServidorUrl(String url) async {
    if (url == servidorUrl) return;
    await _prefs.setString(_kServidor, url);
    // Otro servidor tiene otra base de datos: el id de usuario anterior no vale ahí.
    await _prefs.remove(_kUsuario);
  }

  @override
  String get dispositivoId => _prefs.getString(_kDispositivo) ?? '';

  @override
  String? get alias => _prefs.getString(_kAlias);

  @override
  int? get usuarioRemotoId => _prefs.getInt(_kUsuario);

  @override
  Future<void> guardarUsuario({required String alias, required int id}) async {
    await _prefs.setString(_kAlias, alias);
    await _prefs.setInt(_kUsuario, id);
  }
}
