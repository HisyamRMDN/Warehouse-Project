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
    'Set',
    'Box',
    'Unit',
    'Kg',
    'Roll',
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

  InputDecoration _cleanInput({
    required String hint,
    String? prefixText,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: 19, color: const Color(0xFF64748B))
          : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF155EEF), width: 1.5),
      ),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Nonaktifkan Barang?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: 600,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle & Pinned Header
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isEdit
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                    color: _isEdit
                        ? const Color(0xFF059669)
                        : const Color(0xFF155EEF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit
                            ? 'Edit Master Barang'
                            : 'Daftarkan Barang Baru',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _isEdit
                            ? 'Perbarui detail SKU, rak, dan harga'
                            : 'Lengkapi identitas produk peralatan masak',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
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

          // Form Body (Scrollable dengan label statis di atas input)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTag(
                    icon: Icons.label_outline_rounded,
                    title: 'IDENTITAS PRODUK',
                  ),
                  const SizedBox(height: 12),
                  const _FieldLabel('Kode SKU / Barcode *'),
                  TextField(
                    controller: _skuCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _cleanInput(
                      hint: 'Contoh: PNC-005-24CM',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Nama Barang & Ukuran *'),
                  TextField(
                    controller: _nameCtrl,
                    decoration: _cleanInput(
                      hint: 'Contoh: Panci Kukus Supra 24 cm',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Kategori'),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedCategoryId,
                    decoration: _cleanInput(
                      hint: 'Pilih kategori',
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
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTag(
                    icon: Icons.shelves,
                    title: 'STOK & LOKASI RAK',
                  ),
                  const SizedBox(height: 12),
                  const _FieldLabel('Satuan Dasar'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableUnits.map((unit) {
                      final active = _selectedUnit == unit;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedUnit = unit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF131B2E)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFF131B2E)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Lokasi Rak / Bin'),
                            TextField(
                              controller: _rackCtrl,
                              decoration: _cleanInput(
                                hint: 'Rak A-02',
                                icon: Icons.location_on_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Batas Min. Stok'),
                            TextField(
                              controller: _minStockCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _cleanInput(hint: '5'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 14),
                    const _FieldLabel('Stok Awal Masuk Gudang (pcs)'),
                    TextField(
                      controller: _initialStockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: _cleanInput(
                        hint: '0 (otomatis tercatat sebagai mutasi IN)',
                        icon: Icons.south_west_rounded,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SectionTag(
                    icon: Icons.payments_outlined,
                    title: 'KEMASAN & HARGA (OPSIONAL)',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Isi per Lusin'),
                            TextField(
                              controller: _packQtyCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setState(() {}),
                              decoration: _cleanInput(hint: '1 = satuan pcs'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Harga Beli / pcs'),
                            TextField(
                              controller: _buyPriceCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _cleanInput(
                                hint: '0',
                                prefixText: 'Rp ',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Harga Jual / pcs'),
                            TextField(
                              controller: _sellPriceCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _cleanInput(
                                hint: '0',
                                prefixText: 'Rp ',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (packQty > 1) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Harga Jual / lusin'),
                              TextField(
                                controller: _sellPackCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _cleanInput(
                                  hint: '0',
                                  prefixText: 'Rp ',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF155EEF),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Stok tercatat: ${widget.item!.currentStock} ${widget.item!.unit}'
                              '${widget.item!.packBreakdown != null ? ' (${widget.item!.packBreakdown})' : ''}. '
                              'Ubah jumlah stok lewat menu Mutasi / Opname.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Pinned Footer Actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                if (_isEdit) ...[
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _confirmDeactivate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('Nonaktifkan'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF155EEF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 19),
                      label: Text(
                        _isSaving
                            ? 'Menyimpan...'
                            : (_isEdit ? 'Simpan Perubahan' : 'Simpan Barang'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTag extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTag({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF155EEF)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}
