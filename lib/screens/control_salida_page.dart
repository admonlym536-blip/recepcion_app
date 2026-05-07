
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlSalidaPage extends StatelessWidget {
  const ControlSalidaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Control de Salida",
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
        body: const TabBarView(
          children: [
            FaltantesTab(),
            CanastasTab(),
          ],
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////
/// 🔴 TAB FALTANTES PRO
///////////////////////////////////////////////////////////

class FaltantesTab extends StatefulWidget {
  const FaltantesTab({super.key});

  @override
  State<FaltantesTab> createState() => _FaltantesTabState();
}

class _FaltantesTabState extends State<FaltantesTab> {
  final codigoController = TextEditingController();
  final cantidadController = TextEditingController();

  Map<String, dynamic>? vehiculoSeleccionado;
  List<Map<String, dynamic>> vehiculos = [];

  List<Map<String, dynamic>> listaFaltantes = [];
  String nombreProducto = "";
  double precioProducto = 0;
  final currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    cargarVehiculos();
  }

  Future<void> cargarVehiculos() async {
    final data = await Supabase.instance.client.from('vehiculos').select();
    setState(() {
      vehiculos = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> buscarProducto(String codigo) async {
    final data = await Supabase.instance.client
        .from('productos')
        .select()
        .eq('sku', codigo)
        .maybeSingle();

    setState(() {
      nombreProducto = data?['nombre'] ?? "Producto no encontrado";
      precioProducto = (data?['precio'] ?? 0).toDouble();
    });
  }

  double get totalGeneral {
    return listaFaltantes.fold(
        0, (sum, item) => sum + item['subtotal']);
  }

  Future<void> guardarTodo() async {
    if (vehiculoSeleccionado == null || listaFaltantes.isEmpty) {
      return;
    }

    for (var item in listaFaltantes) {
      await Supabase.instance.client.from('faltantes_salida').insert({
        'codigo_producto': item['codigo'],
        'cantidad_faltante': item['cantidad'],
        'vehiculo': vehiculoSeleccionado!['placa'],
        'fecha': DateTime.now().toIso8601String(),
      });
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Guardado correctamente")),
    );

    setState(() {
      listaFaltantes.clear();
    });
  }

  @override
  void dispose() {
    codigoController.dispose();
    cantidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "SKU",
                      prefixIcon: const Icon(Icons.qr_code_2),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: Color(0xFF0A2A5E),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length >= 3) {
                        buscarProducto(value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (nombreProducto.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$nombreProducto - ${currencyFormat.format(precioProducto)}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Cantidad",
                      prefixIcon: const Icon(Icons.numbers),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: Color(0xFF0A2A5E),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: vehiculoSeleccionado,
                    hint: const Text("Vehículo"),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: Color(0xFF0A2A5E),
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: vehiculos.map((v) {
                      return DropdownMenuItem(
                        value: v,
                        child: Text("${v['ruta']} - ${v['placa']}"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        vehiculoSeleccionado = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (codigoController.text.isEmpty ||
                            cantidadController.text.isEmpty) {
                          return;
                        }

                        final cantidad = int.tryParse(cantidadController.text);
                        if (cantidad == null) {
                          return;
                        }
                        final subtotal = cantidad * precioProducto;

                        setState(() {
                          listaFaltantes.add({
                            'codigo': codigoController.text,
                            'nombre': nombreProducto,
                            'cantidad': cantidad,
                            'precio': precioProducto,
                            'subtotal': subtotal,
                          });

                          codigoController.clear();
                          cantidadController.clear();
                          nombreProducto = "";
                          precioProducto = 0;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Agregar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: listaFaltantes.length,
              itemBuilder: (context, index) {
                final item = listaFaltantes[index];

                return Card(
                  elevation: 1.2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    title: Text(
                      item['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      "Cant: ${item['cantidad']} x ${currencyFormat.format(item['precio'])}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currencyFormat.format(item['subtotal']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              listaFaltantes.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A5E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "TOTAL: ${currencyFormat.format(totalGeneral)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A2A5E),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: guardarTodo,
              icon: const Icon(Icons.save_outlined),
              label: const Text("Guardar todo"),
            ),
          )
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////
/// 🟢 CANASTAS (sin cambios grandes)
///////////////////////////////////////////////////////////

class CanastasTab extends StatefulWidget {
  const CanastasTab({super.key});

  @override
  State<CanastasTab> createState() => _CanastasTabState();
}

class _CanastasTabState extends State<CanastasTab> {
  Map<String, dynamic>? vehiculoSeleccionado;
  List<Map<String, dynamic>> vehiculos = [];
  Map<String, dynamic>? registroActual;

  // Controladores para salida de canastillas
  final salidaGrandes = TextEditingController();
  final salidaMedianas = TextEditingController();
  final salidaPequenas = TextEditingController();
  // Controladores para entrada de canastillas
  final entradaGrandes = TextEditingController();
  final entradaMedianas = TextEditingController();
  final entradaPequenas = TextEditingController();

  // Cargar el registro actual del día para el vehículo seleccionado, si existe
  Future<void> cargarRegistroHoy() async {
    if (vehiculoSeleccionado == null) {
      return;
    }
    // Obtenemos la fecha actual en formato YYYY-MM-DD
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final data = await Supabase.instance.client
        .from('control_canastillas')
        .select()
        .eq('vehiculo', vehiculoSeleccionado!['placa'])
        .eq('fecha', hoy)
        .maybeSingle();
    setState(() {
      registroActual = data;
      if (data != null) {
        // Prefill the controllers with existing data
        salidaGrandes.text = data['salida_grandes']?.toString() ?? '';
        salidaMedianas.text = data['salida_medianas']?.toString() ?? '';
        salidaPequenas.text = data['salida_pequenas']?.toString() ?? '';
        entradaGrandes.text = data['entrada_grandes']?.toString() ?? '';
        entradaMedianas.text = data['entrada_medianas']?.toString() ?? '';
        entradaPequenas.text = data['entrada_pequenas']?.toString() ?? '';
      } else {
        // Limpiar campos si no hay registro
        salidaGrandes.clear();
        salidaMedianas.clear();
        salidaPequenas.clear();
        entradaGrandes.clear();
        entradaMedianas.clear();
        entradaPequenas.clear();
      }
    });
  }

  // Guardar solo las canastillas de salida (intermedio)
  Future<void> guardarSalida() async {
    if (vehiculoSeleccionado == null ||
        salidaGrandes.text.isEmpty ||
        salidaMedianas.text.isEmpty ||
        salidaPequenas.text.isEmpty) {
      return;
    }
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    if (registroActual == null) {
      // Insertar nuevo registro con salidas y entradas en cero
      await Supabase.instance.client.from('control_canastillas').insert({
        'vehiculo': vehiculoSeleccionado!['placa'],
        'fecha': hoy,
        'salida_grandes': int.parse(salidaGrandes.text),
        'salida_medianas': int.parse(salidaMedianas.text),
        'salida_pequenas': int.parse(salidaPequenas.text),
        'entrada_grandes': 0,
        'entrada_medianas': 0,
        'entrada_pequenas': 0,
      });
    } else {
      // Actualizar salidas del registro existente
      await Supabase.instance.client
          .from('control_canastillas')
          .update({
        'salida_grandes': int.parse(salidaGrandes.text),
        'salida_medianas': int.parse(salidaMedianas.text),
        'salida_pequenas': int.parse(salidaPequenas.text),
      }).eq('id', registroActual!['id']);
    }
    // Mostrar mensaje y recargar el registro
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Salidas guardadas (intermedio)")),
    );
    await cargarRegistroHoy();
  }

  // Guardar definitivo (salida y entrada) en el registro
  Future<void> guardarDefinitivo() async {
    if (vehiculoSeleccionado == null ||
        salidaGrandes.text.isEmpty ||
        salidaMedianas.text.isEmpty ||
        salidaPequenas.text.isEmpty ||
        entradaGrandes.text.isEmpty ||
        entradaMedianas.text.isEmpty ||
        entradaPequenas.text.isEmpty) {
      return;
    }
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    if (registroActual == null) {
      // Insertar nuevo registro con salidas y entradas
      await Supabase.instance.client.from('control_canastillas').insert({
        'vehiculo': vehiculoSeleccionado!['placa'],
        'fecha': hoy,
        'salida_grandes': int.parse(salidaGrandes.text),
        'salida_medianas': int.parse(salidaMedianas.text),
        'salida_pequenas': int.parse(salidaPequenas.text),
        'entrada_grandes': int.parse(entradaGrandes.text),
        'entrada_medianas': int.parse(entradaMedianas.text),
        'entrada_pequenas': int.parse(entradaPequenas.text),
      });
    } else {
      // Actualizar salidas y entradas del registro existente
      await Supabase.instance.client
          .from('control_canastillas')
          .update({
        'salida_grandes': int.parse(salidaGrandes.text),
        'salida_medianas': int.parse(salidaMedianas.text),
        'salida_pequenas': int.parse(salidaPequenas.text),
        'entrada_grandes': int.parse(entradaGrandes.text),
        'entrada_medianas': int.parse(entradaMedianas.text),
        'entrada_pequenas': int.parse(entradaPequenas.text),
      }).eq('id', registroActual!['id']);
    }
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registro definitivo guardado")),
    );
    await cargarRegistroHoy();
  }

  @override
  void initState() {
    super.initState();
    cargarVehiculos();
  }

  Future<void> cargarVehiculos() async {
    final data = await Supabase.instance.client.from('vehiculos').select();
    setState(() {
      vehiculos = List<Map<String, dynamic>>.from(data);
    });
  }

  /// Este método se eliminó en favor de guardarSalida y guardarDefinitivo.
  /// La lógica de registro se divide ahora en dos pasos: un guardado
  /// intermedio para las salidas y un guardado definitivo para salidas
  /// y entradas. Mantener este método vacío evita referencias
  /// accidentalmente sin romper la API interna.
  Future<void> guardarCanastas() async {
    // Intencionalmente vacío. Use guardarSalida() o guardarDefinitivo().
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: vehiculoSeleccionado,
            hint: const Text("Vehículo"),
            items: vehiculos.map((v) {
              return DropdownMenuItem(
                value: v,
                child: Text("${v['ruta']} - ${v['placa']}"),
              );
            }).toList(),
            onChanged: (value) async {
              setState(() {
                vehiculoSeleccionado = value;
              });
              await cargarRegistroHoy();
            },
          ),
          const SizedBox(height: 10),

          // Sección de salida de canastillas
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Salida",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextField(
            controller: salidaGrandes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Grandes (salida)",
            ),
          ),
          TextField(
            controller: salidaMedianas,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Medianas (salida)",
            ),
          ),
          TextField(
            controller: salidaPequenas,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Pequeñas (salida)",
            ),
          ),
          const SizedBox(height: 10),
          // Sección de entrada de canastillas
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Entrada",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextField(
            controller: entradaGrandes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Grandes (entrada)",
            ),
          ),
          TextField(
            controller: entradaMedianas,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Medianas (entrada)",
            ),
          ),
          TextField(
            controller: entradaPequenas,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Pequeñas (entrada)",
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: guardarSalida,
                  child: const Text("Guardar salida"),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: guardarDefinitivo,
                  child: const Text("Guardar definitivo"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}