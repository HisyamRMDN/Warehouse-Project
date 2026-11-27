import 'package:flutter/material.dart';
import 'package:warehouse_project/models/wms_models.dart';

/// Helper ikon Google Material & warna kategori tanpa emoji
class WmsCategoryStyle {
  static IconData icon(String? catName) {
    if (catName == null) return Icons.inventory_2_outlined;
    final n = catName.toLowerCase();
    if (n.contains('panci') || n.contains('wajan')) {
      return Icons.soup_kitchen_outlined;
    }
    if (n.contains('wadah') || n.contains('saringan') || n.contains('baskom')) {
      return Icons.takeout_dining_outlined;
    }
    if (n.contains('mangkok') || n.contains('piring')) {
      return Icons.rice_bowl_outlined;
    }
    if (n.contains('sendok') ||
        n.contains('alat makan') ||
        n.contains('masak')) {
      return Icons.restaurant_outlined;
    }
    if (n.contains('gelas') || n.contains('termos') || n.contains('mug')) {
      return Icons.local_cafe_outlined;
    }
    if (n.contains('pisau') || n.contains('potong')) {
      return Icons.carpenter_outlined;
    }
    if (n.contains('prasmanan')) {
      return Icons.room_service_outlined;
    }
    return Icons.kitchen_outlined;
  }

  static Color color(String? catName) {
    if (catName == null) return const Color(0xFF475569);
    final n = catName.toLowerCase();
    if (n.contains('panci') || n.contains('wajan')) {
      return const Color(0xFF155EEF);
    }
    if (n.contains('wadah') || n.contains('saringan')) {
      return const Color(0xFF0284C7);
    }
    if (n.contains('mangkok') || n.contains('piring')) {
      return const Color(0xFF0D9488);
    }
    if (n.contains('sendok') || n.contains('alat makan')) {
      return const Color(0xFF4F46E5);
    }
    if (n.contains('gelas') || n.contains('termos')) {
      return const Color(0xFF0891B2);
    }
    if (n.contains('pisau') || n.contains('potong')) {
      return const Color(0xFFE11D48);
    }
    if (n.contains('prasmanan')) return const Color(0xFFD97706);
    return const Color(0xFF475569);
  }
}

/// Kartu statistik ringkas bergaya bersih (dipakai untuk metrik Admin di Beranda)
class WmsStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const WmsStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor = const Color(0xFF155EEF),
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
            border: Border.all(color: const Color(0xFFE8EEF5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak pencarian membulat dengan ikon Google Material
class WmsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onScanTap; // <-- Tambahkan ini
  final bool hasText;

  const WmsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasText,
    this.onScanTap, // <-- Tambahkan ini
    this.hintText = 'Cari barang, SKU, atau rak...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: onClear,
                )
              : IconButton(
                  tooltip: 'Pindai Barcode SKU',
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20,
                    color: Color(0xFF155EEF),
                  ),
                  onPressed: onScanTap,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}

/// Avatar ikon kategori berbasis Google Material Icons
/// Avatar ikon kategori berbasis Google Material Icons + foto produk Shopee
class CategoryAvatar extends StatelessWidget {
  final String? categoryName;
  final String? skuPrefix;
  final String? imageUrl;
  final double size;

  const CategoryAvatar({
    super.key,
    this.categoryName,
    this.skuPrefix,
    this.imageUrl,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final key = categoryName ?? skuPrefix;
    final iconData = WmsCategoryStyle.icon(key);
    final fgColor = WmsCategoryStyle.color(key);
    final bgColor = fgColor.withValues(alpha: 0.12);
    final url = imageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            iconData,
            color: fgColor,
            size: size * 0.48,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(iconData, color: fgColor, size: size * 0.48),
    );
  }
}

/// Pill indikator jumlah stok bergaya mockup (biru lembut / kuning / merah lembut)
class StockBadge extends StatelessWidget {
  final ItemModel item;

  const StockBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isOut = item.currentStock == 0;
    final bool isLow = item.isLowStock;

    final Color bg = isOut
        ? const Color(0xFFFEE2E2)
        : isLow
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFEFF6FF);
    final Color fg = isOut
        ? const Color(0xFFDC2626)
        : isLow
            ? const Color(0xFFB45309)
            : const Color(0xFF155EEF);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${item.currentStock} ${item.unit.toLowerCase()}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
        if (item.packBreakdown != null) ...[
          const SizedBox(height: 3),
          Text(
            item.packBreakdown!,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ],
    );
  }
}

/// Header section bersih dengan tombol aksi teks biru di kanan
class WmsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const WmsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
