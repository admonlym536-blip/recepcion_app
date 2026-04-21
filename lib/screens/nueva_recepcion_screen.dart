import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'scan_screen.dart';

class NuevaRecepcionScreen extends StatefulWidget {
  const NuevaRecepcionScreen({super.key});

  @override
  State<NuevaRecepcionScreen> createState() =>
      _NuevaRecepcionScreenState();
}

class _NuevaRecepcionScreenState extends State<NuevaRecepcionScreen> {
  final supabase = Supabase.instance.client;

  final planillaController = TextEditingController();

  Map<String, dynamic>? vehiculoSeleccionado;
  List<Map<String, dynamic>> vehiculos = [];

  final currencyFormat =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  bool iniciado = false;
  bool loading = false;

  String tipoSeleccionado = 'devolucion buena';

  List<Map<String, dynamic>> productos = [];

  @override
  void initState() {
    super.initState();
    cargarVehiculos();
  }

  Future<void> cargarVehiculos() async {
    final data = await supabase.from('vehiculos').select();
    setState(() {
      vehiculos = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<int?> pedirCantidad(String nombre) async {
    final controller = TextEditingController(text: '1');

    return await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(nombre),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final c = int.tryParse(controller.text) ?? 1;
              Navigator.pop(context, c);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> escanear() async {
    final codigo = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (codigo == null) return;

    try {
      final data = await supabase
          .from('productos')
          .select()
          .eq('codigo', codigo)
          .maybeSingle();

      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto no encontrado')),
        );
        return;
      }

      final cantidad = await pedirCantidad(data['nombre']);
      if (cantidad == null) return;

      final index = productos.indexWhere(
        (p) =>
            p['codigo'] == codigo &&
            p['tipo'] == tipoSeleccionado,
      );

      setState(() {
        if (index >= 0) {
          productos[index]['cantidad'] += cantidad;
        } else {
          productos.add({
            'codigo': data['codigo'],
            'nombre': data['nombre'],
            'precio': data['precio'],
            'cantidad': cantidad,
            'tipo': tipoSeleccionado,
          });
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> agregarManual() async {
    final controller = TextEditingController();

    final texto = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ingresar producto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'SKU (recomendado)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );

    if (texto == null || texto.isEmpty) return;

    try {
      final data = await supabase
          .from('productos')
          .select()
          .or('sku.eq.$texto,codigo.eq.$texto')
          .maybeSingle();

      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto no encontrado')),
        );
        return;
      }

      final cantidad = await pedirCantidad(data['nombre']);
      if (cantidad == null) return;

      final index = productos.indexWhere(
        (p) =>
            p['codigo'] == data['codigo'] &&
            p['tipo'] == tipoSeleccionado,
      );

      setState(() {
        if (index >= 0) {
          productos[index]['cantidad'] += cantidad;
        } else {
          productos.add({
            'codigo': data['codigo'],
            'nombre': data['nombre'],
            'precio': data['precio'],
            'cantidad': cantidad,
            'tipo': tipoSeleccionado,
          });
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  double get total => productos.fold(
        0,
        (s, p) =>
            s + ((p['precio'] as num) * (p['cantidad'] as int)),
      );

  double get totalDevolucionBuena => productos
      .where((p) => p['tipo'] == 'devolucion buena')
      .fold(
        0,
        (s, p) =>
            s + ((p['precio'] as num) * (p['cantidad'] as int)),
      );

  double get totalAverias => productos
      .where((p) => p['tipo'] == 'averia')
      .fold(
        0,
        (s, p) =>
            s + ((p['precio'] as num) * (p['cantidad'] as int)),
      );

  Future<void> guardar() async {
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos')),
      );
      return;
    }

    if (planillaController.text.isEmpty ||
        vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa planilla y vehículo')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final recepcion = await supabase
          .from('recepciones')
          .insert({
            'planilla': planillaController.text,
            'placa': vehiculoSeleccionado!['placa'],
            'usuario': Supabase.instance.client.auth.currentUser?.email,
            'total': total,
            'total_devolucion_buena': totalDevolucionBuena,
            'total_averias': totalAverias,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final id = recepcion['id'];

      final detalles = productos.map((p) => {
            'recepcion_id': id,
            'codigo': p['codigo'],
            'nombre': p['nombre'],
            'cantidad': p['cantidad'],
            'precio': p['precio'],
            'tipo': p['tipo'],
          }).toList();

      await supabase.from('recepcion_detalle').insert(detalles);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado exitoso')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => loading = false);
  }

  @override
  void dispose() {
    planillaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Recepción')),

      floatingActionButton: iniciado
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'manual',
                  onPressed: agregarManual,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'scan',
                  onPressed: escanear,
                  child: const Icon(Icons.qr_code),
                ),
              ],
            )
          : null,

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: iniciado
            ? Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            "TOTAL: ${currencyFormat.format(total)}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                "Devolución buena: ${currencyFormat.format(totalDevolucionBuena)}",
                                style: const TextStyle(color: Colors.green),
                              ),
                              Text(
                                "Averías: ${currencyFormat.format(totalAverias)}",
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField(
                    initialValue: tipoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                          value: 'devolucion buena',
                          child: Text('Devolución buena')),
                      DropdownMenuItem(
                          value: 'averia', child: Text('Avería')),
                    ],
                    onChanged: (v) =>
                        setState(() => tipoSeleccionado = v!),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: productos.isEmpty
                        ? const Center(child: Text('Agrega productos'))
                        : ListView.builder(
                            itemCount: productos.length,
                            itemBuilder: (_, i) {
                              final p = productos[i];
                              return Card(
                                child: ListTile(
                                  title: Text(p['nombre']),
                                  subtitle: Text("${p['cantidad']} - ${p['tipo']}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        productos.removeAt(i);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : guardar,
                      child: loading
                          ? const CircularProgressIndicator()
                          : const Text("GUARDAR"),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  TextField(
                    controller: planillaController,
                    decoration: const InputDecoration(labelText: 'Planilla'),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    hint: const Text("Seleccionar vehículo"),
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

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (planillaController.text.isEmpty ||
                          vehiculoSeleccionado == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Completa los datos')),
                        );
                        return;
                      }

                      setState(() => iniciado = true);
                    },
                    child: const Text("INICIAR"),
                  ),
                ],
              ),
      ),
    );
  }
}