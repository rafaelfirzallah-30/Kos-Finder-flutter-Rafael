import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String role; // seeker | owner | admin

  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isSeeker => role == 'seeker';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as String,
        email: (m['email'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        role: (m['role'] ?? 'seeker') as String,
      );
}

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserProfile.fromMap(data);
      }

      // Jika profil belum ada di tabel, gunakan fallback & coba buatkan barisnya
      final defaultRole = (user.userMetadata?['role'] as String?) ?? 'owner';
      final defaultName = (user.userMetadata?['name'] as String?) ?? 'User';

      final fallbackData = {
        'id': user.id,
        'email': user.email ?? '',
        'name': defaultName,
        'role': defaultRole,
      };

      try {
        await _client.from('profiles').upsert(fallbackData);
      } catch (_) {}

      return UserProfile.fromMap(fallbackData);
    } catch (_) {
      // Fallback agar halaman tidak blank putih jika database sedang proses
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        name: (user.userMetadata?['name'] as String?) ?? 'User',
        role: (user.userMetadata?['role'] as String?) ?? 'owner',
      );
    }
  }
}
