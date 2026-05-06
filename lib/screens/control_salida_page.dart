
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlSalidaPage extends StatelessWidget {
  const ControlSalidaPage({super.key});

  @override
  void dispose() {
    codigoController.dispose();
    cantidadController.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    salidaGrandes.dispose();
    salidaMedianas.dispose();
    salidaPequenas.dispose();
    entradaGrandes.dispose();
    entradaMedianas.dispose();
    entradaPequenas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Control de Salida"),
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: codigoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "SKU"),
            onChanged: (value) {
              if (value.length >= 3) {
                buscarProducto(value);
              }
            },
          ),

          if (nombreProducto.isNotEmpty)
            Text("$nombreProducto - \$${precioProducto.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.bold)),

          TextField(
            controller: cantidadController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Cantidad"),
          ),

          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: vehiculoSeleccionado,
            hint: const Text("Vehículo"),
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

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {
              if (codigoController.text.isEmpty ||
                  cantidadController.text.isEmpty) {
                return;
              }

              final cantidad = int.parse(cantidadController.text);
              final subtotal = cantidad * precioProducto;

              listaFaltantes.add({
                'codigo': codigoController.text,
                'nombre': nombreProducto,
                'cantidad': cantidad,
                'precio': precioProducto,
                'subtotal': subtotal,
              });

              setState(() {});

              codigoController.clear();
              cantidadController.clear();
              nombreProducto = "";
              precioProducto = 0;
            },
            child: const Text("Agregar"),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView.builder(
              itemCount: listaFaltantes.length,
              itemBuilder: (context, index) {
                final item = listaFaltantes[index];

                return Card(
                  child: ListTile(
                    title: Text(item['nombre']),
                    subtitle: Text(
                        "Cant: ${item['cantidad']} x \$${item['precio']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("\$${item['subtotal'].toStringAsFixed(0)}"),
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

          Text(
            "TOTAL: \$${totalGeneral.toStringAsFixed(0)}",
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),

          ElevatedButton(
            onPressed: guardarTodo,
            child: const Text("Guardar todo"),
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
    if (vehiculoSeleccionado == null) return;
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