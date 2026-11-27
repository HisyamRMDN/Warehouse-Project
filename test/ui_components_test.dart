import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

void main() {
  group('WmsCategoryStyle (Google Material Icons)', () {
    test('Memetakan kategori dapur ke ikon Google Material yang tepat', () {
      expect(
        WmsCategoryStyle.icon('Panci & Wajan'),
        Icons.soup_kitchen_outlined,
      );
      expect(
        WmsCategoryStyle.icon('Mangkok & Piring'),
        Icons.rice_bowl_outlined,
      );
      expect(
        WmsCategoryStyle.icon('Gelas & Termos'),
        Icons.local_cafe_outlined,
      );
    });
  });

  group('StockBadge Widget', () {
    testWidgets('Menampilkan teks stok dan rincian lusin', (tester) async {
      final item = ItemModel.fromJson({
        'id': '1',
        'sku': 'SDK-01',
        'name': 'Sendok Makan',
        'unit': 'pcs',
        'pack_label': 'lusin',
        'pack_qty': 12,
        'current_stock': 24,
        'min_stock': 6,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StockBadge(item: item)),
        ),
      );

      expect(find.text('24 pcs'), findsOneWidget);
      expect(find.text('2 lusin'), findsOneWidget);
    });
  });

  group('WmsStatCard & WmsSectionHeader', () {
    testWidgets('WmsStatCard merender judul, nilai, dan memicu onTap',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WmsStatCard(
              title: 'Nilai Modal Stok',
              value: 'Rp 12.500.000',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Nilai Modal Stok'), findsOneWidget);
      expect(find.text('Rp 12.500.000'), findsOneWidget);

      await tester.tap(find.byType(WmsStatCard));
      expect(tapped, isTrue);
    });

    testWidgets('WmsSectionHeader menampilkan judul dan subjudul',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WmsSectionHeader(
              title: 'Kategori Barang',
              subtitle: '7 kelompok produk terdaftar',
            ),
          ),
        ),
      );

      expect(find.text('Kategori Barang'), findsOneWidget);
      expect(find.text('7 kelompok produk terdaftar'), findsOneWidget);
    });
  });

  group('WmsSearchBar Widget', () {
    testWidgets(
        'Menampilkan ikon scanner saat kosong dan ikon hapus saat terisi',
        (tester) async {
      final ctrl = TextEditingController();
      String query = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => WmsSearchBar(
                controller: ctrl,
                hasText: ctrl.text.isNotEmpty,
                onChanged: (v) => setState(() => query = v),
                onClear: () => setState(() {
                  ctrl.clear();
                  query = '';
                }),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Panci');
      await tester.pump();

      expect(query, 'Panci');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(ctrl.text, isEmpty);
    });
  });
}
