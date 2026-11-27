import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';
import 'package:flutter/services.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const int _pageSize = 30;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<StockTransactionModel> _transactions = [];
  String _searchQuery = '';
  String _filterType = 'ALL'; // 'ALL' | 'IN' | 'OUT' | 'OPNAME'

  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchHistory(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 240) {
      _fetchHistory(reset: false);
    }
  }

  Future<void> _exportCsvToClipboard() async {
    if (_transactions.isEmpty) return;
    final buf = StringBuffer()
      ..writeln(
          'Tanggal,SKU,Nama Barang,Jenis,Jumlah,Satuan,Channel,Ref,Catatan');

    for (final tx in _transactions) {
      final delta = tx.type == 'OUT' ? -tx.quantity : tx.quantity;
      final safeName = '"${tx.itemName.replaceAll('"', '""')}"';
      final safeNotes = '"${(tx.notes ?? '').replaceAll('"', '""')}"';
      buf.writeln(
        '${_formatDateTime(tx.transactionDate)},${tx.itemSku},$safeName,${tx.type},$delta,${tx.itemUnit},${tx.channel ?? ''},${tx.refNo ?? ''},$safeNotes',
      );
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_transactions.length} baris riwayat CSV disalin (siap tempel ke Excel/Sheets)',
        ),
      ),
    );
  }

  Future<void> _fetchHistory({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final from = reset ? 0 : _transactions.length;
      final to = from + _pageSize - 1;

      var query = supabase
          .from('stock_transactions')
          .select('*, items(name, sku, unit, pack_label)');

      if (_filterType == 'IN') {
        query = query.eq('type', 'IN');
      } else if (_filterType == 'OUT') {
        query = query.eq('type', 'OUT');
      } else if (_filterType == 'OPNAME') {
        query = query.ilike('notes', '%Opname%');
      }

      final response = await query
          .order('transaction_date', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final rawList = response.data as List<dynamic>;
      var fetched = rawList
          .map((e) => StockTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        fetched = fetched.where((tx) {
          return tx.itemName.toLowerCase().contains(q) ||
              tx.itemSku.toLowerCase().contains(q) ||
              (tx.refNo?.toLowerCase().contains(q) ?? false) ||
              (tx.notes?.toLowerCase().contains(q) ?? false);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        if (reset) {
          _transactions = fetched;
        } else {
          _transactions.addAll(fetched);
        }
        _totalCount = response.count;
        _hasMore = rawList.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat riwayat: $e')),
      );
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = val);
      _fetchHistory(reset: true);
    });
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} • $h:$min WIB';
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'shopee':
        return 'Shopee';
      case 'tokopedia':
        return 'Tokopedia';
      case 'offline':
        return 'Offline';
      default:
        return channel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        title: const Text('Riwayat Mutasi Stok'),
        actions: [
          IconButton(
            tooltip: 'Salin CSV ke Excel',
            onPressed: _transactions.isEmpty ? null : _exportCsvToClipboard,
            icon: const Icon(
              Icons.table_view_outlined,
              color: Color(0xFF155EEF),
              size: 21,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: WmsSearchBar(
              controller: _searchCtrl,
              hasText: _searchQuery.isNotEmpty,
              hintText: 'Cari nama barang, SKU, atau no. pesanan...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
                _fetchHistory(reset: true);
              },
            ),
          ),

          // Filter Pill: Semua | Masuk | Keluar | Opname
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _HistoryFilterPill(
                  label: 'Semua',
                  selected: _filterType == 'ALL',
                  onTap: () {
                    setState(() => _filterType = 'ALL');
                    _fetchHistory(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                _HistoryFilterPill(
                  label: 'Masuk (IN)',
                  icon: Icons.south_west_rounded,
                  selected: _filterType == 'IN',
                  onTap: () {
                    setState(() => _filterType = 'IN');
                    _fetchHistory(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                _HistoryFilterPill(
                  label: 'Keluar (OUT)',
                  icon: Icons.north_east_rounded,
                  selected: _filterType == 'OUT',
                  onTap: () {
                    setState(() => _filterType = 'OUT');
                    _fetchHistory(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                _HistoryFilterPill(
                  label: 'Opname',
                  icon: Icons.tune_rounded,
                  selected: _filterType == 'OPNAME',
                  onTap: () {
                    setState(() => _filterType = 'OPNAME');
                    _fetchHistory(reset: true);
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menampilkan ${_transactions.length} dari $_totalCount catatan mutasi',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada riwayat mutasi yang cocok.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchHistory(reset: true),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: _transactions.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _transactions.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: () =>
                                              _fetchHistory(reset: false),
                                          child:
                                              const Text('Muat Lebih Banyak'),
                                        ),
                                ),
                              );
                            }

                            final tx = _transactions[index];
                            final isOpname = (tx.notes ?? '')
                                .toLowerCase()
                                .contains('opname');
                            final delta =
                                tx.type == 'OUT' ? -tx.quantity : tx.quantity;
                            final isInbound = delta > 0;

                            final Color badgeBg = isOpname
                                ? const Color(0xFFEFF6FF)
                                : isInbound
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF3C7);
                            final Color badgeFg = isOpname
                                ? const Color(0xFF155EEF)
                                : isInbound
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFB45309);
                            final IconData iconData = isOpname
                                ? Icons.tune_rounded
                                : isInbound
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE8EEF5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: badgeFg,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.itemName,
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
                                          '${tx.itemSku} • ${_formatDateTime(tx.transactionDate)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        if (tx.channel != null ||
                                            (tx.refNo != null &&
                                                tx.refNo!.isNotEmpty)) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (tx.channel != null)
                                                _channelLabel(tx.channel!),
                                              if (tx.refNo != null &&
                                                  tx.refNo!.isNotEmpty)
                                                'Ref: ${tx.refNo}',
                                            ].join(' • '),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                        if (tx.notes != null &&
                                            tx.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            tx.notes!,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${isInbound ? '+' : '-'}${delta.abs()} ${tx.itemUnit.toLowerCase()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: badgeFg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _HistoryFilterPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
