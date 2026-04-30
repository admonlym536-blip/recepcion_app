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
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    cargarDetalle();
  }

  Future<void> cargarDetalle() async {
    final data = await supabase
        .from('recepcion_detalle')
        .select()
        .eq('recepcion_id', widget.recepcion['id']);

    setState(() {
      detalles = data;
      loading = false;
    });
  }

  Future<void> editarCantidad(Map item) async {
    final controller =
        TextEditingController(text: item['cantidad'].toString());

    final nuevaCantidad = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item['nombre']),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nueva cantidad'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context,
                    int.tryParse(controller.text) ?? item['cantidad']);
              },
              child: const Text('Guardar'))
        ],
      ),
    );

    if (nuevaCantidad == null) return;

    await supabase
        .from('recepcion_detalle')
        .update({'cantidad': nuevaCantidad}).eq('id', item['id']);

    cargarDetalle();
  }

  Future<void> agregarProducto() async {
    final skuController = TextEditingController();
    final cantidadController = TextEditingController(text: '1');

    String tipo = 'devolucion buena';
    String nombreProducto = '';

    final result = await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Agregar producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU'),
                  onChanged: (value) async {
                    final producto = await supabase
                        .from('productos')
                        .select()
                        .or('sku.eq.' + value + ',codigo.eq.' + value)
                        .maybeSingle();

                    if (producto != null) {
                      setStateDialog(() {
                        nombreProducto = producto['nombre'];
                      });
                    }
                  },
                ),
                const SizedBox(height: 5),
                Text(
                  nombreProducto.isEmpty
                      ? 'Producto no identificado'
                      : nombreProducto,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                TextField(
                  controller: cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                DropdownButtonFormField(
                  initialValue: tipo,
                  items: const [
                    DropdownMenuItem(
                        value: 'devolucion buena',
                        child: Text('Devolución buena')),
                    DropdownMenuItem(
                        value: 'averia', child: Text('Avería')),
                    DropdownMenuItem(
                        value: 'dev_mal_manejo',
                        child: Text('Dev x mal estado')),
                  ],
                  onChanged: (v) => tipo = v!,
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'sku': skuController.text,
                      'cantidad': int.tryParse(cantidadController.text) ?? 1,
                      'tipo': tipo
                    });
                  },
                  child: const Text('Agregar'))
            ],
          );
        },
      ),
    );

    if (result == null) return;

    final producto = await supabase
        .from('productos')
        .select()
        .or('sku.eq.${result['sku']},codigo.eq.${result['sku']}')
        .maybeSingle();

    if (producto == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto no encontrado')),
      );
      return;
    }

    await supabase.from('recepcion_detalle').insert({
      'recepcion_id': widget.recepcion['id'],
      'codigo': producto['codigo'],
      'nombre': producto['nombre'],
      'cantidad': result['cantidad'],
      'precio': producto['precio'],
      'tipo': result['tipo'],
    });

    cargarDetalle();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recepcion;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle Recepción')),

      floatingActionButton: FloatingActionButton(
        onPressed: agregarProducto,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Devolución buena: ${currencyFormat.format(r['total_devolucion_buena'] ?? 0)}',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Averías: ${currencyFormat.format(r['total_averias'] ?? 0)}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: detalles.length,
                    itemBuilder: (_, i) {
                      final d = detalles[i];

                      final esAveria = d['tipo'] == 'averia';

                      return Card(
                        color: esAveria
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        child: ListTile(
                          title: Text(
                            d['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Cant: ${d['cantidad']} - ${d['tipo']}",
                            style: TextStyle(
                              color: esAveria ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => editarCantidad(d),
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
