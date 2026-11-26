import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';

class ItemFormDialog extends StatefulWidget {
  final ItemModel? item; // null = Tambah Baru, non-null = Edit
  final List<CategoryModel> categories;
  final String? defaultCategoryId;
  final Future<void> Function() onSaved;

  const ItemFormDialog({
    super.key,
    this.item,
    required this.categories,
    this.defaultCategoryId,
    required this.onSaved,
  });

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  static const List<String> _availableUnits = [
    'Pcs',
    'Box',
    'Unit',
    'Kg',
    'Roll',
    'Set',
  ];

  late final TextEditingController _skuCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _rackCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _initialStockCtrl;
  late final TextEditingController _packQtyCtrl;
  late final TextEditingController _buyPriceCtrl;
  late final TextEditingController _sellPriceCtrl;
  late final TextEditingController _sellPackCtrl;

  late String _selectedUnit;
  String? _selectedCategoryId;
  bool _isSaving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _skuCtrl = TextEditingController(text: item?.sku ?? '');
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _rackCtrl = TextEditingController(text: item?.rackLocation ?? '');
    _minStockCtrl =
        TextEditingController(text: (item?.minStock ?? 5).toString());
    _initialStockCtrl = TextEditingController(text: '0');
    _packQtyCtrl = TextEditingController(text: (item?.packQty ?? 1).toString());
    _buyPriceCtrl = TextEditingController(
      text: (item != null && item.buyPrice > 0)
          ? item.buyPrice.toInt().toString()
          : '',
    );
    _sellPriceCtrl = TextEditingController(
      text: (item != null && item.sellPrice > 0)
          ? item.sellPrice.toInt().toString()
          : '',
    );
    _sellPackCtrl = TextEditingController(
      text: item?.sellPricePack != null
          ? item!.sellPricePack!.toInt().toString()
          : '',
    );

    _selectedUnit = (item != null && _availableUnits.contains(item.unit))
        ? item.unit
        : 'Pcs';

    final candidateCat = item?.categoryId ?? widget.defaultCategoryId;
    _selectedCategoryId = widget.categories.any((c) => c.id == candidateCat)
        ? candidateCat
        : null;
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _nameCtrl.dispose();
    _rackCtrl.dispose();
    _minStockCtrl.dispose();
    _initialStockCtrl.dispose();
    _packQtyCtrl.dispose();
    _buyPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    _sellPackCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? helper,
    String? prefixText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixText: prefixText,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  String _friendlyError(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') return 'Kode SKU sudah dipakai barang lain';
      if (e.code == '42501') return 'Anda tidak punya izin untuk aksi ini';
    }
    return 'Gagal menyimpan: $e';
  }

  Future<void> _submit() async {
    final sku = _skuCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (sku.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode SKU dan Nama Barang wajib diisi')),
      );
      return;
    }

    final packQty = int.tryParse(_packQtyCtrl.text.trim()) ?? 1;
    if (packQty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi per lusin minimal 1')),
      );
      return;
    }

    final buyPrice = int.tryParse(_buyPriceCtrl.text.trim()) ?? 0;
    final sellPrice = int.tryParse(_sellPriceCtrl.text.trim()) ?? 0;
    final sellPack =
        packQty > 1 ? int.tryParse(_sellPackCtrl.text.trim()) : null;

    final payload = {
      'sku': sku,
      'name': name,
      'category_id': _selectedCategoryId,
      'unit': _selectedUnit,
      'min_stock': int.tryParse(_minStockCtrl.text.trim()) ?? 5,
      'rack_location': _rackCtrl.text.trim(),
      'pack_qty': packQty,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'sell_price_pack': sellPack,
    };

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await supabase.from('items').update(payload).eq('id', widget.item!.id);
      } else {
        final created =
            await supabase.from('items').insert(payload).select('id').single();

        final initialStock = int.tryParse(_initialStockCtrl.text.trim()) ?? 0;
        if (initialStock > 0) {
          await supabase.from('stock_transactions').insert({
            'item_id': created['id'],
            'type': 'IN',
            'quantity': initialStock,
            'notes': 'Stok awal',
          });
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Perubahan barang disimpan' : 'SKU baru berhasil dibuat',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  Future<void> _confirmDeactivate() async {
    final item = widget.item!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nonaktifkan Barang?'),
        content: Text(
          'Barang "${item.name}" (${item.sku}) akan disembunyikan dari daftar aktif.\n\n'
          'Riwayat mutasi stok sebelumnya tetap tersimpan aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(confirmCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await supabase
          .from('items')
          .update({'is_active': false}).eq('id', item.id);

      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SKU ${item.sku} dinonaktifkan')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final packQty = int.tryParse(_packQtyCtrl.text.trim()) ?? 1;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  _isEdit ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded,
              color:
                  _isEdit ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'Edit Master Barang' : 'Daftarkan Barang Baru',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'INFORMASI UTAMA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _skuCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldDecoration(
                  label: 'Kode SKU / Barcode *',
                  hint: 'Contoh: PNC-005-24CM',
                  icon: Icons.qr_code_scanner_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: _fieldDecoration(
                  label: 'Nama Barang & Ukuran *',
                  hint: 'Contoh: Panci Kukus Supra 24 cm',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedCategoryId,
                decoration: _fieldDecoration(
                  label: 'Kategori',
                  icon: Icons.category_outlined,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tanpa Kategori'),
                  ),
                  ...widget.categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 18),
              const Text(
                'STOK & LOKASI RAK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: _fieldDecoration(label: 'Satuan'),
                      items: _availableUnits
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minStockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldDecoration(label: 'Min. Stok'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rackCtrl,
                      decoration: _fieldDecoration(
                        label: 'Lokasi Rak / Bin',
                        hint: 'Rak A-02',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _initialStockCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _fieldDecoration(
                          label: 'Stok Awal (pcs)',
                          helper: 'Masuk mutasi IN',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'KEMASAN & HARGA (OPSIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _packQtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration(
                        label: 'Isi per Lusin',
                        helper: '1 = satuan pcs',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _buyPriceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldDecoration(
                        label: 'Harga Beli/pcs',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sellPriceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldDecoration(
                        label: 'Harga Jual/pcs',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                  if (packQty > 1) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sellPackCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _fieldDecoration(
                          label: 'Jual/lusin',
                          prefixText: 'Rp ',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_isEdit) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Stok saat ini: ${widget.item!.currentStock} ${widget.item!.unit}'
                    '${widget.item!.packBreakdown != null ? ' (≈ ${widget.item!.packBreakdown})' : ''}. '
                    'Perubahan stok hanya via Mutasi / Opname.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment:
          _isEdit ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      actions: [
        if (_isEdit)
          TextButton.icon(
            onPressed: _isSaving ? null : _confirmDeactivate,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Nonaktifkan'),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ],
    );
  }
}
