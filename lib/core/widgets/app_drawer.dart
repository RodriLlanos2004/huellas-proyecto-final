import 'package:flutter/material.dart';

import '../rutas.dart';

class _Destino {
  const _Destino(this.ruta, this.etiqueta, this.icono, this.iconoActivo);
  final String ruta;
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
}

/// Menú lateral (Drawer) de las pantallas principales.
///
/// Navega con rutas nombradas y mantiene limpia la pila: la lista siempre
/// queda en la base, así que el botón Atrás nunca da vueltas infinitas.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.rutaActual});

  final String rutaActual;

  static const _destinos = [
    _Destino(Rutas.lista, 'Mis huellas', Icons.auto_stories_outlined, Icons.auto_stories),
    _Destino(Rutas.nueva, 'Nueva entrada', Icons.add_a_photo_outlined, Icons.add_a_photo),
    _Destino(Rutas.mapa, 'Mapa de recuerdos', Icons.map_outlined, Icons.map),
    _Destino(Rutas.comunidad, 'Huellas Comunidad', Icons.public_outlined, Icons.public),
    _Destino(Rutas.ajustes, 'Ajustes', Icons.settings_outlined, Icons.settings),
  ];

  void _ir(BuildContext context, String destino) {
    final navegador = Navigator.of(context);
    navegador.pop(); // Cierra el drawer.
    if (destino == rutaActual) return;
    if (destino == Rutas.lista) {
      navegador.popUntil(ModalRoute.withName(Rutas.lista));
    } else if (destino == Rutas.nueva) {
      navegador.pushNamed(destino);
    } else {
      navegador.pushNamedAndRemoveUntil(destino, ModalRoute.withName(Rutas.lista));
    }
  }

  void _bloquear(BuildContext context) {
    final navegador = Navigator.of(context);
    navegador.pop();
    navegador.pushNamedAndRemoveUntil(Rutas.bloqueo, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final indice = _destinos.indexWhere((d) => d.ruta == rutaActual);
    return NavigationDrawer(
      selectedIndex: indice < 0 ? null : indice,
      onDestinationSelected: (i) => _ir(context, _destinos[i].ruta),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: tema.colorScheme.primary,
            // Imagen de fondo propia (asset) con el mapa topográfico de la marca.
            image: const DecorationImage(
              image: AssetImage('assets/images/fondo_huellas.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo_huellas.png', width: 52, height: 52),
              const SizedBox(height: 12),
              Text('Huellas',
                  style: tema.textTheme.headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Tu diario con foto, voz y lugar',
                  style: tema.textTheme.bodyMedium?.copyWith(color: Colors.white)),
            ],
          ),
        ),
        for (final d in _destinos)
          NavigationDrawerDestination(
            icon: Icon(d.icono),
            selectedIcon: Icon(d.iconoActivo),
            label: Text(d.etiqueta),
          ),
        const Padding(padding: EdgeInsets.fromLTRB(28, 12, 28, 8), child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text('Bloquear ahora', style: tema.textTheme.labelLarge),
            shape: const StadiumBorder(),
            onTap: () => _bloquear(context),
          ),
        ),
      ],
    );
  }
}
