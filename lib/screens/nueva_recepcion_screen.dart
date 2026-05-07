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
      .where((p) =>
          p['tipo'] == 'devolucion buena' ||
          p['tipo'] == 'dev_mal_manejo')
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

  double get totalMalManejo => productos
      .where((p) => p['tipo'] == 'dev_mal_manejo')
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
            'total_dev_mal_manejo': totalMalManejo,
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
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'Nueva Recepción',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: iniciado
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80, right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'manual',
                    onPressed: agregarManual,
                    backgroundColor: const Color(0xFF1565C0),
                    child: const Icon(Icons.edit),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    heroTag: 'scan',
                    onPressed: escanear,
                    backgroundColor: const Color(0xFF0A2A5E),
                    child: const Icon(Icons.qr_code_scanner),
                  ),
                ],
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: iniciado
            ? Column(
                children: [
                  Card(
                    elevation: 1.4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            "TOTAL: ${currencyFormat.format(total)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFF0A2A5E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chipMonto(
                                "Devolución buena",
                                currencyFormat.format(totalDevolucionBuena),
                                Colors.green,
                              ),
                              _chipMonto(
                                "Averías",
                                currencyFormat.format(totalAverias),
                                Colors.red,
                              ),
                              _chipMonto(
                                "Mal manejo",
                                currencyFormat.format(totalMalManejo),
                                Colors.orange,
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
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: Color(0xFF0A2A5E),
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'devolucion buena',
                        child: Text('Devolución buena'),
                      ),
                      DropdownMenuItem(
                        value: 'averia',
                        child: Text('Avería'),
                      ),
                      DropdownMenuItem(
                        value: 'dev_mal_manejo',
                        child: Text('Dev. buena x mal manejo'),
                      ),
                    ],
                    onChanged: (v) => setState(() => tipoSeleccionado = v!),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: productos.isEmpty
                        ? const Center(
                            child: Text(
                              'Agrega productos',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: productos.length,
                            itemBuilder: (_, i) {
                              final p = productos[i];
                              return Card(
                                elevation: 1.2,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFF0A2A5E).withValues(
                                      alpha: 0.10,
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Color(0xFF0A2A5E),
                                    ),
                                  ),
                                  title: Text(
                                    p['nombre'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "${p['cantidad']} - ${p['tipo']}",
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
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
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : guardar,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(loading ? "Guardando..." : "GUARDAR"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Card(
                    elevation: 1.4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextField(
                            controller: planillaController,
                            decoration: InputDecoration(
                              labelText: 'Planilla',
                              prefixIcon:
                                  const Icon(Icons.receipt_long_outlined),
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
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Map<String, dynamic>>(
                            hint: const Text("Seleccionar vehículo"),
                            decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.local_shipping_outlined),
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (planillaController.text.isEmpty ||
                                    vehiculoSeleccionado == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Completa los datos'),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => iniciado = true);
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text("INICIAR"),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chipMonto(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "$titulo: $valor",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
