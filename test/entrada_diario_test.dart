import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huellas/features/diario/data/servicio_respaldo.dart';
import 'package:huellas/features/diario/domain/entrada_diario.dart';
import 'package:huellas/features/diario/domain/estado_animo.dart';
import 'package:huellas/features/diario/domain/metadatos_entrada.dart';
import 'package:huellas/features/diario/domain/ubicacion.dart';

void main() {
  final completa = EntradaDiario(
    id: 7,
    titulo: 'Atardecer en Progreso',
    texto: 'El mar estaba tranquilo.',
    fecha: DateTime(2026, 11, 15, 18, 45),
    animo: EstadoAnimo.radiante,
    imagen: 'huella_1.jpg',
    ubicacion: const Ubicacion(latitud: 21.2833, longitud: -89.6667, precisionMetros: 5.5),
    metadatos: const MetadatosEntrada(
        origenImagen: OrigenImagen.camara, usoDictado: true, segundosDictado: 12),
  );

  group('Serialización SQLite', () {
    test('toMap y fromMap conservan todos los campos', () {
      final copia = EntradaDiario.fromMap(completa.toMap());
      expect(copia.toJson(), completa.toJson());
    });

    test('una entrada nueva no envía id para que SQLite lo autoincremente', () {
      final nueva = EntradaDiario(titulo: 'a', texto: 'b', fecha: DateTime(2026));
      expect(nueva.toMap().containsKey('id'), isFalse);
    });

    test('sin coordenadas la ubicación queda en null', () {
      final mapa = completa.toMap()
        ..['latitud'] = null
        ..['longitud'] = null;
      expect(EntradaDiario.fromMap(mapa).ubicacion, isNull);
    });

    test('metadatos dañados no impiden leer el registro', () {
      final mapa = completa.toMap()..['metadatos'] = '{esto no es json';
      final leida = EntradaDiario.fromMap(mapa);
      expect(leida.titulo, completa.titulo);
      expect(leida.metadatos.usoDictado, isFalse);
    });

    test('un estado de ánimo desconocido se lee como tranquilo', () {
      final mapa = completa.toMap()..['animo'] = 'eufórico';
      expect(EntradaDiario.fromMap(mapa).animo, EstadoAnimo.tranquilo);
    });
  });

  group('Serialización JSON', () {
    test('toJson y fromJson ida y vuelta, pasando por texto', () {
      final texto = jsonEncode(completa.toJson());
      final copia = EntradaDiario.fromJson(jsonDecode(texto) as Map<String, dynamic>);
      expect(copia.toJson(), completa.toJson());
      expect(copia.ubicacion, completa.ubicacion);
    });

    test('coordenadas fuera de rango se rechazan', () {
      expect(() => Ubicacion.fromJson({'latitud': 120, 'longitud': 0}), throwsFormatException);
    });

    test('el respaldo serializa y deserializa la lista completa', () {
      final json = ServicioRespaldo.serializar([completa, completa.copyWith(id: 8)], DateTime(2026));
      final entradas = ServicioRespaldo.deserializar(json);
      expect(entradas, hasLength(2));
      expect(entradas.last.id, 8);
    });
  });

  test('los campos del proyecto final viajan en SQLite y JSON', () {
    final e = completa.copyWith(
        categoriaId: 1, calificacion: 9, gasto: 250.5, favorita: true, publicar: true, remotoId: 31);
    final mapa = e.toMap();
    expect(mapa['favorita'], 1);
    expect(mapa['remoto_id'], 31);
    expect(EntradaDiario.fromMap(mapa).toJson(), e.toJson());
    expect(EntradaDiario.fromJson(e.toJson()).gasto, 250.5);
    expect(e.publicada, isTrue);
    final quitada = e.sinPublicar();
    expect(quitada.remotoId, isNull);
    expect(quitada.publicar, isFalse);
    expect(quitada.favorita, isTrue);
  });

  test('el enlace de Google Maps lleva las coordenadas', () {
    final url = completa.ubicacion!.enlaceGoogleMaps.toString();
    expect(url, contains('query=21.2833%2C-89.6667'));
    expect(url, startsWith('https://www.google.com/maps/search/'));
  });
}
