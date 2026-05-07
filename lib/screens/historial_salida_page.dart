
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
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text(
            "Historial de Salidas",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicator: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: "Faltantes"),
              Tab(text: "Canastas"),
            ],
          ),
        ),
        body: Column(
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                title: const Text(
                  "Fecha",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(fechaSeleccionada),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: seleccionarFecha,
                ),
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
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0A2A5E).withValues(
                        alpha: 0.12,
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: Color(0xFF0A2A5E),
                      ),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['ruta'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Vehículo: $vehiculo",
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          "Productos: ${info['cantidadItems']}",
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    trailing: Text(
                      currencyFormat.format(info['total']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleSalidaPage(
                            vehiculo: vehiculo,
                            items: List<Map<String, dynamic>>.from(
                              info['items'],
                            ),
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
  /// 🔵 AGRUPAR CANASTILLAS (salida / entrada / diferencia)
  //////////////////////////////////////////////////////

  /// Agrupa los registros de control de canastillas por vehículo para sumar
  /// las salidas, entradas y calcular la diferencia (salida - entrada) por tamaño.
  /// También asigna la ruta a cada vehículo utilizando la tabla de vehículos.
  Future<Map<String, dynamic>> _agruparCanastas(List data) async {
    Map<String, dynamic> resultado = {};
    // Obtener la información de los vehículos para conocer la ruta por placa
    final vehiculos = await supabase.from('vehiculos').select();
    final mapaVehiculos = {
      for (var v in vehiculos) v['placa']: v
    };
    for (var item in data) {
      final vehiculo = item['vehiculo'];
      final infoVehiculo = mapaVehiculos[vehiculo];
      final ruta = infoVehiculo?['ruta'] ?? 'Sin ruta';
      // Convertir los campos a enteros para evitar operaciones con null
      final salidaG = (item['salida_grandes'] ?? 0) as int;
      final salidaM = (item['salida_medianas'] ?? 0) as int;
      final salidaP = (item['salida_pequenas'] ?? 0) as int;
      final entradaG = (item['entrada_grandes'] ?? 0) as int;
      final entradaM = (item['entrada_medianas'] ?? 0) as int;
      final entradaP = (item['entrada_pequenas'] ?? 0) as int;
      final difG = salidaG - entradaG;
      final difM = salidaM - entradaM;
      final difP = salidaP - entradaP;
      if (!resultado.containsKey(vehiculo)) {
        resultado[vehiculo] = {
          'ruta': ruta,
          'salida_grandes': 0,
          'salida_medianas': 0,
          'salida_pequenas': 0,
          'entrada_grandes': 0,
          'entrada_medianas': 0,
          'entrada_pequenas': 0,
          'diferencia_grandes': 0,
          'diferencia_medianas': 0,
          'diferencia_pequenas': 0,
        };
      }
      resultado[vehiculo]['salida_grandes'] += salidaG;
      resultado[vehiculo]['salida_medianas'] += salidaM;
      resultado[vehiculo]['salida_pequenas'] += salidaP;
      resultado[vehiculo]['entrada_grandes'] += entradaG;
      resultado[vehiculo]['entrada_medianas'] += entradaM;
      resultado[vehiculo]['entrada_pequenas'] += entradaP;
      resultado[vehiculo]['diferencia_grandes'] += difG;
      resultado[vehiculo]['diferencia_medianas'] += difM;
      resultado[vehiculo]['diferencia_pequenas'] += difP;
    }
    return resultado;
  }

  //////////////////////////////////////////////////////
  /// 🟢 CANASTAS
  //////////////////////////////////////////////////////

  Widget _canastasTab() {
    // Mostrar un resumen de entradas y salidas de canastillas por vehículo.
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('control_canastillas')
          .stream(primaryKey: ['id']).order('id', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Filtrar por la fecha seleccionada
        final data = snapshot.data!.where((r) {
          final fecha = DateTime.parse(r['fecha']);
          return esMismaFecha(fecha);
        }).toList();
        // Agrupar salidas y entradas por vehículo y calcular diferencia
        return FutureBuilder<Map<String, dynamic>>(
          future: _agruparCanastas(data),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final agrupados = snapshot.data!;
            return ListView(
              children: agrupados.entries.map((entry) {
                final vehiculo = entry.key;
                final info = entry.value as Map<String, dynamic>;
                final salidasText =
                    "G: ${info['salida_grandes']} | M: ${info['salida_medianas']} | P: ${info['salida_pequenas']}";
                final entradasText =
                    "G: ${info['entrada_grandes']} | M: ${info['entrada_medianas']} | P: ${info['entrada_pequenas']}";
                final diffText =
                    "G: ${info['diferencia_grandes']} | M: ${info['diferencia_medianas']} | P: ${info['diferencia_pequenas']}";
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.12),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.green),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['ruta'] ?? 'Sin ruta',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Vehículo: $vehiculo",
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text("Salida: $salidasText"),
                        Text("Entrada: $entradasText"),
                        Text(
                          "Diferencia: $diffText",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A2A5E),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}