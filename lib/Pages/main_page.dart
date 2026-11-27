import 'package:flutter/material.dart';
import 'package:warehouse_project/Pages/category_page.dart';
import 'package:warehouse_project/Pages/form_page.dart';
import 'package:warehouse_project/Pages/home_page.dart';
import 'package:warehouse_project/Pages/items_page.dart';
import 'package:warehouse_project/Pages/login_page.dart';
import 'package:warehouse_project/core/supabase_config.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0; // 0: Beranda, 1: Barang, 2: Mutasi
  int _refreshTick = 0;
  String? _role;
  String _displayName = 'Admin Gudang';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRole());
  }

  Future<void> _loadRole() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      await _forceLogout('Sesi berakhir, silakan login ulang');
      return;
    }
    try {
      final row = await supabase
          .from('profiles')
          .select('role, is_active, full_name, username')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      if (row == null || row['is_active'] != true) {
        await _forceLogout('Akun tidak aktif atau belum terdaftar');
        return;
      }
      setState(() {
        _role = row['role'] as String?;
        final name = (row['full_name'] as String?)?.trim();
        final uname = (row['username'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _displayName = name;
        } else if (uname != null && uname.isNotEmpty) {
          _displayName = uname;
        }
      });
    } catch (_) {}
  }

  Future<void> _forceLogout(String message) async {
    final messenger = ScaffoldMessenger.of(context);
    await _handleLogout();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Keluar dari Akun?'),
        content: const Text('Anda akan kembali ke layar login.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) await _handleLogout();
  }

  void _triggerRefresh() {
    setState(() => _refreshTick++);
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _openCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CategoryPage(
            isAdmin: _role == 'admin',
            onDataChanged: _triggerRefresh,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerTitles = [
      'Halo, $_displayName',
      'Master Barang',
      'Mutasi & Opname',
    ];
    final headerSubtitles = [
      'Arasy39 WMS • Gudang Utama',
      'Arasy39 WMS • Katalog SKU Aktif',
      'Arasy39 WMS • Pencatatan Stok',
    ];

    final pages = [
      HomePage(
        key: ValueKey('home_${_selectedIndex}_$_refreshTick'),
        isAdmin: _role == 'admin',
        onOpenMutation: () => _selectTab(2),
        onNavigateTab: _selectTab,
        onOpenCategories: _openCategoriesSheet,
      ),
      ItemsPage(
        key: ValueKey('items_${_selectedIndex}_$_refreshTick'),
        onDataChanged: _triggerRefresh,
        isAdmin: _role == 'admin',
      ),
      FormPage(
        key: ValueKey('form_${_selectedIndex}_$_refreshTick'),
        embedded: true,
        onSaved: () {
          _triggerRefresh();
          _selectTab(0);
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header bersih
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF155EEF),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Align(
                        key: ValueKey(_selectedIndex),
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerTitles[_selectedIndex],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              headerSubtitles[_selectedIndex],
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kategori Barang',
                    onPressed: _openCategoriesSheet,
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat Ulang',
                    onPressed: _triggerRefresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Keluar',
                    onPressed: _confirmLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Transisi perpindahan halaman halus (Fade + Subtle Slide)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnim = Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offsetAnim, child: child),
                  );
                },
                child: pages[_selectedIndex],
              ),
            ),
          ],
        ),
      ),

      // Floating Glass/Pill Navigation Bar dengan Indikator Meluncur & Expandable Label
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Latar kapsul biru lembut yang meluncur mulus antar tab
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        alignment: _selectedIndex == 0
                            ? Alignment.centerLeft
                            : _selectedIndex == 1
                                ? Alignment.center
                                : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: 1 / 3,
                          heightFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _AnimatedNavItem(
                              outlinedIcon: Icons.home_outlined,
                              filledIcon: Icons.home_rounded,
                              label: 'Beranda',
                              selected: _selectedIndex == 0,
                              onTap: () => _selectTab(0),
                            ),
                          ),
                          Expanded(
                            child: _AnimatedNavItem(
                              outlinedIcon: Icons.inventory_2_outlined,
                              filledIcon: Icons.inventory_2_rounded,
                              label: 'Barang',
                              selected: _selectedIndex == 1,
                              onTap: () => _selectTab(1),
                            ),
                          ),
                          Expanded(
                            child: _AnimatedNavItem(
                              outlinedIcon: Icons.swap_horiz_rounded,
                              filledIcon: Icons.swap_horiz_rounded,
                              label: 'Mutasi',
                              selected: _selectedIndex == 2,
                              onTap: () => _selectTab(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tombol (+) Aksi Cepat Biru dengan animasi rotasi saat tab Mutasi aktif
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedNavItem extends StatelessWidget {
  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.outlinedIcon,
    required this.filledIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF155EEF);
    final inactiveColor = const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? filledIcon : outlinedIcon,
                size: 20,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: activeColor,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
