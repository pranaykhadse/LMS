import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/dashboard/model/user_profile_detail.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';
import 'package:lms/app/features/dashboard/viewmodel/account_settings_view_model.dart';

const _asPurple = Color(0xFF5756C9);
const _asInk = Color(0xFF172033);
const _asMuted = Color(0xFF7C879D);
const _asBg = Color(0xFFF5F7FC);
const _asFieldBg = Color(0xFFF4F6FA);

class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(AccountSettingsViewModel.provider);

    return Scaffold(
      backgroundColor: _asBg,
      drawer: const AppDrawer(),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: LmsAppBar(),
      ),
      body: switch (state.state) {
        DataProviderState.idle ||
        DataProviderState.loading =>
          const Center(child: CircularProgressIndicator(color: _asPurple)),
        DataProviderState.error => _ErrorView(
            message: state.error ?? 'Unable to load your profile.',
            onRetry: () =>
                ref.read(AccountSettingsViewModel.provider.notifier).fetch(),
          ),
        DataProviderState.data => state.data == null
            ? const _ErrorView(message: 'No profile data found.')
            : _AccountSettingsBody(detail: state.data!),
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _asMuted, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _asMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: _asPurple),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountSettingsBody extends StatelessWidget {
  const _AccountSettingsBody({required this.detail});
  final UserProfileDetail detail;

  @override
  Widget build(BuildContext context) {
    final profile = detail.profile;
    final user = detail.user;
    final name = [profile.firstname, profile.lastname]
        .where((s) => (s ?? '').trim().isNotEmpty)
        .join(' ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ProfileHeaderCard(name: name.isEmpty ? 'User' : name, email: user.email ?? '', profile: profile),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.person_outline_rounded,
          title: 'Personal Details',
          children: [
            _FieldRow(label: 'Location', value: profile.location),
            _FieldRow(label: 'Website', value: profile.website?.toString()),
            _FieldRow(label: 'LinkedIn', value: profile.linkedIn?.toString()),
            _FieldRow(label: 'Phone Number', value: detail.phoneNumber),
            _ToggleRow(
              label: 'Receive Text Message Reminders',
              value: detail.enableTextMessages,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.work_outline_rounded,
          title: 'Work Information',
          children: [
            _FieldRow(label: 'Division', value: profile.division),
            _FieldRow(label: 'Department', value: profile.department),
            _FieldRow(label: 'Cost Code', value: user.costCode),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.tune_rounded,
          title: 'Preferences',
          children: [
            _ToggleRow(
              label: 'Two-Factor Auth',
              sublabel: 'Add an extra layer of security',
              value: user.enableTwoFactorAuth == 1,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.groups_outlined,
          title: 'Primary Group',
          children: [
            _SelectedChip(label: user.primaryGroupLabel ?? 'Not assigned'),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.notifications_outlined,
          title: 'Notification Type',
          children: _notificationOptions
              .map((label) => _RadioRow(
                    label: label,
                    selected: (profile.notificationType?.toString() ?? '')
                        .toLowerCase()
                        .contains(label.split(' ').first.toLowerCase()),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.security_rounded,
          title: 'Security',
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Toast.info(context, 'Password reset coming soon.'),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Reset Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _asInk,
                  side: const BorderSide(color: Color(0xFFE1E5EE)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const AppFooter(),
      ],
    );
  }
}

const _notificationOptions = ['Email', 'Slack', 'Teams', 'Text Message (SMS)', 'WhatsApp'];

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.name, required this.email, required this.profile});
  final String name;
  final String email;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final base = profile.avatarBaseUrl?.toString() ?? '';
    final path = profile.avatarPath?.toString() ?? '';
    final url = path.startsWith('http') ? path : (base.isNotEmpty && path.isNotEmpty ? '$base$path' : '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: _asPurple, size: 20),
              const SizedBox(width: 6),
              const Text('Profile', style: TextStyle(color: _asInk, fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Toast.info(context, 'Editing your profile is coming soon.'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _asPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF10121B),
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(color: _asInk, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: _asMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _asPurple),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _asPurple,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(children.length * 2 - 1, (i) {
            if (i.isOdd) return const SizedBox(height: 12);
            return children[i ~/ 2];
          }),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _asMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _asFieldBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            hasValue ? value! : 'Not provided',
            style: TextStyle(
              color: hasValue ? _asInk : _asMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, this.sublabel, required this.value});
  final String label;
  final String? sublabel;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: _asFieldBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _asInk, fontWeight: FontWeight.w700, fontSize: 14)),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(sublabel!, style: const TextStyle(color: _asMuted, fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => Toast.info(context, 'Coming soon.'),
            activeThumbColor: _asPurple,
          ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _asPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _asPurple, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked, color: _asPurple, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: _asPurple, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? _asPurple.withValues(alpha: 0.08) : _asFieldBg,
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: _asPurple, width: 1.4) : null,
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? _asPurple : _asMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? _asPurple : _asInk,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
