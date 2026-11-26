import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/core/supabase_config.dart';
import 'package:warehouse_project/models/wms_models.dart';

class _CsvPreviewRow {
  final int lineNumber;
  final String sku;
  final String name;
  final String categoryName;
  final String unit;
  final int packQty;
  final int buyPrice;
  final int sellPrice;
  final int? sellPricePack;
  final int minStock;
  final String rackLocation;
  final int initialStock;
  final String? errorMessage;
  final bool isDuplicateSku;

  _CsvPreviewRow({
    required this.lineNumber,
    required this.sku,
    required this.name,
    required this.categoryName,
    required this.unit,
    required this.packQty,
    required this.buyPrice,
    required this.sellPrice,
    this.sellPricePack,
    required this.minStock,
    required this.rackLocation,
    required this.initialStock,
    this.errorMessage,
    this.isDuplicateSku = false,
  });

  bool get isValid => errorMessage == null && !isDuplicateSku;
}

class CsvImportDialog extends StatefulWidget {
  final List<ItemModel> existingItems;
  final List<CategoryModel> existingCategories;
  final VoidCallback onImportSuccess;

  const CsvImportDialog({
    super.key,
    required this.existingItems,
    required this.existingCategories,
    required this.onImportSuccess,
  });

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  final TextEditingController _csvCtrl = TextEditingController();
  List<_CsvPreviewRow> _previewRows = [];
  bool _hasParsed = false;
  bool _isImporting = false;
  String? _statusMessage;

  static const String _sampleCsv =
      'sku,name,category,unit,pack_qty,buy_price,sell_price,sell_price_pack,min_stock,rack_location,initial_stock\n'
      'SND-001,Sendok Makan Stainless Tebal,Alat Makan,Pcs,12,2500,3500,38000,24,Rak A-01,60\n'
      'PNC-002,Panci Kukus Stainless 28cm,Peralatan Masak,Pcs,1,45000,65000,,5,Rak B-03,10';

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  /// Mendukung pemisah koma (,) atau titik koma (;) — umum pada Excel region Indonesia
  List<String> _splitCsvLine(String line, String delimiter) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  int? _parseIntClean(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9-]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  void _parseCsvText() {
    final rawText = _csvCtrl.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _previewRows = [];
        _hasParsed = false;
        _statusMessage = 'Tempel data CSV atau salin contoh terlebih dahulu.';
      });
      return;
    }

    final lines = const LineSplitter()
        .convert(rawText)
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return;

    // Deteksi delimiter otomatis (Excel Indonesia sering memakai ';', atau tab jika copy-paste langsung dari sel)
    final firstLine = lines.first;
    final delimiter = firstLine.contains('\t')
        ? '\t'
        : (firstLine.split(';').length > firstLine.split(',').length
            ? ';'
            : ',');

    final existingSkuSet =
        widget.existingItems.map((e) => e.sku.toLowerCase()).toSet();
    final seenInFile = <String>{};
    final parsed = <_CsvPreviewRow>[];

    for (int i = 0; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i], delimiter);

      // Lewati baris header jika kolom pertama bertuliskan 'sku'
      if (i == 0 && cols.isNotEmpty && cols[0].toLowerCase() == 'sku') {
        continue;
      }

      String col(int idx) => idx < cols.length ? cols[idx].trim() : '';

      final sku = col(0).toUpperCase();
      final name = col(1);
      final categoryName = col(2);
      final unit = col(3).isEmpty ? 'Pcs' : col(3);
      final packQty = _parseIntClean(col(4)) ?? 1;
      final buyPrice = _parseIntClean(col(5)) ?? 0;
      final sellPrice = _parseIntClean(col(6)) ?? 0;
      final sellPricePackRaw = _parseIntClean(col(7));
      final minStock = _parseIntClean(col(8)) ?? 5;
      final rackLocation = col(9);
      final initialStock = _parseIntClean(col(10)) ?? 0;

      String? error;
      bool isDup = false;

      if (sku.isEmpty || name.isEmpty) {
        error = 'SKU dan Nama Barang wajib diisi';
      } else if (packQty < 1) {
        error = 'Isi per lusin minimal 1';
      } else if (initialStock < 0 || buyPrice < 0 || sellPrice < 0) {
        error = 'Angka stok/harga tidak boleh negatif';
      } else if (existingSkuSet.contains(sku.toLowerCase())) {
        isDup = true;
      } else if (seenInFile.contains(sku.toLowerCase())) {
        error = 'SKU ganda di dalam file CSV';
      }

      if (sku.isNotEmpty) {
        seenInFile.add(sku.toLowerCase());
      }

      parsed.add(
        _CsvPreviewRow(
          lineNumber: i + 1,
          sku: sku,
          name: name,
          categoryName: categoryName,
          unit: unit,
          packQty: packQty,
          buyPrice: buyPrice,
          sellPrice: sellPrice,
          sellPricePack: packQty > 1 ? sellPricePackRaw : null,
          minStock: minStock,
          rackLocation: rackLocation,
          initialStock: initialStock,
          errorMessage: error,
          isDuplicateSku: isDup,
        ),
      );
    }

    setState(() {
      _previewRows = parsed;
      _hasParsed = true;
      _statusMessage = null;
    });
  }

  Future<void> _executeImport() async {
    final validRows = _previewRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _statusMessage = 'Menyimpan ${validRows.length} barang ke Supabase...';
    });

    try {
      // Peta nama kategori (lowercase) -> id
      final categoryMap = <String, String>{
        for (final c in widget.existingCategories) c.name.toLowerCase(): c.id,
      };

      // 1. Buat kategori baru yang belum ada di database
      final newCategoryNames = <String>{};
      for (final row in validRows) {
        final cat = row.categoryName.trim();
        if (cat.isNotEmpty && !categoryMap.containsKey(cat.toLowerCase())) {
          newCategoryNames.add(cat);
        }
      }

      for (final catName in newCategoryNames) {
        try {
          final inserted = await supabase
              .from('categories')
              .insert({'name': catName})
              .select('id, name')
              .single();
          categoryMap[(inserted['name'] as String).toLowerCase()] =
              inserted['id'] as String;
        } on PostgrestException catch (e) {
          // Jika bentrok case-insensitive, ambil ulang dari database
          if (e.code == '23505') {
            final existing = await supabase
                .from('categories')
                .select('id, name')
                .ilike('name', catName)
                .maybeSingle();
            if (existing != null) {
              categoryMap[(existing['name'] as String).toLowerCase()] =
                  existing['id'] as String;
            }
          } else {
            rethrow;
          }
        }
      }

      // 2. Simpan item satu per satu + catat stok awal via mutasi IN
      int successCount = 0;
      int stockFailCount = 0;

      for (final row in validRows) {
        final catId = row.categoryName.isEmpty
            ? null
            : categoryMap[row.categoryName.toLowerCase()];

        final created = await supabase
            .from('items')
            .insert({
              'sku': row.sku,
              'name': row.name,
              'category_id': catId,
              'unit': row.unit,
              'min_stock': row.minStock,
              'rack_location': row.rackLocation,
              'pack_qty': row.packQty,
              'buy_price': row.buyPrice,
              'sell_price': row.sellPrice,
              'sell_price_pack': row.sellPricePack,
            })
            .select('id')
            .single();

        successCount++;

        if (row.initialStock > 0) {
          try {
            await supabase.from('stock_transactions').insert({
              'item_id': created['id'],
              'type': 'IN',
              'input_unit': 'pcs',
              'input_qty': row.initialStock,
              'quantity': row.initialStock,
              'unit_price': row.buyPrice,
              'reason': 'pembelian',
              'notes': 'Stok awal (Impor CSV)',
            });
          } catch (_) {
            stockFailCount++;
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onImportSuccess();

      final skippedCount = _previewRows.where((r) => r.isDuplicateSku).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil impor $successCount barang'
            '${skippedCount > 0 ? ', $skippedCount SKU lama dilewati' : ''}'
            '${stockFailCount > 0 ? ' ($stockFailCount stok awal gagal dicatat)' : ''}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _statusMessage = 'Gagal impor: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _previewRows.where((r) => r.isValid).length;
    final duplicateCount = _previewRows.where((r) => r.isDuplicateSku).length;
    final errorCount = _previewRows.where((r) => r.errorMessage != null).length;

    return AlertDialog(
      title: const Text('Impor Barang dari CSV / Spreadsheet'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Urutan kolom: sku, name, category, unit, pack_qty, buy_price, sell_price, sell_price_pack, min_stock, rack_location, initial_stock\n'
                'Tips: Anda bisa langsung salin (Ctrl+C) tabel dari Excel / Google Sheets dan tempel di kotak bawah.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isImporting
                          ? null
                          : () {
                              _csvCtrl.text = _sampleCsv;
                              _parseCsvText();
                            },
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Isi Contoh CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _sampleCsv),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Template CSV disalin ke clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin Template'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _csvCtrl,
                maxLines: 6,
                enabled: !_isImporting,
                style: TextStyle(
                  fontFamily: kIsWeb ? 'monospace' : null,
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  hintText:
                      'Tempel data CSV atau sel Excel/Google Sheets di sini...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _parseCsvText,
                icon: const Icon(Icons.preview),
                label: const Text('Periksa & Pratinjau Data'),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusMessage!.startsWith('Gagal')
                        ? Colors.red.shade700
                        : const Color(0xFF1565C0),
                  ),
                ),
              ],
              if (_hasParsed) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text('Siap Impor: $validCount'),
                      backgroundColor: Colors.green.shade100,
                    ),
                    if (duplicateCount > 0)
                      Chip(
                        label:
                            Text('SKU Sudah Ada (Dilewati): $duplicateCount'),
                        backgroundColor: Colors.orange.shade100,
                      ),
                    if (errorCount > 0)
                      Chip(
                        label: Text('Baris Error: $errorCount'),
                        backgroundColor: Colors.red.shade100,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _previewRows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Tidak ada baris data yang terbaca.'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _previewRows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final r = _previewRows[idx];
                            final statusColor = r.errorMessage != null
                                ? Colors.red.shade700
                                : (r.isDuplicateSku
                                    ? Colors.orange.shade800
                                    : Colors.green.shade700);
                            final statusText = r.errorMessage ??
                                (r.isDuplicateSku
                                    ? 'Dilewati (SKU sudah terdaftar)'
                                    : 'Siap • Stok awal: ${r.initialStock} ${r.unit}'
                                        '${r.packQty > 1 ? ' (1 lusin = ${r.packQty})' : ''}');

                            return ListTile(
                              dense: true,
                              title: Text(
                                '${r.sku.isEmpty ? "(Tanpa SKU)" : r.sku} — ${r.name.isEmpty ? "(Tanpa Nama)" : r.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Kategori: ${r.categoryName.isEmpty ? "Umum" : r.categoryName} • '
                                'Beli: ${formatRupiah(r.buyPrice)} • Jual: ${formatRupiah(r.sellPrice)}\n'
                                '$statusText',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: (_isImporting || validCount == 0) ? null : _executeImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          child: _isImporting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Impor $validCount Barang'),
        ),
      ],
    );
  }
}
