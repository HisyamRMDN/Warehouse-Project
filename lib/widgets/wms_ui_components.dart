import 'package:flutter/material.dart';
import 'package:warehouse_project/models/wms_models.dart';

/// Helper warna & emoji kategori yang konsisten di seluruh halaman
class WmsCategoryStyle {
  static String emoji(String? catName) {
    if (catName == null) return '📦';
    final n = catName.toLowerCase();
    if (n.contains('panci') || n.contains('wajan')) return '🍳';
    if (n.contains('wadah') || n.contains('saringan') || n.contains('baskom')) {
      return '🏺';
    }
    if (n.contains('mangkok') || n.contains('piring')) return '🥣';
    if (n.contains('sendok') ||
        n.contains('alat makan') ||
        n.contains('masak')) {
      return '🍴';
    }
    if (n.contains('gelas') || n.contains('termos') || n.contains('mug')) {
      return '🥤';
    }
    if (n.contains('pisau') || n.contains('potong')) return '🔪';
    if (n.contains('prasmanan')) return '🍲';
    return '📦';
  }

  static Color color(String? catName) {
    if (catName == null) return Colors.blueGrey;
    final n = catName.toLowerCase();
    if (n.contains('panci') || n.contains('wajan')) {
      return const Color(0xFFE28743);
    }
    if (n.contains('wadah') || n.contains('saringan')) {
      return const Color(0xFF1E88E5);
    }
    if (n.contains('mangkok') || n.contains('piring')) {
      return const Color(0xFF26A69A);
    }
    if (n.contains('sendok') || n.contains('alat makan')) {
      return const Color(0xFF7E57C2);
    }
    if (n.contains('gelas') || n.contains('termos')) {
      return const Color(0xFF00ACC1);
    }
    if (n.contains('pisau') || n.contains('potong')) {
      return const Color(0xFFD81B60);
    }
    if (n.contains('prasmanan')) return const Color(0xFFEF6C00);
    return Colors.blueGrey;
  }
}

/// Kartu statistik ringkas bergaya Boxora / Gostock (bisa dipakai di HomePage)
class WmsStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isPrimary;
  final VoidCallback? onTap;

  const WmsStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor = const Color(0xFF1565C0),
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary ? accentColor : Colors.white;
    final titleColor =
        isPrimary ? Colors.white.withValues(alpha: 0.88) : Colors.black54;
    final valueColor = isPrimary ? Colors.white : const Color(0xFF1A202C);
    final subColor =
        isPrimary ? Colors.white.withValues(alpha: 0.72) : Colors.black45;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? null
                : Border.all(color: const Color(0xFFEDF2F7), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? accentColor.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.18)
                          : accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isPrimary ? Colors.white : accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak pencarian membulat yang seragam di semua halaman
class WmsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasText;

  const WmsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasText,
    this.hintText = 'Cari nama barang atau kode SKU...',
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
            color: Colors.black.withValues(alpha: 0.025),
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
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF1565C0)),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: Colors.grey),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

/// Avatar ikon kategori lembut untuk kartu barang & riwayat mutasi
class CategoryAvatar extends StatelessWidget {
  final String? categoryName;
  final String skuPrefix;

  const CategoryAvatar({
    super.key,
    this.categoryName,
    required this.skuPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final color = WmsCategoryStyle.color(categoryName);
    final emoji = WmsCategoryStyle.emoji(categoryName);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 1),
          Text(
            skuPrefix,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill indikator jumlah & status stok (Habis / Menipis / Aman)
class StockBadge extends StatelessWidget {
  final ItemModel item;

  const StockBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isOut = item.currentStock == 0;
    final bool isLow = item.isLowStock;

    final Color bg = isOut
        ? const Color(0xFFFFEBEE)
        : isLow
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE3F2FD);
    final Color fg = isOut
        ? const Color(0xFFC62828)
        : isLow
            ? const Color(0xFFE65100)
            : const Color(0xFF1565C0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${item.currentStock} ${item.unit}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
        if (item.packBreakdown != null) ...[
          const SizedBox(height: 3),
          Text(
            '≈ ${item.packBreakdown}',
            style: const TextStyle(fontSize: 10.5, color: Colors.black45),
          ),
        ] else if (isOut || isLow) ...[
          const SizedBox(height: 3),
          Text(
            isOut ? 'Stok habis' : 'Min. ${item.minStock}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ],
    );
  }
}

/// Header bagian halaman dengan judul & aksi di kanan
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
