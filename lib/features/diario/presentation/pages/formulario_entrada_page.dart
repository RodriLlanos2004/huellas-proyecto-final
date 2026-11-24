import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/dependencias.dart';
import '../../../../core/dispositivo/servicio_imagenes.dart';
import '../../../../core/errores.dart';
import '../../../../core/fechas.dart';
import '../../domain/categoria.dart';
import '../../domain/entrada_diario.dart';
import '../../domain/estado_animo.dart';
import '../../domain/metadatos_entrada.dart';
import '../../domain/ubicacion.dart';
import '../widgets/categoria_visual.dart';
import '../widgets/hoja_origen_imagen.dart';
import '../widgets/panel_dictado.dart';
import '../widgets/selector_animo.dart';

/// Decisión del usuario cuando el GPS falla al guardar.
enum _DecisionGps { reintentar, abrirAjustes, sinUbicacion, cancelar }

/// Formulario para crear una entrada: foto (cámara o galería), texto
/// dictado por voz, estado de ánimo, fecha y hora (selectores), categoría,
/// campos numéricos (calificación y gasto), campos lógicos (favorita y
/// publicar) y ubicación GPS al guardar.
class FormularioEntradaPage extends StatefulWidget {
  const FormularioEntradaPage({super.key});

  @override
  State<FormularioEntradaPage> createState() => _FormularioEntradaPageState();
}

class _FormularioEntradaPageState extends State<FormularioEntradaPage> {
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _texto = TextEditingController();
  final _calificacion = TextEditingController(text: '8');
  final _gasto = TextEditingController();

  late final Dependencias _dep = AppScope.of(context);

  EstadoAnimo _animo = EstadoAnimo.feliz;
  ImagenSeleccionada? _imagen;
  bool _guardarUbicacion = true;

  // Campos de fecha, catálogo, numéricos y lógicos.
  DateTime _fecha = DateTime.now();
  int _categoriaId = Categoria.idOtro;
  bool _favorita = false;
  bool _publicar = false;
  late final Future<List<Categoria>> _categorias = _dep.repositorio.obtenerCategorias();

  // Estado del dictado.
  bool _escuchando = false;
  double _nivelSonido = 0;
  String _textoParcial = '';
  String _textoPrevio = '';
  bool _usoDictado = false;
  DateTime? _inicioDictado;
  int _segundosDictado = 0;

  // Estado del guardado.
  bool _guardando = false;
  String _etapa = '';

  bool get _hayCambios =>
      _titulo.text.trim().isNotEmpty || _texto.text.trim().isNotEmpty || _imagen != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recuperarFotoPerdida());
  }

  @override
  void dispose() {
    // Liberar el micrófono si el usuario sale mientras dicta.
    if (_escuchando) _dep.dictado.cancelar();
    _titulo.dispose();
    _texto.dispose();
    _calificacion.dispose();
    _gasto.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Imagen

  Future<void> _recuperarFotoPerdida() async {
    final recuperada = await _dep.imagenes.recuperarPerdida();
    if (recuperada != null && mounted) setState(() => _imagen = recuperada);
  }

  Future<void> _elegirImagen() async {
    final accion = await mostrarHojaOrigenImagen(context, tieneImagen: _imagen != null);
    if (accion == null || !mounted) return;
    final origen = accion.origen;
    if (origen == null) {
      setState(() => _imagen = null);
      return;
    }
    try {
      final imagen = await _dep.imagenes.seleccionar(origen);
      if (imagen != null && mounted) setState(() => _imagen = imagen);
    } on FallaPermiso catch (f) {
      if (mounted) await _avisarPermiso(f);
    } on FallaApp catch (f) {
      _avisar(f.mensaje);
    }
  }

  // ---------------------------------------------------------------- Dictado

  Future<void> _alternarDictado() async {
    if (_escuchando) {
      await _dep.dictado.detener();
      return;
    }
    try {
      await _dep.dictado.preparar();
    } on FallaPermiso catch (f) {
      if (mounted) await _avisarPermiso(f);
      return;
    } on FallaApp catch (f) {
      _avisar(f.mensaje);
      return;
    }
    if (!mounted) return;

    _textoPrevio = _texto.text.trimRight();
    _inicioDictado = DateTime.now();
    setState(() {
      _escuchando = true;
      _textoParcial = '';
      _nivelSonido = 0;
    });

    await _dep.dictado.escuchar(
      alReconocer: (texto, esFinal) {
        if (!mounted) return;
        setState(() {
          _textoParcial = texto;
          // El texto dictado se agrega al que ya estaba escrito.
          _texto.text = [_textoPrevio, texto].where((t) => t.isNotEmpty).join(' ');
          _texto.selection = TextSelection.collapsed(offset: _texto.text.length);
          if (esFinal && texto.isNotEmpty) _usoDictado = true;
        });
      },
      alCambiarNivel: (nivel) {
        if (mounted) setState(() => _nivelSonido = nivel);
      },
      alTerminar: () {
        if (!mounted || !_escuchando) return;
        final inicio = _inicioDictado;
        setState(() {
          _escuchando = false;
          if (inicio != null) _segundosDictado += DateTime.now().difference(inicio).inSeconds;
        });
      },
      alFallar: _avisar,
    );
  }

  // ---------------------------------------------------------------- Guardado

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_escuchando) await _dep.dictado.detener();
    if (!mounted || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _guardando = true;
      _etapa = 'Obteniendo tu ubicación GPS…';
    });

    Ubicacion? ubicacion;
    if (_guardarUbicacion) {
      final resultado = await _capturarUbicacion();
      if (!mounted) return;
      if (resultado.cancelado) {
        setState(() => _guardando = false);
        return;
      }
      ubicacion = resultado.ubicacion;
    }

    String? nombreImagen;
    try {
      if (_imagen != null) {
        setState(() => _etapa = 'Guardando la foto…');
        nombreImagen = await _dep.imagenesGuardadas.guardarCopia(_imagen!.ruta);
      }
      setState(() => _etapa = 'Escribiendo en tu diario…');
      await _dep.repositorio.guardar(EntradaDiario(
        titulo: _titulo.text.trim(),
        texto: _texto.text.trim(),
        fecha: _fecha,
        animo: _animo,
        categoriaId: _categoriaId,
        calificacion: int.parse(_calificacion.text),
        gasto: _gastoIngresado,
        favorita: _favorita,
        publicar: _publicar,
        imagen: nombreImagen,
        ubicacion: ubicacion,
        metadatos: MetadatosEntrada(
          origenImagen: _imagen?.origen,
          usoDictado: _usoDictado,
          segundosDictado: _segundosDictado,
        ),
      ));
      if (mounted) Navigator.pop(context, true);
    } on FallaApp catch (f) {
      // Si la base de datos falló, no se deja una foto huérfana.
      await _dep.imagenesGuardadas.eliminar(nombreImagen);
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(f.mensaje);
    }
  }

  /// Lee el GPS; si falla, pregunta al usuario qué hacer en lugar de rendirse.
  Future<({Ubicacion? ubicacion, bool cancelado})> _capturarUbicacion() async {
    while (true) {
      try {
        final u = await _dep.ubicacion.obtenerActual();
        return (ubicacion: u, cancelado: false);
      } on FallaApp catch (falla) {
        if (!mounted) return (ubicacion: null, cancelado: true);
        final decision = await _preguntarSinGps(falla);
        switch (decision) {
          case _DecisionGps.reintentar:
            if (mounted) setState(() => _etapa = 'Reintentando con el GPS…');
            continue;
          case _DecisionGps.abrirAjustes:
            if (falla is FallaServicioDesactivado) {
              await _dep.permisos.abrirAjustesUbicacion();
            } else {
              await _dep.permisos.abrirAjustesApp();
            }
            return (ubicacion: null, cancelado: true);
          case _DecisionGps.sinUbicacion:
            return (ubicacion: null, cancelado: false);
          case _DecisionGps.cancelar || null:
            return (ubicacion: null, cancelado: true);
        }
      }
    }
  }

  Future<_DecisionGps?> _preguntarSinGps(FallaApp falla) {
    final requiereAjustes =
        falla is FallaServicioDesactivado || (falla is FallaPermiso && falla.permanente);
    final titulo = switch (falla) {
      FallaServicioDesactivado() => 'Ubicación apagada',
      FallaPermiso() => 'Permiso de ubicación',
      FallaTiempoAgotado() => 'El GPS no respondió',
      _ => 'No se obtuvo la ubicación',
    };
    return showDialog<_DecisionGps>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: Text(titulo),
        content: Text('${falla.mensaje}\n\nPuedes guardar la entrada sin ubicación.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DecisionGps.cancelar),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DecisionGps.sinUbicacion),
            child: const Text('Guardar sin ubicación'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, requiereAjustes ? _DecisionGps.abrirAjustes : _DecisionGps.reintentar),
            child: Text(requiereAjustes ? 'Abrir ajustes' : 'Reintentar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Fecha

  /// Selector de fecha y luego de hora. No se permiten fechas futuras (RN-03).
  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: ahora,
      helpText: '¿Qué día fue?',
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
      helpText: '¿A qué hora?',
    );
    if (!mounted) return;
    var elegida = DateTime(dia.year, dia.month, dia.day,
        hora?.hour ?? _fecha.hour, hora?.minute ?? _fecha.minute);
    if (elegida.isAfter(ahora)) elegida = ahora;
    setState(() => _fecha = elegida);
  }

  double get _gastoIngresado => double.tryParse(_gasto.text.replaceAll(',', '.')) ?? 0;

  static String? _validarCalificacion(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Escribe un número';
    if (n < EntradaDiario.calificacionMinima || n > EntradaDiario.calificacionMaxima) {
      return 'Debe ser de 1 a 10';
    }
    return null;
  }

  static String? _validarGasto(String? v) {
    if (v == null || v.trim().isEmpty) return null; // Vacío equivale a 0.
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return 'Número no válido';
    if (n < 0 || n > EntradaDiario.gastoMaximo) return 'Máximo 100,000';
    return null;
  }

  // ---------------------------------------------------------------- Avisos

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _avisarPermiso(FallaPermiso falla) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Permiso necesario'),
          content: Text(falla.mensaje),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ahora no')),
            if (falla.permanente)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _dep.permisos.abrirAjustesApp();
                },
                child: const Text('Abrir ajustes'),
              ),
          ],
        ),
      );

  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar esta entrada?'),
        content: const Text('Perderás lo que escribiste y la foto elegida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir editando')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Descartar')),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return PopScope(
      canPop: !_hayCambios && !_guardando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_guardando) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nueva entrada'),
          actions: [
            IconButton(
              tooltip: 'Guardar',
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: Stack(
          children: [
            Form(
              key: _formulario,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _VistaImagen(imagen: _imagen, alTocar: _guardando ? null : _elegirImagen),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titulo,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Título del día',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ponle un título a tu día' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _texto,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 5,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: '¿Qué pasó hoy?',
                      alignLabelWithHint: true,
                      helperText: 'Escribe o toca el micrófono para dictar',
                      suffixIcon: IconButton(
                        tooltip: _escuchando ? 'Detener dictado' : 'Dictar con voz',
                        onPressed: _guardando ? null : _alternarDictado,
                        icon: Icon(_escuchando ? Icons.stop_circle : Icons.mic,
                            color: _escuchando ? tema.colorScheme.error : tema.colorScheme.primary),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Cuenta un poco de tu día' : null,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _escuchando
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: PanelDictado(
                              nivel: _nivelSonido,
                              textoParcial: _textoParcial,
                              alDetener: _alternarDictado,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 20),
                  Text('¿Cómo te sentiste?', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SelectorAnimo(valor: _animo, alCambiar: (a) => setState(() => _animo = a)),
                  const SizedBox(height: 24),
                  Text('Detalles del día', style: tema.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text('${Fechas.larga(_fecha)}, ${Fechas.hora(_fecha)}'),
                      subtitle: const Text('Fecha y hora del recuerdo'),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: _guardando ? null : _elegirFecha,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Categoria>>(
                    future: _categorias,
                    builder: (context, snapshot) {
                      // Si SQLite falla, se usa el catálogo fijo para no bloquear el formulario.
                      final categorias = snapshot.data ?? Categoria.predeterminadas;
                      return DropdownButtonFormField<int>(
                        initialValue: _categoriaId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final c in categorias)
                            DropdownMenuItem(
                              value: c.id,
                              child: Row(
                                children: [
                                  Icon(c.iconoMaterial, color: c.colorMaterial, size: 20),
                                  const SizedBox(width: 10),
                                  Text(c.nombre),
                                ],
                              ),
                            ),
                        ],
                        onChanged: _guardando ? null : (v) => setState(() => _categoriaId = v ?? _categoriaId),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _calificacion,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Calificación',
                            helperText: 'Del 1 al 10',
                            prefixIcon: Icon(Icons.star_half_outlined),
                          ),
                          validator: _validarCalificacion,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _gasto,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}([.,]\d{0,2})?')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Gasto',
                            helperText: 'En pesos',
                            prefixIcon: Icon(Icons.payments_outlined),
                            hintText: '0.00',
                          ),
                          validator: _validarGasto,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(_favorita ? Icons.favorite : Icons.favorite_border,
                              color: _favorita ? Colors.pink : null),
                          title: const Text('Marcar como favorita'),
                          value: _favorita,
                          onChanged: _guardando ? null : (v) => setState(() => _favorita = v),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        CheckboxListTile(
                          secondary: const Icon(Icons.cloud_upload_outlined),
                          title: const Text('Publicar en Huellas Comunidad'),
                          subtitle: const Text('Se sube al servidor cuando sincronices'),
                          value: _publicar,
                          onChanged: _guardando ? null : (v) => setState(() => _publicar = v ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.my_location),
                      title: const Text('Guardar mi ubicación'),
                      subtitle: const Text('Se captura con el GPS al momento de guardar'),
                      value: _guardarUbicacion,
                      onChanged: _guardando ? null : (v) => setState(() => _guardarUbicacion = v),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar entrada'),
                  ),
                ],
              ),
            ),
            if (_guardando) _CapaGuardando(etapa: _etapa),
          ],
        ),
      ),
    );
  }
}

/// Área de la foto: invita a agregar una o muestra la vista previa.
class _VistaImagen extends StatelessWidget {
  const _VistaImagen({required this.imagen, required this.alTocar});
  final ImagenSeleccionada? imagen;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final imagen = this.imagen;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Material(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: imagen == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 44, color: tema.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('Agrega una foto de tu día', style: tema.textTheme.titleSmall),
                    Text('Cámara o galería', style: tema.textTheme.bodySmall),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(imagen.ruta), fit: BoxFit.cover),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Chip(
                        avatar: Icon(imagen.origen == OrigenImagen.camara
                            ? Icons.photo_camera_outlined
                            : Icons.photo_library_outlined),
                        label: Text(imagen.origen.etiqueta),
                      ),
                    ),
                    const Positioned(
                      right: 12,
                      top: 12,
                      child: CircleAvatar(child: Icon(Icons.edit_outlined)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Capa que bloquea el formulario y explica qué se está haciendo al guardar.
class _CapaGuardando extends StatelessWidget {
  const _CapaGuardando({required this.etapa});
  final String etapa;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black45,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(etapa, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
