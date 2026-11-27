import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';
import 'package:warehouse_project/widgets/wms_ui_components.dart';
import 'package:warehouse_project/widgets/barcode_scanner_sheet.dart';

class FormPage extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onSaved;

  const FormPage({
    super.key,
    this.embedded = false,
    this.onSaved,
  });

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
    'lainnya': 'Hasil Stock Opname Fisik',
    'rusak': 'Barang Rusak / Penyok',
    'pecah': 'Barang Pecah',
    'hilang': 'Selisih / Hilang',
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
        _qtyController.clear();
      } else if (type == 'OUT') {
        _reason = 'penjualan';
        _qtyController.clear();
      } else {
        _reason = 'lainnya';
        _inputUnit = 'pcs';
        _qtyController.text = (_selectedItem?.currentStock ?? 0).toString();
      }
      _channel = _isSale ? 'shopee' : null;
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
      if (_isAdjust) {
        _qtyController.text = item.currentStock.toString();
      }
      _applyDefaultPrice();
    });
  }

  void _onUnitChanged(String unit) {
    setState(() {
      _inputUnit = unit;
      _applyDefaultPrice();
    });
  }

  void _stepQty(int delta) {
    final current = int.tryParse(_qtyController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 999999);
    setState(() {
      _qtyController.text = next.toString();
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
                        'Pilih Barang yang Dicek',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      WmsSearchBar(
                        controller: searchCtrl,
                        hasText: query.isNotEmpty,
                        hintText: 'Ketik nama barang atau kode SKU...',
                        onChanged: (val) => setSheetState(() => query = val),
                        onClear: () => setSheetState(() {
                          searchCtrl.clear();
                          query = '';
                        }),
                        onScanTap: () async {
                          final scannedSku = await BarcodeScannerSheet.scan(
                            context,
                            title: 'Pindai Barang Mutasi',
                            subtitle:
                                'Scan barcode rak untuk memilih SKU otomatis',
                          );
                          if (scannedSku != null && context.mounted) {
                            setSheetState(() {
                              searchCtrl.text = scannedSku;
                              query = scannedSku;
                            });
                          }
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
                            style: TextStyle(color: Color(0xFF64748B)),
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
                            return Material(
                              color: selected
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFF8FAFC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: selected
                                      ? const Color(0xFF155EEF)
                                      : const Color(0xFFE8EEF5),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => Navigator.pop(ctx, it),
                                leading: CategoryAvatar(
                                  categoryName: it.categoryName,
                                  skuPrefix: it.sku.split('-').first,
                                  imageUrl: it.imageUrl,
                                ),
                                title: Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  it.sku,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
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

  void _finishSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (widget.embedded) {
      _qtyController.clear();
      _refController.clear();
      _notesController.clear();
      _initData();
      widget.onSaved?.call();
    } else {
      Navigator.pop(context, true);
    }
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
                ? 'Masukkan jumlah stok fisik aktual'
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
          'Stok fisik sama dengan stok tercatat (${item.currentStock} ${item.unit})',
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
        _finishSuccess('Hasil Stock Opname disimpan');
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
      _finishSuccess(
        _transactionType == 'IN'
            ? 'Barang masuk dicatat'
            : 'Barang keluar dicatat',
      );
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

    String submitLabel = 'Simpan Barang Masuk';
    IconData submitIcon = Icons.check_circle_outline_rounded;
    if (_transactionType == 'OUT') {
      submitLabel = 'Simpan Barang Keluar';
    } else if (_isAdjust) {
      submitLabel = 'Simpan Hasil Opname';
    }

    final bodyContent = _isLoadingItems
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada Master Barang terdaftar.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                    children: [
                      // 1. Pill Tab Masuk / Keluar / Opname (Persis Layar 4 Mockup)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE8EEF5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModePill(
                                label: 'Masuk',
                                selected: _transactionType == 'IN',
                                onTap: () => _onTypeChanged('IN'),
                              ),
                            ),
                            Expanded(
                              child: _ModePill(
                                label: 'Keluar',
                                selected: _transactionType == 'OUT',
                                onTap: () => _onTypeChanged('OUT'),
                              ),
                            ),
                            if (_isAdmin)
                              Expanded(
                                child: _ModePill(
                                  label: 'Opname',
                                  selected: _transactionType == 'ADJUSTMENT',
                                  onTap: () => _onTypeChanged('ADJUSTMENT'),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 2. Kartu Form Utama Putih Bersih
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8EEF5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isAdjust ? 'Barang yang Dicek' : 'Pilih Barang',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Selector Barang yang bisa diketuk untuk cari cepat
                            if (item != null)
                              InkWell(
                                onTap: _openItemPicker,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
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
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.sku}  •  Sistem: ${item.currentStock} ${item.unit.toLowerCase()}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Baris Stok Tercatat di Sistem (Khusus Opname, persis Layar 4 Mockup)
                            if (_isAdjust && item != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Stok Tercatat di Sistem',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      '${item.currentStock} ${item.unit.toLowerCase()}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Kotak Jumlah dengan Tombol Stepper - dan + (Persis Layar 4 Mockup)
                            Text(
                              _isAdjust
                                  ? 'Hitung Stok Fisik Aktual'
                                  : 'Jumlah ($unitLabel)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _StepperButton(
                                    icon: Icons.remove_rounded,
                                    isPrimary: false,
                                    onTap: () => _stepQty(-1),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _qtyController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: '0',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  _StepperButton(
                                    icon: Icons.add_rounded,
                                    isPrimary: true,
                                    onTap: () => _stepQty(1),
                                  ),
                                ],
                              ),
                            ),

                            // Banner Selisih Otomatis (Persis Layar 4 Mockup)
                            if (_isAdjust && opnameDiff != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: opnameDiff == 0
                                      ? const Color(0xFFF1F5F9)
                                      : opnameDiff > 0
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Selisih Otomatis',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: opnameDiff == 0
                                            ? const Color(0xFF475569)
                                            : opnameDiff > 0
                                                ? const Color(0xFF047857)
                                                : const Color(0xFFB91C1C),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        opnameDiff == 0
                                            ? '0 ${item!.unit.toLowerCase()}'
                                            : '${opnameDiff > 0 ? '+' : ''}$opnameDiff ${item!.unit.toLowerCase()}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: opnameDiff == 0
                                              ? const Color(0xFF475569)
                                              : opnameDiff > 0
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

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
                              const SizedBox(height: 12),
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

                            if (!_isAdjust && item != null && item.hasPack) ...[
                              const SizedBox(height: 12),
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

                            if (!_isAdjust) ...[
                              const SizedBox(height: 12),
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

                            const SizedBox(height: 12),
                            TextField(
                              controller: _refController,
                              decoration: InputDecoration(
                                labelText: _isAdjust
                                    ? 'No. Berita Acara (Opsional)'
                                    : 'No. Pesanan / Surat Jalan',
                                hintText: _isAdjust
                                    ? 'Contoh: OPN-NOV-2026'
                                    : 'Contoh: 2611ABCD123',
                              ),
                            ),

                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Catatan (Opsional)',
                                hintText: _isAdjust
                                    ? 'Contoh: 2 unit kemasan penyok di Rak A1'
                                    : 'Contoh: Restock Supplier',
                              ),
                            ),

                            const SizedBox(height: 18),

                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSubmitting ? null : _submitTransaction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF155EEF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(submitIcon, size: 19),
                                label: Text(
                                  submitLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

    if (widget.embedded) return bodyContent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Mutasi & Opname')),
      body: bodyContent,
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF155EEF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? const Color(0xFF155EEF) : const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: isPrimary ? Colors.white : const Color(0xFF0F172A),
            size: 22,
          ),
        ),
      ),
    );
  }
}
