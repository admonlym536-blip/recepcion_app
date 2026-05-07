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

  String _normalizarTipo(dynamic tipoRaw) {
    return (tipoRaw ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('ó', 'o')
        .replaceAll('í', 'i')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ú', 'u');
  }

  bool _esDevolucionBuena(String tipo) {
    return tipo == 'devolucion buena' ||
        tipo == 'devolucion_buena' ||
        tipo == 'dev buena';
  }

  bool _esMalManejo(String tipo) {
    return tipo == 'dev_mal_manejo' ||
        tipo == 'dev mal manejo' ||
        tipo == 'devolucion por mal manejo' ||
        tipo == 'devolucion mal manejo';
  }

  late Map<String, dynamic> recepcionActual;
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
    recepcionActual = Map<String, dynamic>.from(widget.recepcion);
    cargarDetalle();
  }

  Future<void> cargarDetalle() async {
    final data = await supabase
        .from('recepcion_detalle')
        .select()
        .eq('recepcion_id', widget.recepcion['id']);

    double totalGeneral = 0;
    double totalDevolucionBuena = 0;
    double totalAverias = 0;
    double totalMalManejo = 0;

    for (final row in data) {
      final cantidad = (row['cantidad'] as num?) ?? 0;
      final precio = (row['precio'] as num?) ?? 0;
      final subtotal = cantidad * precio;
      final tipo = _normalizarTipo(row['tipo']);

      totalGeneral += subtotal;
      if (tipo == 'averia') {
        totalAverias += subtotal;
      } else if (_esMalManejo(tipo)) {
        totalMalManejo += subtotal;
      } else if (_esDevolucionBuena(tipo)) {
        totalDevolucionBuena += subtotal;
      }
    }

    setState(() {
      detalles = data;
      recepcionActual['total'] = totalGeneral;
      recepcionActual['total_devolucion_buena'] = totalDevolucionBuena;
      recepcionActual['total_averias'] = totalAverias;
      recepcionActual['total_dev_mal_manejo'] = totalMalManejo;
      loading = false;
    });

    await supabase.from('recepciones').update({
      'total': totalGeneral,
      'total_devolucion_buena': totalDevolucionBuena,
      'total_averias': totalAverias,
      'total_dev_mal_manejo': totalMalManejo,
    }).eq('id', widget.recepcion['id']);
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

    if (nuevaCantidad <= 0) {
      await supabase
          .from('recepcion_detalle')
          .delete()
          .eq('id', item['id']);
    } else {
      await supabase
          .from('recepcion_detalle')
          .update({'cantidad': nuevaCantidad}).eq('id', item['id']);
    }

    await recalcularTotalesRecepcion();
    await cargarDetalle();
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
                        .or('sku.eq.$value,codigo.eq.$value')
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
                    final sku = skuController.text.trim();
                    final cantidad = int.tryParse(cantidadController.text) ?? 0;

                    if (sku.isEmpty || cantidad <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingrese SKU y cantidad válida'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, {
                      'sku': sku,
                      'cantidad': cantidad,
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

    await recalcularTotalesRecepcion();
    await cargarDetalle();
  }

  Future<void> recalcularTotalesRecepcion({bool silent = false}) async {
    final data = await supabase
        .from('recepcion_detalle')
        .select('cantidad, precio, tipo')
        .eq('recepcion_id', widget.recepcion['id']);

    double totalGeneral = 0;
    double totalDevolucionBuena = 0;
    double totalAverias = 0;
    double totalMalManejo = 0;

    for (final row in data) {
      final cantidad = (row['cantidad'] as num?) ?? 0;
      final precio = (row['precio'] as num?) ?? 0;
      final subtotal = cantidad * precio;
      final tipo = _normalizarTipo(row['tipo']);

      totalGeneral += subtotal;

      if (tipo == 'averia') {
        totalAverias += subtotal;
      } else if (_esMalManejo(tipo)) {
        totalMalManejo += subtotal;
      } else if (_esDevolucionBuena(tipo)) {
        totalDevolucionBuena += subtotal;
      }
    }

    await supabase.from('recepciones').update({
      'total': totalGeneral,
      'total_devolucion_buena': totalDevolucionBuena,
      'total_averias': totalAverias,
      'total_dev_mal_manejo': totalMalManejo,
    }).eq('id', widget.recepcion['id']);

    if (!silent) {
      await supabase
          .from('recepciones')
          .select(
              'total, total_devolucion_buena, total_averias, total_dev_mal_manejo')
          .eq('id', widget.recepcion['id'])
          .single();
    }

    setState(() {
      recepcionActual['total'] = totalGeneral;
      recepcionActual['total_devolucion_buena'] = totalDevolucionBuena;
      recepcionActual['total_averias'] = totalAverias;
      recepcionActual['total_dev_mal_manejo'] = totalMalManejo;

      // Compatibilidad temporal:
      // Si en la lista viene intercambiado D y M, aquí lo corregimos para mostrar bien.
      final d = (recepcionActual['total_devolucion_buena'] as num?) ?? 0;
      final m = (recepcionActual['total_dev_mal_manejo'] as num?) ?? 0;
      if (d == 0 && m > 0) {
        recepcionActual['total_devolucion_buena'] = m;
        recepcionActual['total_dev_mal_manejo'] = 0;
      }
    });
  }

  Widget _montoChip(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$titulo: $valor',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = recepcionActual;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Detalle Recepción'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: agregarProducto,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Planilla: ${r['planilla']} • Placa: ${r['placa']}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(r['total'] ?? 0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A2A5E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _montoChip(
                            "Devolución buena",
                            currencyFormat
                                .format(r['total_devolucion_buena'] ?? 0),
                            const Color(0xFF2E7D32),
                          ),
                          _montoChip(
                            "Averías",
                            currencyFormat.format(r['total_averias'] ?? 0),
                            const Color(0xFFC62828),
                          ),
                          _montoChip(
                            "Mal manejo",
                            currencyFormat
                                .format(r['total_dev_mal_manejo'] ?? 0),
                            const Color(0xFFEF6C00),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: detalles.length,
                    itemBuilder: (_, i) {
                      final d = detalles[i];
                      final tipo = (d['tipo'] ?? '').toString();
                      final esAveria = tipo == 'averia';
                      final esMalManejo = tipo == 'dev_mal_manejo';
                      final colorTipo = esAveria
                          ? const Color(0xFFC62828)
                          : (esMalManejo
                              ? const Color(0xFFEF6C00)
                              : const Color(0xFF2E7D32));

                      return Card(
                        elevation: 1.2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: colorTipo.withValues(alpha: 0.12),
                            child: Icon(Icons.inventory_2, color: colorTipo),
                          ),
                          title: Text(
                            d['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            "Cant: ${d['cantidad']} • ${d['tipo']}",
                            style: TextStyle(
                              color: colorTipo,
                              fontWeight: FontWeight.w600,
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
