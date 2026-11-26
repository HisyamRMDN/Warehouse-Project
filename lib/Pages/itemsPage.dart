import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/csv_import_dialog.dart';
import 'package:warehouse_project/widgets/item_form_dialog.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

class ItemsPage extends StatefulWidget {
  final VoidCallback onDataChanged;
  final bool isAdmin;

  const ItemsPage({
    super.key,
    required this.onDataChanged,
    this.isAdmin = false,
  });

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  static const int _pageSize = 50;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<ItemModel> _items = [];
  List<CategoryModel> _categories = [];

  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _onlyLowStock = false;

  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _initLoad();
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
      _fetchItems(reset: false);
    }
  }

  Future<void> _initLoad() async {
    await Future.wait([
      _fetchCategories(),
      _fetchItems(reset: true),
    ]);
  }

  Future<void> _fetchCategories() async {
    try {
      final catRes = await supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      if (!mounted) return;
      setState(() {
        _categories = (catRes as List<dynamic>)
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
  }

  String _escapeLike(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_')
        .replaceAll(',', ' ');
  }

  Future<void> _fetchItems({required bool reset}) async {
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
      final from = reset ? 0 : _items.length;
      final to = from + _pageSize - 1;

      var query = supabase
          .from('items')
          .select('*, categories(name)')
          .eq('is_active', true);

      if (_selectedCategoryId != null) {
        query = query.eq('category_id', _selectedCategoryId!);
      }

      final q = _searchQuery.trim();
      if (q.isNotEmpty) {
        final safe = _escapeLike(q);
        query = query.or('name.ilike.%$safe%,sku.ilike.%$safe%');
      }

      final response = await query
          .order('name', ascending: true)
          .range(from, to)
          .count(CountOption.exact);

      final rawList = response.data as List<dynamic>;
      var fetched = rawList
          .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (_onlyLowStock) {
        fetched = fetched.where((item) => item.isLowStock).toList();
      }

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = fetched;
        } else {
          _items.addAll(fetched);
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
        SnackBar(content: Text('Gagal memuat barang: $e')),
      );
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = val);
      _fetchItems(reset: true);
    });
  }

  void _openItemForm([ItemModel? item]) {
    showDialog(
      context: context,
      builder: (_) => ItemFormDialog(
        item: item,
        categories: _categories,
        defaultCategoryId: _selectedCategoryId,
        onSaved: () async {
          await _fetchItems(reset: true);
          widget.onDataChanged();
        },
      ),
    );
  }

  Future<void> _openCsvImport() async {
    List<ItemModel> allActiveForCheck = _items;
    try {
      final res = await supabase
          .from('items')
          .select('id, sku, name, unit, current_stock, min_stock')
          .eq('is_active', true);
      allActiveForCheck = (res as List<dynamic>)
          .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => CsvImportDialog(
        existingItems: allActiveForCheck,
        existingCategories: _categories,
        onImportSuccess: () async {
          await _initLoad();
          widget.onDataChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header bersih: Judul + Tombol Impor & Tambah
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: WmsSectionHeader(
              title: 'Master Barang',
              subtitle: _onlyLowStock
                  ? '${_items.length} barang stok menipis'
                  : 'Menampilkan ${_items.length} dari $_totalCount SKU',
              trailing: widget.isAdmin
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openCsvImport,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            side: const BorderSide(color: Color(0xFF1565C0)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Impor CSV'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _openItemForm(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('SKU Baru'),
                        ),
                      ],
                    )
                  : null,
            ),
          ),

          // Search Bar Reusable
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WmsSearchBar(
              controller: _searchCtrl,
              hasText: _searchQuery.isNotEmpty,
              onChanged: _onSearchChanged,
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
                _fetchItems(reset: true);
              },
            ),
          ),

          // Filter Kategori Horizontal
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Semua'),
                    selected: _selectedCategoryId == null && !_onlyLowStock,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategoryId = null;
                        _onlyLowStock = false;
                      });
                      _fetchItems(reset: true);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: const Text('⚠️', style: TextStyle(fontSize: 12)),
                    label: const Text('Stok Menipis'),
                    selected: _onlyLowStock,
                    selectedColor: const Color(0xFFFFE0B2),
                    onSelected: (val) {
                      setState(() => _onlyLowStock = val);
                      _fetchItems(reset: true);
                    },
                  ),
                ),
                ..._categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Text(
                        WmsCategoryStyle.emoji(cat.name),
                        style: const TextStyle(fontSize: 12),
                      ),
                      label: Text(cat.name),
                      selected: _selectedCategoryId == cat.id,
                      onSelected: (val) {
                        setState(() {
                          _selectedCategoryId = val ? cat.id : null;
                        });
                        _fetchItems(reset: true);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Daftar Kartu Barang (3 Titik Fokus: Ikon | Nama & SKU | Badge Stok)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          (_searchQuery.isNotEmpty ||
                                  _selectedCategoryId != null ||
                                  _onlyLowStock)
                              ? 'Tidak ada barang yang cocok dengan filter.'
                              : 'Belum ada master barang.',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchItems(reset: true),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 88),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: () =>
                                              _fetchItems(reset: false),
                                          child: Text(
                                            'Muat Lebih Banyak (${_items.length}/$_totalCount)',
                                          ),
                                        ),
                                ),
                              );
                            }

                            final item = _items[index];
                            final hasRack = item.rackLocation != null &&
                                item.rackLocation!.isNotEmpty;
                            final hasSellPrice = item.sellPrice > 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFEDF2F7),
                                ),
                              ),
                              child: ListTile(
                                onTap: widget.isAdmin
                                    ? () => _openItemForm(item)
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                leading: CategoryAvatar(
                                  categoryName: item.categoryName,
                                  skuPrefix: item.sku.split('-').first,
                                ),
                                title: Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1A202C),
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    '${item.sku}'
                                    '${hasRack ? ' • Rak ${item.rackLocation}' : ''}'
                                    '${hasSellPrice ? ' • ${formatRupiah(item.sellPrice)}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                trailing: StockBadge(item: item),
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
