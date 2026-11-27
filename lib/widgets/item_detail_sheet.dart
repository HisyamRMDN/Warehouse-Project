import 'package:flutter/material.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

class ItemDetailSheet extends StatefulWidget {
  final ItemModel item;
  final bool isAdmin;
  final VoidCallback? onEditPressed;

  const ItemDetailSheet({
    super.key,
    required this.item,
    this.isAdmin = false,
    this.onEditPressed,
  });

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  bool _isLoadingLedger = true;
  List<StockTransactionModel> _ledger = [];

  @override
  void initState() {
    super.initState();
    _fetchItemLedger();
  }

  Future<void> _fetchItemLedger() async {
    setState(() => _isLoadingLedger = true);
    try {
      final res = await supabase
          .from('stock_transactions')
          .select('*, items(name, sku, unit, pack_label)')
          .eq('item_id', widget.item.id)
          .order('transaction_date', ascending: false)
          .limit(30);

      if (!mounted) return;
      setState(() {
        _ledger = (res as List<dynamic>)
            .map((e) =>
                StockTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoadingLedger = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingLedger = false);
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} • $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasMargin = item.buyPrice > 0 && item.sellPrice > 0;
    final marginValue = item.sellPrice - item.buyPrice;
    final marginPercent =
        item.buyPrice > 0 ? ((marginValue / item.buyPrice) * 100).round() : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 600,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Produk
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryAvatar(
                  categoryName: item.categoryName,
                  skuPrefix: item.sku.split('-').first,
                  imageUrl: item.imageUrl,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.sku,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (item.categoryName != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.categoryName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF155EEF),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grid Metrik Stok, Rak, Min Stok
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBox(
                          label: 'Stok Fisik',
                          value:
                              '${item.currentStock} ${item.unit.toLowerCase()}',
                          subValue: item.packBreakdown,
                          accent: item.isLowStock
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                          bg: item.isLowStock
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFECFDF5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricBox(
                          label: 'Batas Min.',
                          value: '${item.minStock} ${item.unit.toLowerCase()}',
                          subValue: item.isLowStock ? 'Perlu Restock' : 'Aman',
                          accent: const Color(0xFF334155),
                          bg: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricBox(
                          label: 'Lokasi Rak',
                          value: (item.rackLocation == null ||
                                  item.rackLocation!.isEmpty)
                              ? '-'
                              : item.rackLocation!,
                          subValue: item.hasPack
                              ? '1 lusin = ${item.packQty}'
                              : 'Satuan ecer',
                          accent: const Color(0xFF155EEF),
                          bg: const Color(0xFFEFF6FF),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Kartu Harga & Estimasi Margin
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Harga Beli',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.buyPrice > 0
                                    ? formatRupiah(item.buyPrice)
                                    : '-',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Harga Jual',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.sellPrice > 0
                                    ? formatRupiah(item.sellPrice)
                                    : '-',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF155EEF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasMargin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: marginValue >= 0
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${marginValue >= 0 ? '+' : ''}$marginPercent%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: marginValue >= 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Header Timeline Riwayat Per-SKU
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 17,
                        color: Color(0xFF155EEF),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'RIWAYAT MUTASI BARANG INI',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_ledger.length} catatan',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoadingLedger)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_ledger.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Belum ada riwayat mutasi untuk SKU ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ledger.length,
                      itemBuilder: (context, index) {
                        final tx = _ledger[index];
                        final isOpname =
                            (tx.notes ?? '').toLowerCase().contains('opname');
                        final delta =
                            tx.type == 'OUT' ? -tx.quantity : tx.quantity;
                        final isInbound = delta > 0;
                        final isLast = index == _ledger.length - 1;

                        final Color dotColor = isOpname
                            ? const Color(0xFF155EEF)
                            : isInbound
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706);

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Garis vertikal timeline + titik indikator
                              SizedBox(
                                width: 24,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(top: 5),
                                      decoration: BoxDecoration(
                                        color: dotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE8EEF5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isOpname
                                                    ? 'Stock Opname'
                                                    : isInbound
                                                        ? 'Barang Masuk'
                                                        : 'Barang Keluar',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatDate(tx.transactionDate),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              if (tx.notes != null &&
                                                  tx.notes!.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  tx.notes!,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${isInbound ? '+' : '-'}${delta.abs()} ${item.unit.toLowerCase()}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: dotColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Tombol Edit Produk di Footer (khusus Admin)
          if (widget.isAdmin && widget.onEditPressed != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEditPressed!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF155EEF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit Detail & Harga Barang',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color accent;
  final Color bg;

  const _MetricBox({
    required this.label,
    required this.value,
    this.subValue,
    required this.accent,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          if (subValue != null && subValue!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subValue!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
