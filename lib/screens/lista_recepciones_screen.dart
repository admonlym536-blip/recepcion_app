import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'nueva_recepcion_screen.dart';
import 'detalle_recepcion_screen.dart';
import 'control_salida_page.dart';
import 'historial_salida_page.dart';
import 'login_page.dart';

class ListaRecepcionesScreen extends StatefulWidget {
  const ListaRecepcionesScreen({super.key});

  @override
  State<ListaRecepcionesScreen> createState() =>
      _ListaRecepcionesScreenState();
}

class _ListaRecepcionesScreenState extends State<ListaRecepcionesScreen> {
  final supabase = Supabase.instance.client;

  DateTime fechaSeleccionada = DateTime.now();
  final Color azulPrincipal = const Color(0xFF0A2A5E);

  final currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$ ',
    decimalDigits: 0,
  );

  Stream<List<Map<String, dynamic>>> getRecepcionesStream() {
    return supabase
        .from('recepciones')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false);
  }

  Future<void> seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() => fechaSeleccionada = fecha);
    }
  }

  bool esMismaFecha(DateTime fecha) {
    return fecha.year == fechaSeleccionada.year &&
        fecha.month == fechaSeleccionada.month &&
        fecha.day == fechaSeleccionada.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: azulPrincipal,
        elevation: 0,
        title: const Text(
          'Recepción L&M',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getRecepcionesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final recepciones = snapshot.data!.where((r) {
            final fecha = DateTime.parse(r['created_at']);
            return esMismaFecha(fecha);
          }).toList();

          num totalGeneral = 0;
          num totalDevolucionBuena = 0;
          num totalAverias = 0;
          num totalMalManejo = 0;

          for (final r in recepciones) {
            final devolucion = (r['total_devolucion_buena'] as num?) ?? 0;
            final averias = (r['total_averias'] as num?) ?? 0;
            final malManejo = (r['total_dev_mal_manejo'] as num?) ?? 0;
            final totalGuardado = (r['total'] as num?) ?? 0;

            final totalCalculado = devolucion + averias + malManejo;
            final totalSeguro = totalGuardado > 0 ? totalGuardado : totalCalculado;

            totalGeneral += totalSeguro;
            totalDevolucionBuena += devolucion;
            totalAverias += averias;
            totalMalManejo += malManejo;
          }

          return Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        color: const Color(0xFF607D8B),
                        icon: Icons.local_shipping,
                        label: 'Control de Salida',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ControlSalidaPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        color: const Color(0xFF2E7D32),
                        icon: Icons.bar_chart,
                        label: 'Ver Salidas',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistorialSalidaPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.calendar_today, color: azulPrincipal),
                    title: const Text("Fecha seleccionada"),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(fechaSeleccionada),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: seleccionarFecha,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Card(
                  elevation: 2,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Total General del Día",
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currencyFormat.format(totalGeneral),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: azulPrincipal,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniChip(
                              "Devolución buena",
                              currencyFormat.format(totalDevolucionBuena),
                              const Color(0xFF2E7D32),
                            ),
                            _miniChip(
                              "Averías",
                              currencyFormat.format(totalAverias),
                              const Color(0xFFC62828),
                            ),
                            _miniChip(
                              "Mal manejo",
                              currencyFormat.format(totalMalManejo),
                              const Color(0xFFEF6C00),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: recepciones.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: recepciones.length,
                        itemBuilder: (context, index) {
                          final r = recepciones[index];

                          final devolucionBuena =
                              (r['total_devolucion_buena'] as num?) ?? 0;
                          final averias = (r['total_averias'] as num?) ?? 0;
                          final malManejo =
                              (r['total_dev_mal_manejo'] as num?) ?? 0;
                          final totalGuardado = (r['total'] as num?) ?? 0;
                          final totalCalculado =
                              devolucionBuena + averias + malManejo;
                          final total =
                              totalGuardado > 0 ? totalGuardado : totalCalculado;

                          final Color colorTipo = averias > 0
                              ? const Color(0xFFC62828)
                              : (malManejo > 0
                                  ? const Color(0xFFEF6C00)
                                  : const Color(0xFF2E7D32));

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            child: Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DetalleRecepcionScreen(recepcion: r),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            colorTipo.withValues(alpha: 0.15),
                                        child: Icon(
                                          Icons.local_shipping,
                                          color: colorTipo,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Planilla ${r['planilla']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Placa: ${r['placa']}',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                _tagMonto(
                                                  "D",
                                                  currencyFormat
                                                      .format(devolucionBuena),
                                                  const Color(0xFF2E7D32),
                                                ),
                                                _tagMonto(
                                                  "A",
                                                  currencyFormat.format(averias),
                                                  const Color(0xFFC62828),
                                                ),
                                                _tagMonto(
                                                  "M",
                                                  currencyFormat
                                                      .format(malManejo),
                                                  const Color(0xFFEF6C00),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Total',
                                            style: TextStyle(
                                              color: Colors.black45,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(total),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: azulPrincipal,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Colors.black38,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: azulPrincipal,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NuevaRecepcionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Nueva"),
      ),
    );
  }

  Widget _actionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  Widget _miniChip(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$titulo: $valor',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tagMonto(String prefijo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$prefijo: $valor',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text(
        "No hay recepciones para esta fecha",
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
