import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/models/wms_models.dart';

void main() {
  group('ItemModel Parsing & Logika Stok', () {
    test('Parsing lengkap JSON dari Supabase termasuk relasi categories', () {
      final item = ItemModel.fromJson({
        'id': 'item-001',
        'sku': 'WJN-32-GRN',
        'name': 'Wajan Wok Granite 32cm',
        'category_id': 'cat-01',
        'categories': {'name': 'Panci & Wajan'},
        'unit': 'pcs',
        'pack_label': 'lusin',
        'pack_qty': 12,
        'current_stock': 48,
        'min_stock': 10,
        'buy_price': 85000,
        'sell_price': 125000,
        'sell_price_pack': 1400000,
        'rack_location': 'A1',
        'is_active': true,
      });

      expect(item.id, 'item-001');
      expect(item.sku, 'WJN-32-GRN');
      expect(item.categoryName, 'Panci & Wajan');
      expect(item.currentStock, 48);
      expect(item.rackLocation, 'A1');
      expect(item.isLowStock, isFalse);
      expect(item.hasPack, isTrue);
      expect(item.packBreakdown, '4 lusin');
    });

    test('Konversi packBreakdown dengan sisa pcs', () {
      final item = ItemModel.fromJson({
        'id': 'item-002',
        'sku': 'SDK-01-SS',
        'name': 'Sendok Makan Stainless',
        'unit': 'pcs',
        'pack_label': 'lusin',
        'pack_qty': 12,
        'current_stock': 29,
        'min_stock': 12,
      });

      expect(item.packBreakdown, '2 lusin + 5 pcs');
    });

    test('Deteksi stok menipis (isLowStock) dan stok habis', () {
      final menipis = ItemModel.fromJson({
        'id': 'item-003',
        'sku': 'PRC-08-SS',
        'name': 'Panci Presto 8L',
        'unit': 'pcs',
        'current_stock': 5,
        'min_stock': 5,
      });

      final habis = ItemModel.fromJson({
        'id': 'item-004',
        'sku': 'PSU-06-CHF',
        'name': 'Set Pisau Dapur 6 Pcs',
        'unit': 'pcs',
        'current_stock': 0,
        'min_stock': 3,
      });

      expect(menipis.isLowStock, isTrue);
      expect(habis.isLowStock, isTrue);
    });
  });

  group('CategoryModel & StockTransactionModel', () {
    test('CategoryModel parsing id dan nama', () {
      final cat = CategoryModel.fromJson({
        'id': 'cat-10',
        'name': 'Wadah & Saringan',
      });

      expect(cat.id, 'cat-10');
      expect(cat.name, 'Wadah & Saringan');
    });

    test('StockTransactionModel parsing relasi items dan kuantitas', () {
      final tx = StockTransactionModel.fromJson({
        'id': 'tx-99',
        'item_id': 'item-001',
        'type': 'IN',
        'quantity': 24,
        'transaction_date': '2026-11-27T08:00:00Z',
        'items': {
          'name': 'Wajan Wok Granite 32cm',
          'sku': 'WJN-32-GRN',
          'unit': 'pcs',
          'pack_label': 'lusin',
        },
      });

      expect(tx.type, 'IN');
      expect(tx.quantity, 24);
      expect(tx.itemName, 'Wajan Wok Granite 32cm');
      expect(tx.itemUnit, 'pcs');
    });
  });

  group('Utilitas Format Rupiah', () {
    test('Memformat nominal positif dan nol dengan benar', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(9500), 'Rp 9.500');
      expect(formatRupiah(1250000), 'Rp 1.250.000');
    });
  });
}
