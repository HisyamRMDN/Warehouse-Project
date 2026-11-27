import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/item_detail_sheet.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

void main() {
  group('ItemModel & imageUrl Parsing Tests', () {
    test(
        'ItemModel memetakan image_url dari JSON Supabase dan membersihkan spasi',
        () {
      final item = ItemModel.fromJson({
        'id': 'item-001',
        'sku': 'GLS-001',
        'name': 'Gelas Metal Minum Silinder untuk Es Teh',
        'category_id': 'cat-1',
        'categories': {'name': 'Gelas & Termos'},
        'unit': 'Pcs',
        'current_stock': 80,
        'min_stock': 5,
        'rack_location': 'A-01',
        'pack_qty': 12,
        'pack_label': 'lusin',
        'buy_price': 12000,
        'sell_price': 20000,
        'image_url':
            '  https://cf.shopee.co.id/file/id-11134201-81zto-muk2v3gl6gw122  ',
      });

      expect(item.sku, 'GLS-001');
      expect(item.imageUrl,
          'https://cf.shopee.co.id/file/id-11134201-81zto-muk2v3gl6gw122');
      expect(item.sellPrice, 20000);
      expect(item.buyPrice, 12000);
      expect(item.isLowStock, isFalse);
    });

    test('ItemModel menangani image_url null atau kosong dengan aman', () {
      final item = ItemModel.fromJson({
        'id': 'item-002',
        'sku': 'PNC-001',
        'name': 'Milk Pan Honey Comb 18',
        'unit': 'Pcs',
        'current_stock': 3,
        'min_stock': 5,
        'image_url': null,
      });

      expect(item.imageUrl, isNull);
      expect(item.isLowStock, isTrue);
    });
  });

  group('CategoryAvatar Widget Tests (Foto Shopee & Fallback Ikon)', () {
    testWidgets(
        'Menampilkan ikon kategori Google Material jika imageUrl kosong',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryAvatar(
              categoryName: 'Panci & Wajan',
              skuPrefix: 'PNC',
              imageUrl: null,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.soup_kitchen_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Merender Image.network saat imageUrl tersedia',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryAvatar(
              categoryName: 'Panci & Wajan',
              skuPrefix: 'PNC',
              imageUrl: 'https://cf.shopee.co.id/file/sample-image',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('ItemDetailSheet Widget Tests', () {
    final sampleItem = ItemModel(
      id: 'item-detail-1',
      sku: 'PNC-003-24CM',
      name: 'Panci Kukus Steamer 304 Stainless - 24 cm',
      categoryName: 'Panci & Wajan',
      unit: 'Pcs',
      currentStock: 4,
      minStock: 5,
      rackLocation: 'B-02',
      packQty: 1,
      buyPrice: 400000,
      sellPrice: 550000,
    );

    testWidgets(
        'Menampilkan informasi stok, lokasi rak, harga, margin, dan tombol edit untuk Admin',
        (tester) async {
      bool editTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemDetailSheet(
              item: sampleItem,
              isAdmin: true,
              onEditPressed: () {
                editTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('PNC-003-24CM'), findsOneWidget);
      expect(find.text('Panci Kukus Steamer 304 Stainless - 24 cm'),
          findsOneWidget);
      expect(find.text('4 pcs'), findsOneWidget);
      expect(find.text('B-02'), findsOneWidget);
      // Margin (550.000 - 400.000) / 400.000 = +38%
      expect(find.text('+38%'), findsOneWidget);
      expect(find.text('Edit Detail & Harga Barang'), findsOneWidget);

      await tester.tap(find.text('Edit Detail & Harga Barang'));
      await tester.pumpAndSettle();
      expect(editTriggered, isTrue);
    });

    testWidgets(
        'Menyembunyikan tombol edit barang untuk akun Operator (non-Admin)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemDetailSheet(
              item: sampleItem,
              isAdmin: false,
            ),
          ),
        ),
      );

      expect(find.text('PNC-003-24CM'), findsOneWidget);
      expect(find.text('Edit Detail & Harga Barang'), findsNothing);
    });
  });
}
