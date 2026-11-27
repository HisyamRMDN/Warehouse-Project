import 'package:flutter/material.dart';
import 'package:warehouse_project/Pages/historyPage.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';
import 'package:warehouse_project/Pages/restockPage.dart';

class HomePage extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback? onOpenMutation;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenCategories;

  const HomePage({
    super.key,
    this.isAdmin = false,
    this.onOpenMutation,
    this.onNavigateTab,
    this.onOpenCategories,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _errorMessage;

  int _totalSku = 0;
  int _totalStockUnits = 0;
  int _lowStockCount = 0;
  double _stockCost = 0;
  double _totalRevenue30d = 0;
  List<StockTransactionModel> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final itemsRes = await supabase
          .from('items')
          .select('id, current_stock, min_stock, buy_price')
          .eq('is_active', true);

      final txRes = await supabase
          .from('stock_transactions')
          .select('*, items(name, sku, unit, pack_label)')
          .order('transaction_date', ascending: false)
          .limit(10);

      final itemsList = itemsRes as List<dynamic>;
      int totalUnits = 0;
      int lowCount = 0;
      double totalCost = 0;

      for (final row in itemsList) {
        final current = (row['current_stock'] as num?)?.toInt() ?? 0;
        final min = (row['min_stock'] as num?)?.toInt() ?? 5;
        totalUnits += current;
        totalCost += ((row['buy_price'] as num?)?.toDouble() ?? 0) * current;
        if (current <= min) lowCount++;
      }

      double rev30 = 0;
      if (widget.isAdmin) {
        try {
          final since = DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String()
              .substring(0, 10);
          final salesRes = await supabase
              .from('sales_by_channel')
              .select()
              .gte('day', since);
          for (final row in salesRes as List<dynamic>) {
            rev30 += ((row['revenue'] as num?)?.toDouble() ?? 0);
          }
        } catch (_) {}
      }

      final transactions = (txRes as List<dynamic>)
          .map((e) => StockTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _totalSku = itemsList.length;
        _totalStockUnits = totalUnits;
        _lowStockCount = lowCount;
        _stockCost = totalCost;
        _totalRevenue30d = rev30;
        _recentTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data dashboard: $e';
        _isLoading = false;
      });
    }
  }

  String _formatRibuan(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute WIB';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'IN':
        return 'Masuk';
      case 'OUT':
        return 'Keluar';
      default:
        return 'Opname';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadDashboardData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          // 1. Kartu Ringkasan Utama Putih Bersih (Persis Layar 2 Mockup)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EEF5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Stok Fisik',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatRibuan(_totalStockUnits),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'unit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onNavigateTab?.call(1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SKU Aktif',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$_totalSku',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RestockPage(),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perlu Restock',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  '$_lowStockCount',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: Color(0xFFB45309),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ringkasan Modal & Omzet (khusus Admin, tetap ringkas)
          if (widget.isAdmin && (_stockCost > 0 || _totalRevenue30d > 0)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: WmsStatCard(
                    title: 'Nilai Modal Stok',
                    value: formatRupiah(_stockCost),
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: const Color(0xFF155EEF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WmsStatCard(
                    title: 'Omzet 30 Hari',
                    value: formatRupiah(_totalRevenue30d),
                    icon: Icons.trending_up_rounded,
                    accentColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // 2. Bagian Catat Cepat (Persis Layar 2 Mockup)
          WmsSectionHeader(
            title: 'Catat Cepat',
            trailing: TextButton.icon(
              onPressed: widget.onOpenCategories,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF155EEF),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.category_outlined, size: 17),
              label: const Text(
                'Kategori',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: 'Barang Masuk',
                  subtitle: 'Terima stok',
                  icon: Icons.south_west_rounded,
                  iconColor: const Color(0xFF059669),
                  onTap: widget.onOpenMutation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  title: 'Barang Keluar',
                  subtitle: 'Kirim toko',
                  icon: Icons.north_east_rounded,
                  iconColor: const Color(0xFFD97706),
                  onTap: widget.onOpenMutation,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Aktivitas Terbaru (Persis Layar 2 Mockup)
          WmsSectionHeader(
            title: 'Aktivitas Terbaru',
            trailing: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              },
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF155EEF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          if (_recentTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada aktivitas mutasi stok.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: Column(
                children: List.generate(_recentTransactions.length, (index) {
                  final tx = _recentTransactions[index];
                  final delta = tx.type == 'OUT' ? -tx.quantity : tx.quantity;
                  final isInbound = delta > 0;
                  final Color deltaColor = isInbound
                      ? const Color(0xFF059669)
                      : tx.type == 'ADJUSTMENT'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFD97706);

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          tx.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${_typeLabel(tx.type)} • ${_formatTime(tx.transactionDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        trailing: Text(
                          '${isInbound ? '+' : '-'}${delta.abs()} ${tx.itemUnit.toLowerCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: deltaColor,
                          ),
                        ),
                      ),
                      if (index < _recentTransactions.length - 1)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Color(0xFFF1F5F9),
                        ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EEF5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
