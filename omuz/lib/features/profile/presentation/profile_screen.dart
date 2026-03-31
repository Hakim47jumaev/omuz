import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/omuz_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(() => prov.loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();
    final profile = prov.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: prov.profileLoading || profile == null
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : OmuzPage.background(
              context: context,
              child: RefreshIndicator(
                onRefresh: () => prov.loadProfile(),
                child: ListView(
                  padding: OmuzPage.padding,
                  children: [
                  _buildUserCard(profile),
                  const SizedBox(height: 12),
                  if (!_isStaff(profile) && prov.wallet != null) ...[
                    _buildWalletCard(prov.wallet!),
                    const SizedBox(height: 12),
                  ],
                  if (_isStaff(profile))
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/resume'),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('Resume'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push('/resume'),
                            icon: const Icon(Icons.description, size: 18),
                            label: const Text('Resume'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push('/wallet/transactions'),
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: const Text('Transactions'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!_isStaff(profile)) ...[
                    const SizedBox(height: 16),
                    _buildXPCard(profile['xp'] as Map<String, dynamic>),
                    const SizedBox(height: 16),
                    _buildBadges(profile['badges'] as List<dynamic>),
                  ],
                  if (!_isStaff(profile)) ...[
                    const SizedBox(height: 16),
                    _buildHistory(profile['xp_history'] as List<dynamic>),
                  ],
                ],
                ),
              ),
            ),
    );
  }

  bool _isStaff(Map<String, dynamic> profile) {
    final user = profile['user'] as Map<String, dynamic>?;
    return user?['is_staff'] == true;
  }

  Future<void> _pickAndUploadAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    final ok = await context.read<ProfileProvider>().uploadAvatar(file.path);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile photo updated' : 'Could not update profile photo')),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> profile) {
    final user = profile['user'] as Map<String, dynamic>;
    final firstName = ((user['first_name'] as String?) ?? '').trim();
    final lastName = ((user['last_name'] as String?) ?? '').trim();
    final initialsSource = firstName.isNotEmpty
        ? firstName
        : (lastName.isNotEmpty ? lastName : '?');
    final fullName = [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
    final avatarUrl = (user['avatar_url'] as String?)?.trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          initialsSource[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24),
                        ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: InkWell(
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: _uploadingAvatar
                          ? Padding(
                              padding: const EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.edit,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 14,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'User' : fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  user['phone'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(Map<String, dynamic> w) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance_wallet, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  Text(
                    '${w['balance']} TJS',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Account', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                Text(
                  _formatAccount(w['account_number'] as String),
                  style: TextStyle(color: cs.onSurface, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAccount(String num) {
    final buf = StringBuffer();
    for (var i = 0; i < num.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(num[i]);
    }
    return buf.toString();
  }

  Widget _buildXPCard(Map<String, dynamic> xp) {
    final totalXp = xp['total_xp'] as int;
    final level = xp['level'] as int;
    final currentStreak = (xp['current_streak'] as int?) ?? 0;
    final bestStreak = (xp['best_streak'] as int?) ?? 0;
    final progressInLevel = (totalXp % 100) / 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _xpStat('Level', '$level', Icons.star, Colors.amber),
                _xpStat('Total XP', '$totalXp', Icons.bolt, Colors.orange),
                _xpStat('Streak', '$currentStreak d', Icons.local_fire_department, Colors.deepOrange),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best streak: $bestStreak days'),
                Text('Next level: ${100 - (totalXp % 100)} XP'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressInLevel,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xpStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildBadges(List<dynamic> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badges', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (badges.isEmpty)
          const Text('No badges yet. Complete lessons to earn them!')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) {
              return Chip(
                avatar: const Icon(Icons.emoji_events, size: 18),
                label: Text(b['label'] as String),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHistory(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('XP History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...history.map((h) => ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle, color: Colors.green, size: 20),
              title: Text(h['reason'] as String),
              trailing: Text('+${h['amount']} XP',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
      ],
    );
  }
}
