import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    double total = items.fold(
      0,
      (sum, item) => sum + (item['subtotal'] ?? 0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(
          "Detalle $vehiculo",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              "Items registrados: ${items.length}",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  elevation: 1.4,
                  margin: const EdgeInsets.only(bottom: 10),
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
                        alpha: 0.10,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF0A2A5E),
                      ),
                    ),
                    title: Text(
                      item['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "Cant: ${item['cantidad_faltante']} x ${currencyFormat.format(item['precio'] ?? 0)}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    trailing: Text(
                      currencyFormat.format(item['subtotal'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A5E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "TOTAL: ${currencyFormat.format(total)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A2A5E),
              ),
            ),
          )
        ],
      ),
    );
  }
}
