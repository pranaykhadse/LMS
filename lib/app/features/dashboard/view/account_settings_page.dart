import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/user_profile_detail.dart';
import 'package:lms/app/features/dashboard/viewmodel/account_settings_view_model.dart';

const _asPurple = Color(0xFF5756C9);
const _asInk = Color(0xFF172033);
const _asMuted = Color(0xFF7C879D);
const _asBg = Color(0xFFF5F7FC);
const _asFieldBg = Color(0xFFF4F6FA);

/// Avatar upload isn't wired up yet (no confirmed upload endpoint), so for
/// now the avatar is just a plain URL the user can paste in — this mirrors
/// the same resolution the profile PUT's avatar_path/avatar_base_url pair
/// would otherwise need.
String _resolveAvatarUrl(UserProfile profile) {
  final base = profile.avatarBaseUrl?.toString() ?? '';
  final path = profile.avatarPath?.toString() ?? '';
  return path.startsWith('http') ? path : (base.isNotEmpty && path.isNotEmpty ? '$base$path' : '');
}

class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(AccountSettingsViewModel.provider);

    return AppScaffold(
      backgroundColor: _asBg,
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

class _AccountSettingsBody extends ConsumerStatefulWidget {
  const _AccountSettingsBody({required this.detail});
  final UserProfileDetail detail;

  @override
  ConsumerState<_AccountSettingsBody> createState() => _AccountSettingsBodyState();
}

class _AccountSettingsBodyState extends ConsumerState<_AccountSettingsBody> {
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _linkedInCtrl;
  late final TextEditingController _divisionCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _avatarUrlCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.detail.profile;
    _firstnameCtrl = TextEditingController(text: p.firstname ?? '');
    _lastnameCtrl = TextEditingController(text: p.lastname ?? '');
    _locationCtrl = TextEditingController(text: p.location ?? '');
    _websiteCtrl = TextEditingController(text: p.website?.toString() ?? '');
    _linkedInCtrl = TextEditingController(text: p.linkedIn?.toString() ?? '');
    _divisionCtrl = TextEditingController(text: p.division ?? '');
    _departmentCtrl = TextEditingController(text: p.department ?? '');
    _avatarUrlCtrl = TextEditingController(text: _resolveAvatarUrl(p));
    _phoneCtrl = TextEditingController(text: widget.detail.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    _linkedInCtrl.dispose();
    _divisionCtrl.dispose();
    _departmentCtrl.dispose();
    _avatarUrlCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _resetControllers() {
    final p = widget.detail.profile;
    _firstnameCtrl.text = p.firstname ?? '';
    _lastnameCtrl.text = p.lastname ?? '';
    _locationCtrl.text = p.location ?? '';
    _websiteCtrl.text = p.website?.toString() ?? '';
    _linkedInCtrl.text = p.linkedIn?.toString() ?? '';
    _divisionCtrl.text = p.division ?? '';
    _departmentCtrl.text = p.department ?? '';
    _avatarUrlCtrl.text = _resolveAvatarUrl(p);
    _phoneCtrl.text = widget.detail.phoneNumber ?? '';
  }

  void _startEditing() => setState(() => _isEditing = true);

  void _cancelEditing() {
    _resetControllers();
    setState(() => _isEditing = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final avatarUrl = _avatarUrlCtrl.text.trim();
    final error = await ref
        .read(AccountSettingsViewModel.provider.notifier)
        .update(
          firstname: _firstnameCtrl.text.trim(),
          lastname: _lastnameCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          website: _websiteCtrl.text.trim(),
          linkedIn: _linkedInCtrl.text.trim(),
          division: _divisionCtrl.text.trim(),
          department: _departmentCtrl.text.trim(),
          avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
          phoneNumber: _phoneCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _isEditing = false;
    });
    if (error != null) {
      Toast.error(context, error);
    } else {
      Toast.success(context, 'Profile updated successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.detail.profile;
    final user = widget.detail.user;
    final name = [profile.firstname, profile.lastname]
        .where((s) => (s ?? '').trim().isNotEmpty)
        .join(' ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ProfileHeaderCard(
          name: name.isEmpty ? 'User' : name,
          email: user.email ?? '',
          profile: profile,
          isEditing: _isEditing,
          isSaving: _isSaving,
          firstnameController: _firstnameCtrl,
          lastnameController: _lastnameCtrl,
          avatarUrlController: _avatarUrlCtrl,
          onEdit: _startEditing,
          onCancel: _cancelEditing,
          onSave: _save,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.person_outline_rounded,
          title: 'Personal Details',
          children: [
            _FieldRow(
              label: 'Location',
              value: profile.location,
              controller: _isEditing ? _locationCtrl : null,
            ),
            _FieldRow(
              label: 'Website',
              value: profile.website?.toString(),
              controller: _isEditing ? _websiteCtrl : null,
            ),
            _FieldRow(
              label: 'LinkedIn',
              value: profile.linkedIn?.toString(),
              controller: _isEditing ? _linkedInCtrl : null,
            ),
            _FieldRow(
              label: 'Phone Number',
              value: widget.detail.phoneNumber,
              controller: _isEditing ? _phoneCtrl : null,
              keyboardType: TextInputType.phone,
            ),
            _ToggleRow(
              label: 'Receive Text Message Reminders',
              value: widget.detail.enableTextMessages,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.work_outline_rounded,
          title: 'Work Information',
          children: [
            _FieldRow(
              label: 'Division',
              value: profile.division,
              controller: _isEditing ? _divisionCtrl : null,
            ),
            _FieldRow(
              label: 'Department',
              value: profile.department,
              controller: _isEditing ? _departmentCtrl : null,
            ),
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
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const _ResetPasswordDialog(),
                ),
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
  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.profile,
    required this.isEditing,
    required this.isSaving,
    required this.firstnameController,
    required this.lastnameController,
    required this.avatarUrlController,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });
  final String name;
  final String email;
  final UserProfile profile;
  final bool isEditing;
  final bool isSaving;
  final TextEditingController firstnameController;
  final TextEditingController lastnameController;
  final TextEditingController avatarUrlController;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
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
              if (isEditing) ...[
                TextButton(
                  onPressed: isSaving ? null : onCancel,
                  style: TextButton.styleFrom(foregroundColor: _asMuted),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _asPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ] else
                ElevatedButton.icon(
                  onPressed: onEdit,
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
          if (isEditing)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: avatarUrlController,
              builder: (context, value, _) => _Avatar(url: value.text.trim()),
            )
          else
            _Avatar(url: _resolveAvatarUrl(profile)),
          const SizedBox(height: 14),
          if (isEditing) ...[
            if (Responsive.isTablet(context)) const _DesktopFieldLabel('First Name'),
            _EditableName(controller: firstnameController, hint: 'First name'),
            const SizedBox(height: 10),
            if (Responsive.isTablet(context)) const _DesktopFieldLabel('Last Name'),
            _EditableName(controller: lastnameController, hint: 'Last name'),
            const SizedBox(height: 10),
            if (Responsive.isTablet(context)) const _DesktopFieldLabel('Avatar URL'),
            TextField(
              controller: avatarUrlController,
              style: const TextStyle(color: _asInk, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Avatar image URL',
                prefixIcon: const Icon(Icons.image_outlined, size: 18, color: _asMuted),
                filled: true,
                fillColor: _asFieldBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ] else
            Text(name, style: const TextStyle(color: _asInk, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: _asMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _DesktopFieldLabel extends StatelessWidget {
  const _DesktopFieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: _asMuted, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final valid = url.startsWith('http');
    return CircleAvatar(
      radius: 44,
      backgroundColor: const Color(0xFF10121B),
      backgroundImage: valid ? NetworkImage(url) : null,
      onBackgroundImageError: valid ? (_, __) {} : null,
      child: valid ? null : const Icon(Icons.person, color: Colors.white, size: 40),
    );
  }
}

class _EditableName extends StatelessWidget {
  const _EditableName({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _asInk, fontWeight: FontWeight.w800, fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _asFieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog();

  @override
  ConsumerState<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPassword = _oldPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorText = 'All fields are required.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorText = 'New password and confirm password do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final error = await ref
        .read(AccountSettingsViewModel.provider.notifier)
        .changePassword(oldPassword: oldPassword, newPassword: newPassword);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorText = error;
      });
      return;
    }
    Navigator.of(context).pop();
    Toast.success(context, 'Password changed successfully.');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Reset Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _asInk, fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Positioned(
                  right: 0,
                  top: -4,
                  child: IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: _asMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PasswordField(label: 'Old Password', controller: _oldPasswordCtrl),
            const SizedBox(height: 14),
            _PasswordField(label: 'New Password', controller: _newPasswordCtrl),
            const SizedBox(height: 14),
            _PasswordField(label: 'Confirm Password', controller: _confirmPasswordCtrl),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _asPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(90, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Okay', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(90, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(color: _asInk, fontSize: 13, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: widget.label),
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          style: const TextStyle(color: _asInk, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: _asFieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: _asMuted,
              ),
            ),
          ),
        ),
      ],
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
  const _FieldRow({
    required this.label,
    this.value,
    this.controller,
    this.keyboardType,
  });
  final String label;
  final String? value;

  /// When set, this field is editable — a TextField is shown instead of the
  /// read-only box, bound to this controller.
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _asMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (controller != null)
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: _asInk, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Not provided',
              filled: true,
              fillColor: _asFieldBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _asFieldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              (value ?? '').trim().isNotEmpty ? value! : 'Not provided',
              style: TextStyle(
                color: (value ?? '').trim().isNotEmpty ? _asInk : _asMuted,
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
