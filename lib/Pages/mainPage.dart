import 'package:flutter/material.dart';
import 'package:warehouse_project/Pages/categoryPage.dart';
import 'package:warehouse_project/Pages/formPage.dart';
import 'package:warehouse_project/Pages/homePage.dart';
import 'package:warehouse_project/Pages/itemsPage.dart';
import 'package:warehouse_project/Pages/loginPage.dart';
import 'package:warehouse_project/core/supabase_config.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
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
              backgroundColor: const Color(0xFF1D61E7),
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

  Future<void> _openMutationForm() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FormPage()),
    );
    if (updated == true) {
      _triggerRefresh();
    }
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
    final pages = [
      HomePage(
        key: ValueKey('home_$_refreshTick'),
        isAdmin: _role == 'admin',
        onOpenMutation: _openMutationForm,
        onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
      ),
      ItemsPage(
        key: ValueKey('items_$_refreshTick'),
        onDataChanged: _triggerRefresh,
        isAdmin: _role == 'admin',
      ),
      CategoryPage(
        key: ValueKey('cat_$_refreshTick'),
        onDataChanged: _triggerRefresh,
        isAdmin: _role == 'admin',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar bersih ala Boxora (Logo + Brand + Refresh + Profil/Logout)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D61E7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.view_in_ar_rounded,
                      color: Color(0xFF1D61E7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Arasy39 WMS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2559),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$_displayName${_role != null ? ' • ${_role!.toUpperCase()}' : ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8F9BBA),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat Ulang',
                    onPressed: _triggerRefresh,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE9EDF7)),
                      ),
                    ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF1B2559),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Keluar',
                    onPressed: _confirmLogout,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE9EDF7)),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFE53935),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Isi halaman aktif
            Expanded(child: pages[_selectedIndex]),
          ],
        ),
      ),

      // Floating Bottom Dock bergaya Boxora + Tombol Aksi Biru di kanan
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE9EDF7)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B2559).withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavPillItem(
                        icon: Icons.home_rounded,
                        label: 'Beranda',
                        selected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      _NavPillItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Barang',
                        selected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      _NavPillItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Kategori',
                        selected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tombol + Mutasi Stok bulat membulat (Boxora style)
              Material(
                color: const Color(0xFF1D61E7),
                borderRadius: BorderRadius.circular(20),
                elevation: 4,
                shadowColor: const Color(0xFF1D61E7).withValues(alpha: 0.35),
                child: InkWell(
                  onTap: _openMutationForm,
                  borderRadius: BorderRadius.circular(20),
                  child: const SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
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

class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.icon,
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
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B2559) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : const Color(0xFF8F9BBA),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
