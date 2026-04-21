import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'detalle_salida_page.dart';

class HistorialSalidaPage extends StatefulWidget {
  const HistorialSalidaPage({super.key});

  @override
  State<HistorialSalidaPage> createState() => _HistorialSalidaPageState();
}

class _HistorialSalidaPageState extends State<HistorialSalidaPage> {
  final supabase = Supabase.instance.client;

  final currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  DateTime fechaSeleccionada = DateTime.now();

  bool esMismaFecha(DateTime fecha) {
    return fecha.year == fechaSeleccionada.year &&
        fecha.month == fechaSeleccionada.month &&
        fecha.day == fechaSeleccionada.day;
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Historial de Salidas"),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Faltantes"),
              Tab(text: "Canastas"),
            ],
          ),
        ),
        body: Column(
          children: [
            ListTile(
              title: const Text("Fecha"),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(fechaSeleccionada),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: seleccionarFecha,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _faltantesTab(),
                  _canastasTab(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////
  /// 🔴 FALTANTES PRO
  //////////////////////////////////////////////////////

  Widget _faltantesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('faltantes_salida')
          .stream(primaryKey: ['id']).order('id', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.where((r) {
          final fecha = DateTime.parse(r['fecha']);
          return esMismaFecha(fecha);
        }).toList();

        return FutureBuilder(
          future: _agruparFaltantes(data),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final agrupados =
                snapshot.data as Map<String, dynamic>;

            return ListView(
              children: agrupados.entries.map((entry) {
                final vehiculo = entry.key;
                final info = entry.value;

                return Card(
                  margin: const EdgeInsets.all(10),
                  elevation: 3,
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping,
                        color: Colors.blue),

                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['ruta'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text("Vehículo: $vehiculo"),
                        Text("Productos: ${info['cantidadItems']}"),
                      ],
                    ),

                    trailing: Text(
                      currencyFormat.format(info['total']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleSalidaPage(
                            vehiculo: vehiculo,
                            items: List<Map<String, dynamic>>.from(
                                info['items']),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  //////////////////////////////////////////////////////
  /// 🔥 AGRUPAR CON RUTA
  //////////////////////////////////////////////////////

  Future<Map<String, dynamic>> _agruparFaltantes(List data) async {
    Map<String, dynamic> resultado = {};

    final productos = await supabase.from('productos').select();
    final vehiculos = await supabase.from('vehiculos').select();

    final mapaProductos = {
      for (var p in productos) p['sku']: p
    };

    final mapaVehiculos = {
      for (var v in vehiculos) v['placa']: v
    };

    for (var item in data) {
      final vehiculo = item['vehiculo'];

      final producto = mapaProductos[item['codigo_producto']];
      final infoVehiculo = mapaVehiculos[vehiculo];

      final precio = (producto?['precio'] ?? 0).toDouble();
      final nombre = producto?['nombre'] ?? 'Sin nombre';
      final ruta = infoVehiculo?['ruta'] ?? 'Sin ruta';

      final subtotal = precio * item['cantidad_faltante'];

      if (!resultado.containsKey(vehiculo)) {
        resultado[vehiculo] = {
          'total': 0.0,
          'cantidadItems': 0,
          'ruta': ruta,
          'items': [],
        };
      }

      resultado[vehiculo]['total'] += subtotal;
      resultado[vehiculo]['cantidadItems'] += 1;

      resultado[vehiculo]['items'].add({
        'nombre': nombre,
        'cantidad_faltante': item['cantidad_faltante'],
        'precio': precio,
        'subtotal': subtotal,
      });
    }

    return resultado;
  }

  //////////////////////////////////////////////////////
  /// 🟢 CANASTAS
  //////////////////////////////////////////////////////

  Widget _canastasTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('canastas_vehiculo')
          .stream(primaryKey: ['id']).order('id', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.where((r) {
          final fecha = DateTime.parse(r['fecha']);
          return esMismaFecha(fecha);
        }).toList();

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const Icon(Icons.inventory,
                    color: Colors.green),
                title: Text("Vehículo: ${item['vehiculo']}"),
                subtitle: Text(
                    "G: ${item['canastas_grandes']} | M: ${item['canastas_medianas']} | P: ${item['canastas_pequenas']}"),
              ),
            );
          },
        );
      },
    );
  }
}