import 'package:flutter/material.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

class HomePage extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback? onOpenMutation;
  final ValueChanged<int>? onNavigateTab;

  const HomePage({
    super.key,
    this.isAdmin = false,
    this.onOpenMutation,
    this.onNavigateTab,
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
  Map<String, double> _revenueByChannel = {};
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
          .limit(15);

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

      final revenue = <String, double>{};
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
            final ch = (row['channel'] as String?) ?? 'lainnya';
            revenue[ch] = (revenue[ch] ?? 0) +
                ((row['revenue'] as num?)?.toDouble() ?? 0);
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
        _revenueByChannel = revenue;
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
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
        return 'Lainnya';
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

    final totalRevenue30d =
        _revenueByChannel.values.fold<double>(0, (a, b) => a + b);

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 1. Kartu Hero Gradasi Biru ala Boxora
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4C8DF6),
                  Color(0xFF1D61E7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D61E7).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ringkasan Gudang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Live Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _GlassMetricBox(
                        label: 'Total SKU',
                        value: '$_totalSku',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GlassMetricBox(
                        label: 'Stok Menipis',
                        value: '$_lowStockCount',
                        highlightWarning: _lowStockCount > 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _GlassMetricBox(
                  label: 'Total Fisik di Gudang',
                  value: '$_totalStockUnits pcs',
                  isLarge: true,
                ),
              ],
            ),
          ),

          // Kartu Finansial Khusus Admin (Nilai Modal & Omzet)
          if (widget.isAdmin) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: WmsStatCard(
                    title: 'Nilai Stok (Modal)',
                    value: formatRupiah(_stockCost),
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: const Color(0xFF6A1B9A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WmsStatCard(
                    title: 'Omzet 30 Hari',
                    value: formatRupiah(totalRevenue30d),
                    icon: Icons.trending_up_rounded,
                    accentColor: const Color(0xFF00897B),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // 2. Menu Aksi Cepat (Grid 2x2 bergaya Boxora)
          const WmsSectionHeader(
            title: 'Aksi Cepat',
            subtitle: 'Catat pergerakan stok atau kelola katalog',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  title: 'Barang Masuk',
                  subtitle: 'Restock supplier',
                  icon: Icons.south_west_rounded,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF2E7D32),
                  onTap: widget.onOpenMutation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  title: 'Barang Keluar',
                  subtitle: 'Pesanan marketplace',
                  icon: Icons.north_east_rounded,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                  onTap: widget.onOpenMutation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  title: 'Daftar SKU',
                  subtitle: '$_totalSku produk terdaftar',
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFE3F2FD),
                  iconColor: const Color(0xFF1565C0),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  title: 'Kategori',
                  subtitle: 'Kelompok peralatan',
                  icon: Icons.grid_view_rounded,
                  iconBg: const Color(0xFFFFF3E0),
                  iconColor: const Color(0xFFEF6C00),
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 3. Riwayat Mutasi Terbaru bergaya Gostock Recent Documents
          WmsSectionHeader(
            title: 'Mutasi Terbaru',
            subtitle: '15 transaksi terakhir di buku besar',
          ),
          const SizedBox(height: 10),

          if (_recentTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9EDF7)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 38, color: Color(0xFF8F9BBA)),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada transaksi mutasi stok.',
                    style: TextStyle(color: Color(0xFF8F9BBA)),
                  ),
                ],
              ),
            )
          else
            ..._recentTransactions.map((tx) {
              final delta = tx.type == 'OUT' ? -tx.quantity : tx.quantity;
              final isInbound = delta > 0;
              final isAdjust = tx.type == 'ADJUSTMENT';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE9EDF7)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isInbound
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isAdjust
                          ? Icons.tune_rounded
                          : (isInbound
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded),
                      color: isInbound
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                  title: Text(
                    tx.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1B2559),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${tx.itemSku} • ${_formatDateTime(tx.transactionDate)}'
                      '${tx.channel != null ? ' • ${_channelLabel(tx.channel!)}' : ''}'
                      '${(tx.notes != null && tx.notes!.isNotEmpty) ? ' • ${tx.notes}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8F9BBA),
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isInbound
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isInbound ? '+' : '-'}${delta.abs()} ${tx.itemUnit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isInbound
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GlassMetricBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isLarge;
  final bool highlightWarning;

  const _GlassMetricBox({
    required this.label,
    required this.value,
    this.isLarge = false,
    this.highlightWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isLarge ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightWarning
              ? const Color(0xFFFFCC80)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EDF7)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF1B2559),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8F9BBA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
