import 'package:flutter/material.dart';

import '../../../../core/dependencias.dart';
import '../../../../core/errores.dart';

/// RN-08: alias de 3 a 20 caracteres (letras, números, punto o guion bajo).
final patronAlias = RegExp(r'^[A-Za-z0-9_.]{3,20}$');

String? validarAlias(String? v) {
  final texto = v?.trim() ?? '';
  if (texto.length < 3) return 'Mínimo 3 caracteres';
  if (!patronAlias.hasMatch(texto)) return 'Solo letras, números, punto y guion bajo';
  return null;
}

/// Pide el alias, lo registra en el servidor (POST /api/usuarios) y lo guarda
/// en las preferencias. Devuelve true si quedó registrado.
Future<bool> mostrarDialogoAlias(BuildContext context) async {
  final registrado = await showDialog<bool>(
    context: context,
    builder: (_) => const _DialogoAlias(),
  );
  return registrado ?? false;
}

class _DialogoAlias extends StatefulWidget {
  const _DialogoAlias();

  @override
  State<_DialogoAlias> createState() => _DialogoAliasState();
}

class _DialogoAliasState extends State<_DialogoAlias> {
  final _formulario = GlobalKey<FormState>();
  late final Dependencias _dep = AppScope.of(context);
  late final _alias = TextEditingController(text: _dep.preferencias.alias ?? '');
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final usuario = await _dep.comunidad.registrarUsuario(
        alias: _alias.text.trim(),
        dispositivo: _dep.preferencias.dispositivoId,
      );
      await _dep.preferencias.guardarUsuario(alias: usuario.alias, id: usuario.id);
      if (mounted) Navigator.pop(context, true);
    } on FallaApp catch (f) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = f.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.alternate_email),
        title: const Text('Tu alias en la comunidad'),
        content: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Es el nombre público que verán los demás. No se pide correo ni contraseña.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alias,
                autofocus: true,
                maxLength: 20,
                enabled: !_enviando,
                decoration: const InputDecoration(prefixText: '@', labelText: 'Alias'),
                validator: validarAlias,
                onFieldSubmitted: (_) => _registrar(),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _enviando ? null : _registrar,
            child: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Registrar'),
          ),
        ],
      );
}
