import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:warehouse_project/core/format.dart';
import 'package:warehouse_project/models/wms_models.dart';

enum LabelPaperPreset {
  thermal50x30('Stiker Termal 50×30 mm (Satuan)', 50, 30, 1),
  thermal4x6Grid('Kertas 4×6 Inci Xprinter (Grid 8 Label)', 101.6, 152.4, 8);

  final String label;
  final double widthMm;
  final double heightMm;
  final int labelsPerPage;

  const LabelPaperPreset(
    this.label,
    this.widthMm,
    this.heightMm,
    this.labelsPerPage,
  );
}

class BarcodeLabelSheet extends StatefulWidget {
  final ItemModel item;

  const BarcodeLabelSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, ItemModel item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeLabelSheet(item: item),
    );
  }

  @override
  State<BarcodeLabelSheet> createState() => _BarcodeLabelSheetState();
}

class _BarcodeLabelSheetState extends State<BarcodeLabelSheet> {
  LabelPaperPreset _preset = LabelPaperPreset.thermal50x30;
  bool _showPrice = false;

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final item = widget.item;
    final hasRack =
        item.rackLocation != null && item.rackLocation!.trim().isNotEmpty;

    pw.Widget buildSingleLabel({bool compact = false}) {
      return pw.Container(
        padding: pw.EdgeInsets.all(compact ? 5 : 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ARASY39 WMS',
                  style: pw.TextStyle(
                    fontSize: compact ? 5.5 : 6,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                if (hasRack)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.black,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      'RAK ${item.rackLocation!.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: compact ? 5.5 : 6,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: item.sku,
              width: compact ? 110 : 118,
              height: compact ? 24 : 28,
              drawText: true,
              textStyle: pw.TextStyle(
                fontSize: compact ? 7 : 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              item.name,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: compact ? 6 : 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (_showPrice && item.sellPrice > 0)
              pw.Text(
                formatRupiah(item.sellPrice),
                style: pw.TextStyle(
                  fontSize: compact ? 6 : 6.5,
                  color: PdfColors.grey800,
                ),
              ),
          ],
        ),
      );
    }

    final pageFormat = PdfPageFormat(
      _preset.widthMm * PdfPageFormat.mm,
      _preset.heightMm * PdfPageFormat.mm,
      marginAll: _preset == LabelPaperPreset.thermal50x30
          ? 1.5 * PdfPageFormat.mm
          : 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) {
          if (_preset == LabelPaperPreset.thermal50x30) {
            return pw.Center(child: buildSingleLabel());
          }
          // Grid 2 kolom x 4 baris untuk kertas termal 4x6 inci (Xprinter XP-420B)
          return pw.GridView(
            crossAxisCount: 2,
            crossAxisSpacing: 4 * PdfPageFormat.mm,
            mainAxisSpacing: 3 * PdfPageFormat.mm,
            childAspectRatio: 1.32,
            children: List.generate(
              8,
              (_) => buildSingleLabel(compact: true),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF155EEF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cetak Label Barcode Rak',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'SKU: ${widget.item.sku}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<LabelPaperPreset>(
                    value: _preset,
                    decoration: const InputDecoration(
                      labelText: 'Ukuran Kertas / Stiker Termal',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: LabelPaperPreset.values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _preset = val);
                    },
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Tampilkan Harga Jual di Label',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    value: _showPrice,
                    activeTrackColor: const Color(0xFF155EEF),
                    onChanged: (v) => setState(() => _showPrice = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PdfPreview(
                  key: ValueKey('${_preset.name}_$_showPrice'),
                  build: _buildPdf,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName: 'Label_${widget.item.sku}.pdf',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
