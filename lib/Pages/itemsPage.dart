import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/csv_import_dialog.dart';
import 'package:warehouse_project/widgets/item_form_dialog.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';
import 'package:warehouse_project/widgets/item_detail_sheet.dart';

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

  void _openItemDetail(ItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Center(
        child: ItemDetailSheet(
          item: item,
          isAdmin: widget.isAdmin,
          onEditPressed: () => _openItemForm(item),
        ),
      ),
    );
  }

  void _openItemForm([ItemModel? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Center(
        child: ItemFormDialog(
          item: item,
          categories: _categories,
          defaultCategoryId: _selectedCategoryId,
          onSaved: () async {
            await _fetchItems(reset: true);
            widget.onDataChanged();
          },
        ),
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
    final bool isAllSelected = _selectedCategoryId == null && !_onlyLowStock;

    return Column(
      children: [
        // Baris Search + Tombol Impor & (+) biru sesuai Layar 3 Mockup
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Expanded(
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
              if (widget.isAdmin) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _openCsvImport,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Tooltip(
                        message: 'Impor CSV',
                        child: Icon(
                          Icons.upload_file_outlined,
                          color: Color(0xFF155EEF),
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFF155EEF),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _openItemForm(),
                    borderRadius: BorderRadius.circular(14),
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Tooltip(
                        message: 'Tambah SKU Baru',
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Deretan Pill Filter dengan Ikon Google Material
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterPill(
                label: 'Semua',
                selected: isAllSelected,
                selectedBg: const Color(0xFF131B2E),
                selectedFg: Colors.white,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _onlyLowStock = false;
                  });
                  _fetchItems(reset: true);
                },
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Perlu Restock',
                icon: Icons.warning_amber_rounded,
                selected: _onlyLowStock,
                defaultBg: const Color(0xFFFEF3C7),
                defaultFg: const Color(0xFFB45309),
                selectedBg: const Color(0xFFD97706),
                selectedFg: Colors.white,
                onTap: () {
                  setState(() => _onlyLowStock = !_onlyLowStock);
                  _fetchItems(reset: true);
                },
              ),
              const SizedBox(width: 8),
              ..._categories.map(
                (cat) {
                  final active = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      label: cat.name,
                      icon: WmsCategoryStyle.icon(cat.name),
                      selected: active,
                      selectedBg: const Color(0xFF131B2E),
                      selectedFg: Colors.white,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = active ? null : cat.id;
                        });
                        _fetchItems(reset: true);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _onlyLowStock
                    ? '${_items.length} barang perlu restock'
                    : 'Menampilkan ${_items.length} dari $_totalCount SKU aktif',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
              if (!isAllSelected || _searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategoryId = null;
                      _onlyLowStock = false;
                    });
                    _fetchItems(reset: true);
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF155EEF),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Daftar Kartu Barang (2 Baris Bersih + Pill Stok di Kanan sesuai Layar 3 Mockup)
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        (!isAllSelected || _searchQuery.isNotEmpty)
                            ? 'Tidak ada barang yang cocok.'
                            : 'Belum ada master barang.',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _fetchItems(reset: true),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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

                          return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                      color: Color(0xFFE8EEF5)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  onTap: () => _openItemDetail(item),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  leading: CategoryAvatar(
                                    categoryName: item.categoryName,
                                    skuPrefix: item.sku.split('-').first,
                                    imageUrl: item.imageUrl,
                                  ),
                                  title: Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '${item.sku}${hasRack ? '  •  RAK-${item.rackLocation}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  trailing: StockBadge(item: item),
                                ),
                              ));
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color defaultBg;
  final Color defaultFg;
  final Color selectedBg;
  final Color selectedFg;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.selected,
    this.defaultBg = Colors.white,
    this.defaultFg = const Color(0xFF334155),
    required this.selectedBg,
    required this.selectedFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedBg : defaultBg;
    final fg = selected ? selectedFg : defaultFg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: selected || defaultBg != Colors.white
              ? null
              : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
