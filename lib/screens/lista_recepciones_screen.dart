import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'nueva_recepcion_screen.dart';
import 'detalle_recepcion_screen.dart';

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
    symbol: '\$',
    decimalDigits: 0,
  );

  // 🔥 STREAM SIN FILTROS (COMPATIBLE)
  Stream<List<Map<String, dynamic>>> getRecepcionesStream() {
    return supabase
        .from('recepciones')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false);
  }

  Future<void> seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
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
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        backgroundColor: azulPrincipal,
        title: const Text('Recepción L&M'),
        centerTitle: true,
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getRecepcionesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🔥 FILTRADO EN FLUTTER (AQUÍ ESTÁ EL TRUCO)
          final recepciones = snapshot.data!.where((r) {
            final fecha = DateTime.parse(r['created_at']);
            return esMismaFecha(fecha);
          }).toList();

          // 🔥 TOTALES EN TIEMPO REAL
          final totalGeneral = recepciones.fold(
              0.0, (sum, r) => sum + (r['total'] ?? 0));

          final totalCambios = recepciones.fold(
              0.0, (sum, r) => sum + (r['total_cambios'] ?? 0));

          final totalAverias = recepciones.fold(
              0.0, (sum, r) => sum + (r['total_averias'] ?? 0));

          return Column(
            children: [
              const SizedBox(height: 10),

              // 📅 FECHA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Card(
                  child: ListTile(
                    leading:
                        Icon(Icons.calendar_today, color: azulPrincipal),
                    title: const Text("Fecha seleccionada"),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy')
                          .format(fechaSeleccionada),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: seleccionarFecha,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 🔥 TOTAL GENERAL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          "Total General",
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          currencyFormat.format(totalGeneral),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2A5E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 🔥 KPIs
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: _cardKPI(
                        "Cambios",
                        currencyFormat.format(totalCambios),
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _cardKPI(
                        "Averías",
                        currencyFormat.format(totalAverias),
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 📋 LISTA
              Expanded(
                child: recepciones.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        itemCount: recepciones.length,
                        itemBuilder: (context, index) {
                          final r = recepciones[index];

                          final total = r['total'] ?? 0;
                          final cambios =
                              r['total_cambios'] ?? 0;
                          final averias =
                              r['total_averias'] ?? 0;

                          final colorTipo = averias > 0
                              ? Colors.red
                              : Colors.green;

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 5),
                            child: Card(
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DetalleRecepcionScreen(
                                              recepcion: r),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundColor: colorTipo,
                                  child: const Icon(
                                    Icons.local_shipping,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  'Planilla: ${r['planilla']}',
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                                subtitle: Text(
                                    'Placa: ${r['placa']}'),
                                trailing: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormat
                                          .format(total),
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "C: ${currencyFormat.format(cambios)}",
                                      style:
                                          const TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      "A: ${currencyFormat.format(averias)}",
                                      style:
                                          const TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: azulPrincipal,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const NuevaRecepcionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _cardKPI(String titulo, String valor,
      {Color color = Colors.black}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(titulo),
            const SizedBox(height: 5),
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text("No hay datos"),
    );
  }
}