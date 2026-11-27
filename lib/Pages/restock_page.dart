import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

class RestockPage extends StatefulWidget {
  const RestockPage({super.key});

  @override
  State<RestockPage> createState() => _RestockPageState();
}

class _RestockPageState extends State<RestockPage> {
  bool _isLoading = true;
  List<_RestockPlanItem> _lowItems = [];

  @override
  void initState() {
    super.initState();
    _loadLowStockItems();
  }

  Future<void> _loadLowStockItems() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('items')
          .select('*, categories(name)')
          .eq('is_active', true)
          .order('current_stock', ascending: true);

      final all = (res as List<dynamic>)
          .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
          .where((item) => item.isLowStock)
          .toList();

      final plans = all.map((item) {
        final rawNeed =
            ((item.minStock * 2) - item.currentStock).clamp(1, 9999);
        final int suggestedPcs;
        if (item.hasPack && item.packQty > 1) {
          final packs = (rawNeed / item.packQty).ceil();
          suggestedPcs = packs * item.packQty;
        } else {
          suggestedPcs = rawNeed;
        }
        return _RestockPlanItem(item: item, orderQtyPcs: suggestedPcs);
      }).toList();

      if (!mounted) return;
      setState(() {
        _lowItems = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat daftar restock: $e')),
      );
    }
  }

  num get _totalEstimatedCost {
    num total = 0;
    for (final p in _lowItems) {
      total += p.item.buyPrice * p.orderQtyPcs;
    }
    return total;
  }

  void _updateOrderQty(int index, int delta) {
    final current = _lowItems[index];
    final step = current.item.hasPack ? current.item.packQty : 1;
    final next = (current.orderQtyPcs + (delta * step)).clamp(step, 99999);
    setState(() {
      _lowItems[index] = _RestockPlanItem(
        item: current.item,
        orderQtyPcs: next,
      );
    });
  }

  Future<void> _copyWhatsAppFormat() async {
    if (_lowItems.isEmpty) return;
    final now = DateTime.now();
    final tgl =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final buf = StringBuffer()
      ..writeln('*ORDER RESTOCK GUDANG ARASY39*')
      ..writeln('Tanggal: $tgl')
      ..writeln('Total Item: ${_lowItems.length} SKU')
      ..writeln('-----------------------------');

    for (int i = 0; i < _lowItems.length; i++) {
      final p = _lowItems[i];
      final item = p.item;
      final qtyLabel = item.hasPack
          ? '${p.orderQtyPcs ~/ item.packQty} ${item.packLabel} (${p.orderQtyPcs} ${item.unit})'
          : '${p.orderQtyPcs} ${item.unit}';
      buf.writeln('${i + 1}. [${item.sku}] ${item.name} — *$qtyLabel*');
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Daftar order berhasil disalin! Siap ditempel ke WhatsApp'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        title: const Text('Daftar Belanja Restock'),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            onPressed: _loadLowStockItems,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lowItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: Color(0xFF059669),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Semua stok barang dalam kondisi aman!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE8EEF5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Estimasi Total Modal Belanja',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _totalEstimatedCost > 0
                                        ? formatRupiah(_totalEstimatedCost)
                                        : 'Harga beli belum diisi',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_lowItems.length} SKU',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                        itemCount: _lowItems.length,
                        itemBuilder: (context, index) {
                          final plan = _lowItems[index];
                          final item = plan.item;
                          final subtotal = item.buyPrice * plan.orderQtyPcs;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE8EEF5)),
                            ),
                            child: Row(
                              children: [
                                CategoryAvatar(
                                  categoryName: item.categoryName,
                                  skuPrefix: item.sku.split('-').first,
                                  imageUrl: item.imageUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Sisa: ${item.currentStock} / Min: ${item.minStock} ${item.unit.toLowerCase()}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                      if (subtotal > 0) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Est: ${formatRupiah(subtotal)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _updateOrderQty(index, -1),
                                        icon: const Icon(
                                          Icons.remove_rounded,
                                          size: 16,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '${plan.orderQtyPcs}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _updateOrderQty(index, 1),
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 16,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _lowItems.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _copyWhatsAppFormat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    label: const Text(
                      'Salin Daftar Order untuk WhatsApp',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _RestockPlanItem {
  final ItemModel item;
  final int orderQtyPcs;

  _RestockPlanItem({required this.item, required this.orderQtyPcs});
}
