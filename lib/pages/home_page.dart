import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/kos_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../widgets/role_guard.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<UserProfile?> _profileFuture;
  late Future<List<Map<String, dynamic>>> _kosFuture;
  final KosService _kosService = KosService();

  @override
  void initState() {
    super.initState();
    _refreshData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.init();
      await NotificationService.instance.setupInteractedMessage();
    });
  }

  void _refreshData() {
    setState(() {
      _profileFuture = ProfileService().getMyProfile();
      _kosFuture = _kosService.fetchAll();
    });
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showAddKosDialog() async {
    final nameC = TextEditingController();
    final addrC = TextEditingController();
    final priceC = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kos Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Kos')),
            TextField(controller: addrC, decoration: const InputDecoration(labelText: 'Alamat')),
            TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (Rp)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (nameC.text.isNotEmpty) {
                final navigator = Navigator.of(ctx);
                await _kosService.add(
                  name: nameC.text.trim(),
                  address: addrC.text.trim(),
                  price: int.tryParse(priceC.text) ?? 0,
                );
                navigator.pop();
                _refreshData();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSecurityTest(String targetKosId) async {
    final updated = await _kosService.update(targetKosId, {'name': 'HACKED BY OTHER USER'});
    final deleted = await _kosService.delete(targetKosId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil Security Testing (RLS)'),
        content: Text(
          '1. Coba UPDATE data user lain:\n'
          '   ${updated ? "FAIL (Berhasil diubah!)" : "PASS (Ditolak oleh RLS)"}\n\n'
          '2. Coba DELETE data user lain:\n'
          '   ${deleted ? "FAIL (Berhasil dihapus!)" : "PASS (Ditolak oleh RLS)"}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showTokenDialog() async {
    final token = await NotificationService.instance.getToken() ?? 'Token belum tersedia';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('FCM Device Token'),
        content: SelectableText(token),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token disalin ke clipboard!')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Salin'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.id ?? '';

    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final p = snap.data;
        if (snap.hasError || p == null) {
          return const Scaffold(
            body: Center(child: Text('Gagal memuat profil')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('KosFinder (${p.role})'),
            actions: [
              IconButton(
                tooltip: 'Lihat FCM Token',
                icon: const Icon(Icons.notifications_active),
                onPressed: _showTokenDialog,
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(p.name.isEmpty ? p.email : p.name),
                  subtitle: Text('${p.email} • Role: ${p.role.toUpperCase()}'),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Daftar Kos Tersedia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _kosFuture,
                  builder: (context, kosSnap) {
                    if (kosSnap.connectionState != ConnectionState.done) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }
                    final items = kosSnap.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Belum ada data kos.'),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final kos = items[i];
                        final isMine = kos['owner_id'] == currentUserId;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.home, color: isMine ? Colors.green : Colors.grey),
                            title: Text(kos['name'] ?? '-'),
                            subtitle: Text('${kos['address'] ?? '-'} • Rp ${kos['price'] ?? 0}\n'
                                'Owner: ${isMine ? "Milik Anda" : "User Lain"}'),
                            trailing: isMine
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final ok = await _kosService.delete(kos['id']);
                                          if (ok) _refreshData();
                                        },
                                      ),
                                    ],
                                  )
                                : IconButton(
                                    tooltip: 'Uji RLS (Bypass Test)',
                                    icon: const Icon(Icons.security, color: Colors.orange),
                                    onPressed: () => _runSecurityTest(kos['id']),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: RoleGuard(
            role: p.role,
            allowed: const ['owner', 'admin'],
            child: FloatingActionButton.extended(
              onPressed: _showAddKosDialog,
              icon: const Icon(Icons.add_home),
              label: const Text('Tambah Kos'),
            ),
          ),
        );
      },
    );
  }
}
