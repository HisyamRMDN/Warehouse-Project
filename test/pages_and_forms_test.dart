import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_project/Pages/loginPage.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/item_form_dialog.dart';

void main() {
  group('LoginPage UI & Validasi', () {
    testWidgets('Merender elemen utama layar Masuk ke Gudang', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginPage()),
      );

      expect(find.text('Arasy39 WMS'), findsOneWidget);
      expect(find.text('Masuk ke Gudang'), findsNWidgets(2));
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Menampilkan peringatan jika login ditekan saat kosong',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginPage()),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk ke Gudang'));
      await tester.pump();

      expect(
        find.text('Username dan password wajib diisi'),
        findsOneWidget,
      );
    });

    testWidgets('Toggle visibilitas password berfungsi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginPage()),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('ItemFormDialog UI & Validasi', () {
    final categories = [
      CategoryModel(id: 'c1', name: 'Panci & Wajan'),
      CategoryModel(id: 'c2', name: 'Wadah'),
    ];

    testWidgets('Mode Tambah Barang menampilkan form input dan tombol aksi',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormDialog(
              categories: categories,
              onSaved: () async {},
            ),
          ),
        ),
      );

      expect(find.byType(ItemFormDialog), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Mode Edit Barang mengisi otomatis data barang yang dipilih',
        (tester) async {
      final existingItem = ItemModel.fromJson({
        'id': 'item-10',
        'sku': 'WJN-32-GRN',
        'name': 'Wajan Wok Granite 32cm',
        'category_id': 'c1',
        'unit': 'pcs',
        'current_stock': 48,
        'min_stock': 10,
        'buy_price': 85000,
        'sell_price': 125000,
        'rack_location': 'A1',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormDialog(
              item: existingItem,
              categories: categories,
              onSaved: () async {},
            ),
          ),
        ),
      );

      expect(find.byType(ItemFormDialog), findsOneWidget);
      expect(find.text('WJN-32-GRN'), findsOneWidget);
      expect(find.text('Wajan Wok Granite 32cm'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
    });
  });
}
