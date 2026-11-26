import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  static const _inReasons = {
    'pembelian': 'Pembelian / restock',
    'retur': 'Retur dari pembeli',
    'lainnya': 'Lainnya',
  };
  static const _outReasons = {
    'penjualan': 'Penjualan',
    'rusak': 'Rusak',
    'pecah': 'Pecah',
    'hilang': 'Hilang',
    'lainnya': 'Lainnya',
  };
  static const _adjustReasons = {
    'opname': 'Hasil Stock Opname Fisik',
    'rusak': 'Barang Rusak / Penyok',
    'pecah': 'Barang Pecah',
    'hilang': 'Selisih / Hilang',
    'lainnya': 'Koreksi Lainnya',
  };
  static const _channels = {
    'shopee': 'Shopee',
    'tokopedia': 'Tokopedia',
    'offline': 'Offline / langsung',
    'lainnya': 'Lainnya',
  };

  List<ItemModel> _items = [];
  ItemModel? _selectedItem;
  bool _isAdmin = false;

  String _transactionType = 'IN'; // 'IN' | 'OUT' | 'ADJUSTMENT'
  String _inputUnit = 'pcs'; // 'pcs' | 'pack'
  String _reason = 'pembelian';
  String? _channel;

  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoadingItems = true;
  bool _isSubmitting = false;

  bool get _isAdjust => _transactionType == 'ADJUSTMENT';
  bool get _isPack =>
      !_isAdjust && _inputUnit == 'pack' && (_selectedItem?.hasPack ?? false);
  int get _packQty => _isPack ? _selectedItem!.packQty : 1;

  Map<String, String> get _reasons {
    if (_transactionType == 'IN') return _inReasons;
    if (_transactionType == 'OUT') return _outReasons;
    return _adjustReasons;
  }

  bool get _isSale => _transactionType == 'OUT' && _reason == 'penjualan';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      final futures = <Future<dynamic>>[
        supabase
            .from('items')
            .select('*, categories(name)')
            .eq('is_active', true)
            .order('name', ascending: true),
      ];
      if (uid != null) {
        futures.add(
          supabase.from('profiles').select('role').eq('id', uid).maybeSingle(),
        );
      }

      final results = await Future.wait(futures);
      final loaded = (results[0] as List<dynamic>)
          .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      bool adminFlag = false;
      if (results.length > 1 && results[1] != null) {
        adminFlag = (results[1] as Map<String, dynamic>)['role'] == 'admin';
      }

      if (!mounted) return;
      setState(() {
        _items = loaded;
        _isAdmin = adminFlag;
        if (loaded.isNotEmpty) _selectedItem = loaded.first;
        _isLoadingItems = false;
        _applyDefaultPrice();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingItems = false);
    }
  }

  void _applyDefaultPrice() {
    final item = _selectedItem;
    if (item == null || _isAdjust) {
      _priceController.clear();
      return;
    }
    final num price;
    if (_transactionType == 'OUT') {
      price = _isPack
          ? (item.sellPricePack ?? item.sellPrice * item.packQty)
          : item.sellPrice;
    } else {
      price = item.buyPrice * _packQty;
    }
    _priceController.text = price > 0 ? price.round().toString() : '';
  }

  void _onTypeChanged(String type) {
    setState(() {
      _transactionType = type;
      if (type == 'IN') {
        _reason = 'pembelian';
      } else if (type == 'OUT') {
        _reason = 'penjualan';
      } else {
        _reason = 'opname';
        _inputUnit = 'pcs';
      }
      _channel = _isSale ? 'shopee' : null;
      _qtyController.clear();
      _applyDefaultPrice();
    });
  }

  void _onReasonChanged(String reason) {
    setState(() {
      _reason = reason;
      _channel = _isSale ? (_channel ?? 'shopee') : null;
    });
  }

  void _onItemChanged(ItemModel item) {
    setState(() {
      _selectedItem = item;
      if (!item.hasPack) _inputUnit = 'pcs';
      _applyDefaultPrice();
    });
  }

  void _onUnitChanged(String unit) {
    setState(() {
      _inputUnit = unit;
      _applyDefaultPrice();
    });
  }

  Future<void> _openItemPicker() async {
    final searchCtrl = TextEditingController();
    String query = '';

    final picked = await showModalBottomSheet<ItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? _items
              : _items
                  .where((it) =>
                      it.name.toLowerCase().contains(q) ||
                      it.sku.toLowerCase().contains(q))
                  .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Barang (SKU)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2559),
                        ),
                      ),
                      const SizedBox(height: 10),
                      WmsSearchBar(
                        controller: searchCtrl,
                        hasText: query.isNotEmpty,
                        hintText: 'Ketik nama panci, wadah, atau SKU...',
                        onChanged: (val) => setSheetState(() => query = val),
                        onClear: () {
                          searchCtrl.clear();
                          setSheetState(() => query = '');
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Barang tidak ditemukan',
                            style: TextStyle(color: Color(0xFF8F9BBA)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final it = filtered[idx];
                            final selected = it.id == _selectedItem?.id;
                            return Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFEBF3FE)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF1D61E7)
                                      : const Color(0xFFE9EDF7),
                                ),
                              ),
                              child: ListTile(
                                onTap: () => Navigator.pop(ctx, it),
                                leading: CategoryAvatar(
                                  categoryName: it.categoryName,
                                  skuPrefix: it.sku.split('-').first,
                                ),
                                title: Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF1B2559),
                                  ),
                                ),
                                subtitle: Text(
                                  it.sku,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8F9BBA),
                                  ),
                                ),
                                trailing: StockBadge(item: it),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (picked != null) {
      _onItemChanged(picked);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _submitTransaction() async {
    final item = _selectedItem;
    if (item == null) return;

    final rawText = _qtyController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAdjust
                ? 'Masukkan jumlah stok fisik hasil hitung'
                : 'Jumlah barang wajib diisi',
          ),
        ),
      );
      return;
    }

    final inputVal = int.tryParse(rawText);
    if (inputVal == null) return;

    if (_isAdjust) {
      if (inputVal < 0) {
        _showError('Stok fisik tidak boleh negatif');
        return;
      }
      final diff = inputVal - item.currentStock;
      if (diff == 0) {
        _showError(
          'Stok fisik sama dengan stok tercatat (${item.currentStock} ${item.unit}), tidak ada selisih',
        );
        return;
      }

      setState(() => _isSubmitting = true);
      try {
        await supabase.from('stock_transactions').insert({
          'item_id': item.id,
          'type': 'ADJUSTMENT',
          'input_unit': 'pcs',
          'input_qty': diff,
          'quantity': diff,
          'reason': _reason,
          'ref_no': _refController.text.trim().isEmpty
              ? null
              : _refController.text.trim(),
          'notes': _notesController.text.trim().isEmpty
              ? 'Opname fisik: ${item.currentStock} -> $inputVal ${item.unit}'
              : _notesController.text.trim(),
        });

        if (!mounted) return;
        Navigator.pop(context, true);
      } on PostgrestException catch (e) {
        if (!mounted) return;
        _showError('Ditolak server: ${e.message}');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan opname: $e')),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    // Mode IN / OUT standar
    if (inputVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah barang harus lebih dari 0')),
      );
      return;
    }

    final qtyPcs = inputVal * _packQty;

    if (_transactionType == 'OUT' && qtyPcs > item.currentStock) {
      _showError(
        'Stok tidak mencukupi! Sisa stok ${item.name}: ${item.currentStock} ${item.unit}',
      );
      return;
    }

    final enteredPrice = int.tryParse(_priceController.text.trim());
    final unitPricePerPcs =
        enteredPrice == null ? null : enteredPrice / _packQty;

    setState(() => _isSubmitting = true);

    try {
      await supabase.from('stock_transactions').insert({
        'item_id': item.id,
        'type': _transactionType,
        'input_unit': _isPack ? 'pack' : 'pcs',
        'input_qty': inputVal,
        'quantity': qtyPcs,
        'unit_price': unitPricePerPcs,
        'reason': _reason,
        'channel': _isSale ? _channel : null,
        'ref_no': _refController.text.trim().isEmpty
            ? null
            : _refController.text.trim(),
        'notes': _notesController.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showError('Ditolak server: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan mutasi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedItem;
    final parsedInput = int.tryParse(_qtyController.text.trim());
    final qty = parsedInput ?? 0;
    final price = int.tryParse(_priceController.text.trim());
    final unitLabel =
        _isPack ? (item?.packLabel ?? 'lusin') : (item?.unit ?? 'pcs');

    final int? opnameDiff = (_isAdjust && item != null && parsedInput != null)
        ? parsedInput - item.currentStock
        : null;

    Color submitColor = const Color(0xFF2E7D32);
    String submitLabel = 'Simpan Barang Masuk';
    if (_transactionType == 'OUT') {
      submitColor = const Color(0xFFC62828);
      submitLabel = 'Simpan Barang Keluar';
    } else if (_isAdjust) {
      submitColor = const Color(0xFF1D61E7);
      submitLabel = 'Simpan Hasil Stock Opname';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text('Catat Mutasi Stok'),
      ),
      body: _isLoadingItems
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada Master Barang terdaftar.\nSilakan tambahkan barang terlebih dahulu di tab "Barang".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        // 1. Pemilih Jenis Mutasi (Pill Selector)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE9EDF7)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TypeTabButton(
                                  label: 'Masuk (IN)',
                                  icon: Icons.south_west_rounded,
                                  activeColor: const Color(0xFF2E7D32),
                                  selected: _transactionType == 'IN',
                                  onTap: () => _onTypeChanged('IN'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _TypeTabButton(
                                  label: 'Keluar (OUT)',
                                  icon: Icons.north_east_rounded,
                                  activeColor: const Color(0xFFC62828),
                                  selected: _transactionType == 'OUT',
                                  onTap: () => _onTypeChanged('OUT'),
                                ),
                              ),
                              if (_isAdmin) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _TypeTabButton(
                                    label: 'Opname',
                                    icon: Icons.tune_rounded,
                                    activeColor: const Color(0xFF1D61E7),
                                    selected: _transactionType == 'ADJUSTMENT',
                                    onTap: () => _onTypeChanged('ADJUSTMENT'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 2. Kartu Pilih Barang (Tap untuk membuka pencarian cepat)
                        if (item != null)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: const Color(0xFFE9EDF7)),
                            ),
                            child: ListTile(
                              onTap: _openItemPicker,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1B2559),
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '${item.sku} • Ketuk untuk ganti barang',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1D61E7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StockBadge(item: item),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.unfold_more_rounded,
                                    color: Color(0xFF8F9BBA),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        // 3. Kartu Form Input Utama
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE9EDF7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey('reason_$_transactionType'),
                                initialValue: _reason,
                                decoration:
                                    const InputDecoration(labelText: 'Alasan'),
                                items: _reasons.entries
                                    .map((e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(e.value),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) _onReasonChanged(val);
                                },
                              ),
                              if (_isSale) ...[
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  key: const ValueKey('channel'),
                                  initialValue: _channel,
                                  decoration: const InputDecoration(
                                    labelText: 'Channel Penjualan',
                                  ),
                                  items: _channels.entries
                                      .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value),
                                          ))
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _channel = val),
                                ),
                              ],
                              if (!_isAdjust &&
                                  item != null &&
                                  item.hasPack) ...[
                                const SizedBox(height: 14),
                                const Text(
                                  'Satuan Input',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B2559),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SegmentedButton<String>(
                                  segments: [
                                    ButtonSegment(
                                      value: 'pcs',
                                      label: Text(item.unit),
                                    ),
                                    ButtonSegment(
                                      value: 'pack',
                                      label: Text(
                                        '${item.packLabel} (isi ${item.packQty})',
                                      ),
                                    ),
                                  ],
                                  selected: {_inputUnit},
                                  onSelectionChanged: (set) =>
                                      _onUnitChanged(set.first),
                                ),
                              ],
                              const SizedBox(height: 14),
                              TextField(
                                controller: _qtyController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: _isAdjust
                                      ? 'Stok Fisik Hasil Hitung (${item?.unit ?? 'pcs'}) *'
                                      : 'Jumlah ($unitLabel) *',
                                  helperText: (!_isAdjust && _isPack && qty > 0)
                                      ? '= ${qty * _packQty} ${item?.unit ?? 'pcs'}'
                                      : null,
                                ),
                              ),

                              // Kartu Pratinjau Selisih Otomatis saat mode Opname
                              if (_isAdjust && item != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F7FE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Stok Tercatat: ${item.currentStock} ${item.unit}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF1B2559),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (opnameDiff != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: opnameDiff == 0
                                                ? Colors.grey.shade200
                                                : opnameDiff > 0
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFFFEBEE),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            opnameDiff == 0
                                                ? 'Selisih: 0'
                                                : 'Selisih: ${opnameDiff > 0 ? '+' : ''}$opnameDiff ${item.unit}',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: opnameDiff == 0
                                                  ? Colors.black54
                                                  : opnameDiff > 0
                                                      ? const Color(0xFF2E7D32)
                                                      : const Color(0xFFC62828),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],

                              if (!_isAdjust) ...[
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Harga per $unitLabel (Rp)',
                                    helperText: (price != null && qty > 0)
                                        ? 'Total: ${formatRupiah(price * qty)}'
                                        : null,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              TextField(
                                controller: _refController,
                                decoration: InputDecoration(
                                  labelText: _isAdjust
                                      ? 'No. Berita Acara / Ref (Opsional)'
                                      : 'No. Pesanan / Surat Jalan',
                                  hintText: _isAdjust
                                      ? 'Contoh: OPN-NOV-2026'
                                      : 'Contoh: 2611ABCD123',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _notesController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Keterangan',
                                  hintText: _isAdjust
                                      ? 'Contoh: Hitung ulang rak A-01'
                                      : 'Contoh: Restock Supplier',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                _isSubmitting ? null : _submitTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: submitColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    submitLabel,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _TypeTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTabButton({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : const Color(0xFF8F9BBA),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF8F9BBA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

