class CategoryModel {
  final String id;
  final String name;

  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class ItemModel {
  final String id;
  final String sku;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String unit;
  final int currentStock;
  final int minStock;
  final String? rackLocation;
  final int packQty;
  final String packLabel;
  final num buyPrice;
  final num sellPrice;
  final num? sellPricePack;
  final String? imageUrl; // <-- Tambahkan ini

  ItemModel({
    required this.id,
    required this.sku,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    this.rackLocation,
    this.packQty = 1,
    this.packLabel = 'lusin',
    this.buyPrice = 0,
    this.sellPrice = 0,
    this.sellPricePack,
    this.imageUrl, // <-- Tambahkan ini
  });

  bool get isLowStock => currentStock <= minStock;

  bool get hasPack => packQty > 1;

  /// Contoh: stok 30 pcs, isi 12 -> "2 lusin + 6 Pcs". Null jika tak relevan.
  String? get packBreakdown {
    if (!hasPack) return null;
    final packs = currentStock ~/ packQty;
    final rest = currentStock % packQty;
    if (packs == 0) return null;
    return rest == 0 ? '$packs $packLabel' : '$packs $packLabel + $rest $unit';
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final categoryData = json['categories'] as Map<String, dynamic>?;
    return ItemModel(
      id: json['id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: categoryData?['name'] as String?,
      unit: (json['unit'] as String?) ?? 'Pcs',
      currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      minStock: (json['min_stock'] as num?)?.toInt() ?? 5,
      rackLocation: json['rack_location'] as String?,
      packQty: (json['pack_qty'] as num?)?.toInt() ?? 1,
      packLabel: (json['pack_label'] as String?) ?? 'lusin',
      buyPrice: (json['buy_price'] as num?) ?? 0,
      sellPrice: (json['sell_price'] as num?) ?? 0,
      sellPricePack: json['sell_price_pack'] as num?,
      imageUrl: (json['image_url'] as String?)?.trim(),
    );
  }
}

class StockTransactionModel {
  final String id;
  final String itemId;
  final String itemName;
  final String itemSku;
  final String itemUnit;
  final String itemPackLabel;
  final String type; // 'IN', 'OUT', atau 'ADJUSTMENT'
  final int quantity; // selalu dalam pcs (ADJUSTMENT bisa negatif)
  final String inputUnit; // 'pcs' atau 'pack'
  final int? inputQty; // jumlah sesuai satuan input
  final num? unitPrice; // harga per pcs saat transaksi
  final String? reason;
  final String? channel;
  final String? refNo;
  final String? notes;
  final DateTime transactionDate;

  StockTransactionModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.itemUnit,
    this.itemPackLabel = 'lusin',
    required this.type,
    required this.quantity,
    this.inputUnit = 'pcs',
    this.inputQty,
    this.unitPrice,
    this.reason,
    this.channel,
    this.refNo,
    this.notes,
    required this.transactionDate,
  });

  factory StockTransactionModel.fromJson(Map<String, dynamic> json) {
    final itemData = json['items'] as Map<String, dynamic>?;
    return StockTransactionModel(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemName: (itemData?['name'] as String?) ?? 'Barang Dihapus',
      itemSku: (itemData?['sku'] as String?) ?? '-',
      itemUnit: (itemData?['unit'] as String?) ?? 'Pcs',
      itemPackLabel: (itemData?['pack_label'] as String?) ?? 'lusin',
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toInt(),
      inputUnit: (json['input_unit'] as String?) ?? 'pcs',
      inputQty: (json['input_qty'] as num?)?.toInt(),
      unitPrice: json['unit_price'] as num?,
      reason: json['reason'] as String?,
      channel: json['channel'] as String?,
      refNo: json['ref_no'] as String?,
      notes: json['notes'] as String?,
      transactionDate:
          DateTime.parse(json['transaction_date'] as String).toLocal(),
    );
  }
}
