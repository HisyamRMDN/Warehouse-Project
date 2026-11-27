import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

void main() {
  group('Logika Model & Format', () {
    test('Deteksi stok menipis (isLowStock)', () {
      final aman = ItemModel.fromJson({
        'id': '1',
        'sku': 'PNC-001',
        'name': 'Panci Kukus 24cm',
        'unit': 'pcs',
        'current_stock': 15,
        'min_stock': 5,
      });

      final menipis = ItemModel.fromJson({
        'id': '2',
        'sku': 'WJN-002',
        'name': 'Wajan Teflon 26cm',
        'unit': 'pcs',
        'current_stock': 5,
        'min_stock': 5,
      });

      expect(aman.isLowStock, isFalse);
      expect(menipis.isLowStock, isTrue);
    });

    test('Konversi pcs ke lusin (packBreakdown)', () {
      final sendok = ItemModel.fromJson({
        'id': '3',
        'sku': 'ALM-001',
        'name': 'Sendok Makan Stainless',
        'unit': 'pcs',
        'pack_label': 'lusin',
        'pack_qty': 12,
        'current_stock': 26,
        'min_stock': 12,
      });

      expect(sendok.hasPack, isTrue);
      expect(sendok.packBreakdown, equals('2 lusin + 2 pcs'));
    });

    test('Format Rupiah', () {
      expect(formatRupiah(125000), equals('Rp 125.000'));
    });
  });

  group('Komponen UI Reusable', () {
    testWidgets('StockBadge menampilkan jumlah stok dan satuan',
        (tester) async {
      final item = ItemModel.fromJson({
        'id': '4',
        'sku': 'MPK-001',
        'name': 'Mangkok Keramik',
        'unit': 'pcs',
        'current_stock': 36,
        'min_stock': 10,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StockBadge(item: item)),
        ),
      );

      expect(find.text('36 pcs'), findsOneWidget);
    });
  });
}
