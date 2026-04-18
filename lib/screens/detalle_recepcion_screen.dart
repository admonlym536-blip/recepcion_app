import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DetalleRecepcionScreen extends StatefulWidget {
  final Map recepcion;

  const DetalleRecepcionScreen({super.key, required this.recepcion});

  @override
  State<DetalleRecepcionScreen> createState() =>
      _DetalleRecepcionScreenState();
}

class _DetalleRecepcionScreenState extends State<DetalleRecepcionScreen> {
  final supabase = Supabase.instance.client;

  List detalles = [];
  bool loading = true;

  final currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0, // 🔥 sin decimales
  );

  @override
  void initState() {
    super.initState();
    cargarDetalle();
  }

  Future<void> cargarDetalle() async {
    try {
      final data = await supabase
          .from('recepcion_detalle')
          .select()
          .eq('recepcion_id', widget.recepcion['id']);

      setState(() {
        detalles = data;
        loading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() => loading = false);
    }
  }

  // 🔥 AGRUPAR PRODUCTOS
  List<Map<String, dynamic>> agruparProductos(List datos) {
    final Map<String, Map<String, dynamic>> mapa = {};

    for (var d in datos) {
      final key = "${d['codigo']}_${d['tipo']}";

      if (mapa.containsKey(key)) {
        mapa[key]!['cantidad'] += (d['cantidad'] ?? 0);
      } else {
        mapa[key] = {
          'nombre': d['nombre'],
          'cantidad': d['cantidad'],
          'precio': d['precio'],
          'tipo': d['tipo'],
        };
      }
    }

    return mapa.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recepcion;
    final agrupados = agruparProductos(detalles);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle Recepción')),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔥 RESUMEN MEJORADO
                Card(
                  margin: const EdgeInsets.all(10),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text("Planilla: ${r['planilla']}"),
                        Text("Placa: ${r['placa']}"),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(r['total'] ?? 0),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              "Cambios: ${currencyFormat.format(r['total_cambios'] ?? 0)}",
                              style: const TextStyle(
                                  color: Colors.green),
                            ),
                            Text(
                              "Averías: ${currencyFormat.format(r['total_averias'] ?? 0)}",
                              style: const TextStyle(
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 🔥 ENCABEZADO TABLA
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 4,
                          child: Text("Producto",
                              style:
                                  TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text("Cant",
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text("Tipo",
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 3,
                          child: Text("Total",
                              textAlign: TextAlign.end)),
                    ],
                  ),
                ),

                // 📦 TABLA
                Expanded(
                  child: agrupados.isEmpty
                      ? const Center(child: Text("Sin productos"))
                      : ListView.builder(
                          itemCount: agrupados.length,
                          itemBuilder: (_, i) {
                            final d = agrupados[i];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // 📦 PRODUCTO
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        d['nombre'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),

                                    // 🔢 CANTIDAD
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "${d['cantidad']}",
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    // 🔄 TIPO
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        d['tipo'],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: d['tipo'] == 'averia'
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    // 💰 TOTAL
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        currencyFormat.format(
                                          (d['precio'] ?? 0) *
                                              (d['cantidad'] ?? 0),
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}