import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlSalidaPage extends StatelessWidget {
  const ControlSalidaPage({super.key});

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
    if (vehiculoSeleccionado == null || listaFaltantes.isEmpty) return;

    for (var item in listaFaltantes) {
      await Supabase.instance.client.from('faltantes_salida').insert({
        'codigo_producto': item['codigo'],
        'cantidad_faltante': item['cantidad'],
        'vehiculo': vehiculoSeleccionado!['placa'],
        'fecha': DateTime.now().toIso8601String(),
      });
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
              if (value.length >= 3) buscarProducto(value);
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
            value: vehiculoSeleccionado,
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
                  cantidadController.text.isEmpty) return;

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

  final grandes = TextEditingController();
  final medianas = TextEditingController();
  final pequenas = TextEditingController();

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

  Future<void> guardarCanastas() async {
    if (vehiculoSeleccionado == null ||
        grandes.text.isEmpty ||
        medianas.text.isEmpty ||
        pequenas.text.isEmpty) return;

    await Supabase.instance.client.from('canastas_vehiculo').insert({
      'vehiculo': vehiculoSeleccionado!['placa'],
      'canastas_grandes': int.parse(grandes.text),
      'canastas_medianas': int.parse(medianas.text),
      'canastas_pequenas': int.parse(pequenas.text),
      'fecha': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Guardado correctamente")),
    );

    grandes.clear();
    medianas.clear();
    pequenas.clear();
    setState(() {
      vehiculoSeleccionado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<Map<String, dynamic>>(
            value: vehiculoSeleccionado,
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
          TextField(
            controller: grandes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Grandes"),
          ),
          TextField(
            controller: medianas,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Medianas"),
          ),
          TextField(
            controller: pequenas,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Pequeñas"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: guardarCanastas,
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }
}