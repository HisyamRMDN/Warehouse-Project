import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

class CategoryPage extends StatefulWidget {
  final VoidCallback onDataChanged;
  final bool isAdmin;

  const CategoryPage({
    super.key,
    required this.onDataChanged,
    this.isAdmin = false,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<CategoryModel> _categories = [];
  Map<String, int> _itemCountByCat = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        supabase.from('categories').select().order('name', ascending: true),
        supabase.from('items').select('category_id').eq('is_active', true),
      ]);

      final catList = (results[0] as List<dynamic>)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final counts = <String, int>{};
      for (final row in results[1] as List<dynamic>) {
        final cid = row['category_id'] as String?;
        if (cid != null) {
          counts[cid] = (counts[cid] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _categories = catList;
        _itemCountByCat = counts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tambah Kategori Baru',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            hintText: 'Contoh: Panci & Wajan, Wadah',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await supabase.from('categories').insert({'name': name});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadCategories();
                widget.onDataChanged();
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(_friendlyError(e, 'Gagal menambah kategori')),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D61E7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await supabase.from('categories').delete().eq('id', id);
      await _loadCategories();
      widget.onDataChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e, 'Gagal menghapus'))),
      );
    }
  }

  String _friendlyError(Object e, String fallback) {
    if (e is PostgrestException) {
      if (e.code == '23505') return 'Nama kategori sudah ada';
      if (e.code == '23503') return 'Kategori masih dipakai oleh barang';
      if (e.code == '42501') return 'Anda tidak punya izin untuk aksi ini';
    }
    return '$fallback: $e';
  }

  Future<void> _confirmDelete(CategoryModel cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "${cat.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteCategory(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: WmsSectionHeader(
            title: 'Kategori Barang',
            subtitle: '${_categories.length} kelompok produk terdaftar',
            trailing: widget.isAdmin
                ? ElevatedButton.icon(
                    onPressed: _showAddCategoryDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D61E7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Kategori'),
                  )
                : null,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _categories.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada kategori barang.',
                        style: TextStyle(color: Color(0xFF8F9BBA)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 88),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final accent = WmsCategoryStyle.color(cat.name);
                          final emoji = WmsCategoryStyle.emoji(cat.name);
                          final count = _itemCountByCat[cat.id] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE9EDF7),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    if (widget.isAdmin)
                                      IconButton(
                                        tooltip: 'Hapus Kategori',
                                        onPressed: () => _confirmDelete(cat),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 19,
                                          color: Color(0xFF8F9BBA),
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF1B2559),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$count SKU aktif',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8F9BBA),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
