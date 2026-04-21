import 'package:flutter/material.dart';

class DetalleSalidaPage extends StatelessWidget {
  final String vehiculo;
  final List<Map<String, dynamic>> items;

  const DetalleSalidaPage({
    super.key,
    required this.vehiculo,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    double total = items.fold(
      0,
      (sum, item) => sum + (item['subtotal'] ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Detalle $vehiculo"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(item['nombre']),
                    subtitle: Text(
                      "Cant: ${item['cantidad_faltante']} x \$${item['precio']}",
                    ),
                    trailing: Text(
                      "\$${item['subtotal'].toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(15),
            width: double.infinity,
            color: Colors.grey[200],
            child: Text(
              "TOTAL: \$${total.toStringAsFixed(0)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }
}