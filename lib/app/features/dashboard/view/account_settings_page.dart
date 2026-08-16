import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lms/app/core/data/countries.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/user_profile_detail.dart';
import 'package:lms/app/features/dashboard/viewmodel/account_settings_view_model.dart';

const _asPurple = FigmaTokens.primaryPurple;
const _asInk = FigmaTokens.cardTitles;
const _asMuted = FigmaTokens.noteBodyText;
const _asBg = FigmaTokens.pageBackground;
const _asFieldBg = Color(0xFFF4F6FA);

class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  ConsumerState<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  bool _redirectingUnauthorized = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(AccountSettingsViewModel.provider);

    if (!_redirectingUnauthorized &&
        state.state == DataProviderState.error &&
        isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    return AppScaffold(
      backgroundColor: _asBg,
      onRefresh: () => ref.read(AccountSettingsViewModel.provider.notifier).fetch(),
      body: switch (state.state) {
        DataProviderState.idle ||
        DataProviderState.loading =>
          const Center(child: CircularProgressIndicator(color: _asPurple)),
        DataProviderState.error => _redirectingUnauthorized
            ? const Center(child: CircularProgressIndicator(color: _asPurple))
            : _ErrorView(
                message: friendlyErrorMessage(state.error, 'Unable to load your profile.'),
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
              RetryButton(onRetry: onRetry!, errorMessage: message),
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
  bool _isUploadingAvatar = false;

  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _linkedInCtrl;
  late final TextEditingController _divisionCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _phoneCtrl;
  String? _countryCode;

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
    _phoneCtrl = TextEditingController(text: widget.detail.phoneNumber ?? '');
    _countryCode = p.countryCode?.toString();
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
    _phoneCtrl.text = widget.detail.phoneNumber ?? '';
    _countryCode = p.countryCode?.toString();
  }

  void _startEditing() => setState(() => _isEditing = true);

  void _cancelEditing() {
    _resetControllers();
    setState(() => _isEditing = false);
  }

  /// Shows the error as a toast, unless it indicates the session has
  /// expired - in that case redirect to login instead (these action
  /// results carry the raw exception message, not the same "friendly"
  /// conversion the initial page load's error state goes through, so they
  /// need their own unauthorized check here).
  void _showErrorOrRedirect(String error) {
    if (isUnauthorizedError(error)) {
      redirectToLoginOnSessionExpired(context, ref);
      return;
    }
    Toast.error(context, error);
  }

  /// Immediate upload (not part of the Edit/Save flow) via
  /// POST user-profile/upload-avatar - picking a photo replaces the avatar
  /// right away rather than staging it until Save is pressed.
  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _isUploadingAvatar = true);
    final bytes = await picked.readAsBytes();
    final error = await ref
        .read(AccountSettingsViewModel.provider.notifier)
        .uploadAvatar(bytes, picked.name);
    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);
    if (error != null) {
      _showErrorOrRedirect(error);
    } else {
      Toast.success(context, 'Avatar updated successfully.');
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
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
          phoneNumber: _phoneCtrl.text.trim(),
          countryCode: _countryCode,
        );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _isEditing = false;
    });
    if (error != null) {
      _showErrorOrRedirect(error);
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
    final notificationTypeSelection =
        (profile.notificationType?.toString() ?? '').toLowerCase();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Responsive.pageHPad(context),
        16,
        Responsive.pageHPad(context),
        32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
        const Text(
          'Account Settings',
          style: TextStyle(color: _asInk, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        _ProfileHeaderCard(
          name: name.isEmpty ? 'User' : name,
          email: user.email ?? '',
          profile: profile,
          isEditing: _isEditing,
          isSaving: _isSaving,
          firstnameController: _firstnameCtrl,
          lastnameController: _lastnameCtrl,
          isUploadingAvatar: _isUploadingAvatar,
          onPickAvatar: _pickAndUploadAvatar,
          onEdit: _startEditing,
          onCancel: _cancelEditing,
          onSave: _save,
        ),
        const SizedBox(height: 16),
        // ── Each section is its own bordered, rounded-corner box ───────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // ── Personal Details ──────────────────────────────────
              _SectionBlock(
                icon: Icons.person_outline_rounded,
                title: 'Personal Details',
                children: [
                  // Not yet returned by the profile API - shown as
                  // "Not provided" like Supervisor Name/Email below, ready
                  // to wire up once the backend exposes it.
                  const _FieldRow(label: 'State', value: null),
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
                  _PhoneFieldRow(
                    label: 'Phone Number',
                    value: widget.detail.phoneNumber,
                    controller: _isEditing ? _phoneCtrl : null,
                    countryCode: _countryCode,
                    onCountryChanged: _isEditing
                        ? (code) => setState(() => _countryCode = code)
                        : null,
                  ),
                  _ToggleRow(
                    label: 'Receive Text Message Reminders',
                    value: widget.detail.enableTextMessages,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Work Information ──────────────────────────────────
              _SectionBlock(
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
                  _FieldRow(label: 'Employee ID', value: user.employeeId?.toString()),
                  const _FieldRow(label: 'Supervisor Name', value: null),
                  const _FieldRow(label: 'Supervisor Email', value: null),
                ],
              ),
              const SizedBox(height: 16),
              // ── Preferences ───────────────────────────────────────
              _SectionBlock(
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
              // ── Primary Group ─────────────────────────────────────
              _SectionBlock(
                icon: Icons.groups_outlined,
                title: 'Primary Group',
                children: [
                  _SelectedChip(label: user.primaryGroupLabel ?? 'Not assigned'),
                ],
              ),
              const SizedBox(height: 16),
              // ── Notification Type ─────────────────────────────────
              _SectionBlock(
                icon: Icons.notifications_outlined,
                title: 'Notification Type',
                children: [
                  ..._notificationOptions.map((label) => _RadioRow(
                        label: label,
                        selected: notificationTypeSelection
                            .contains(label.split(' ').first.toLowerCase()),
                      )),
                  // The number that channel actually sends to - only shown
                  // once that channel is selected, matching the reference.
                  if (notificationTypeSelection.contains('text') ||
                      notificationTypeSelection.contains('sms'))
                    _PlainValueBox(value: profile.textPhoneNumber?.toString())
                  else if (notificationTypeSelection.contains('whatsapp'))
                    _PlainValueBox(value: profile.whatsappPhoneNumber?.toString()),
                ],
              ),
              const SizedBox(height: 16),
              // ── Security ──────────────────────────────────────────
              _SectionBlock(
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
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: const Text('Reset Password'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _asInk,
                        side: const BorderSide(
                            color: Color(0xFFD1D5DB), width: 1),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
    required this.isUploadingAvatar,
    required this.onPickAvatar,
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
  final bool isUploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Column(
        children: [
          // ── Top row: Profile label + Edit/Save/Cancel ─────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: _asPurple, size: 18),
              const SizedBox(width: 6),
              const Text('Profile',
                  style: TextStyle(
                      color: _asInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const Spacer(),
              if (isEditing) ...[
                TextButton(
                  onPressed: isSaving ? null : onCancel,
                  style: TextButton.styleFrom(foregroundColor: _asMuted),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                HoverBuilder(
                  builder: (context, hovering) => ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _asPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ] else
                HoverBuilder(
                  builder: (context, hovering) => ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _asPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Avatar left / name+email right ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with camera overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Avatar(url: profile.avatarUrl),
                  if (isUploadingAvatar)
                    const Positioned.fill(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.black45,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: _asPurple,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: isUploadingAvatar ? null : onPickAvatar,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Name + email (or edit fields)
              Expanded(
                child: isEditing
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('First Name'),
                          _EditableName(
                              controller: firstnameController,
                              hint: 'First name'),
                          const SizedBox(height: 10),
                          const _FieldLabel('Last Name'),
                          _EditableName(
                              controller: lastnameController,
                              hint: 'Last name'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: _asInk,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(email,
                              style: const TextStyle(
                                  color: _asMuted, fontSize: 13)),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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
      if (isUnauthorizedError(error)) {
        // Navigate first, while context is still valid - Modular.to.navigate
        // replaces the whole nav stack, which dismisses this dialog too.
        redirectToLoginOnSessionExpired(context, ref);
        return;
      }
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
                HoverBuilder(
                  builder: (context, hovering) => ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _asPurple,
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

// ─── Section block (used inside the single white card) ────────────────────────

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title row
          Row(
            children: [
              Icon(icon, size: 15, color: _asPurple),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _asInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fields
          ...List.generate(children.length * 2 - 1, (i) {
            if (i.isOdd) return const SizedBox(height: 14);
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
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label — fixed width, dark text, left side
        SizedBox(
          width: 160,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: _asInk,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Input — fills remaining space
        Expanded(
          child: controller != null
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                      color: _asInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Not provided',
                    hintStyle:
                        const TextStyle(color: _asMuted, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: Color(0xFFD1D5DB), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: Color(0xFFD1D5DB), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: _asPurple, width: 1.5),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFD1D5DB), width: 1),
                  ),
                  child: Text(
                    (value ?? '').trim().isNotEmpty
                        ? value!
                        : 'Not provided',
                    style: TextStyle(
                      color: (value ?? '').trim().isNotEmpty
                          ? _asInk
                          : _asMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Same layout as [_FieldRow], but for the phone number: while editing, a
/// country picker (flag + dial code) sits in front of the number field so
/// `country_code` and the number are captured separately, matching the
/// API's own `country_code` / `text_phone_number` split. Read-only mode
/// collapses that back down to a single "+<code> <number>" line instead of
/// showing the picker.
class _PhoneFieldRow extends StatelessWidget {
  const _PhoneFieldRow({
    required this.label,
    this.value,
    this.controller,
    this.countryCode,
    this.onCountryChanged,
  });

  final String label;
  final String? value;
  final TextEditingController? controller;
  final String? countryCode;
  final ValueChanged<String>? onCountryChanged;

  @override
  Widget build(BuildContext context) {
    final isEditing = controller != null;
    final country = countryForDialCode(countryCode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: _asInk,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isEditing
              ? Row(
                  children: [
                    _CountryCodePicker(
                      country: country,
                      onSelected: (c) => onCountryChanged?.call(c.dialCode),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                            color: _asInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Not provided',
                          hintStyle:
                              const TextStyle(color: _asMuted, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: _asPurple, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFD1D5DB), width: 1),
                  ),
                  child: Text(
                    (value ?? '').trim().isNotEmpty
                        ? [
                            if (country != null) '+${country.dialCode}',
                            value!.trim(),
                          ].join(' ')
                        : 'Not provided',
                    style: TextStyle(
                      color: (value ?? '').trim().isNotEmpty
                          ? _asInk
                          : _asMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The tappable "flag +code" button shown in front of the phone field while
/// editing - opens [_CountryPickerDialog] to change it.
class _CountryCodePicker extends StatelessWidget {
  const _CountryCodePicker({required this.country, required this.onSelected});

  final Country? country;
  final ValueChanged<Country> onSelected;

  Future<void> _open(BuildContext context) async {
    final selected = await showDialog<Country>(
      context: context,
      builder: (_) => const _CountryPickerDialog(),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              country?.flag ?? '🌐',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              country != null ? '+${country!.dialCode}' : 'Code',
              style: const TextStyle(
                  color: _asInk, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: _asMuted),
          ],
        ),
      ),
    );
  }
}

/// Searchable "Country / +dial code" list dialog, used by
/// [_CountryCodePicker].
class _CountryPickerDialog extends StatefulWidget {
  const _CountryPickerDialog();

  @override
  State<_CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<_CountryPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? kCountries
        : kCountries
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.dialCode.contains(query))
            .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select country',
                style: TextStyle(
                    color: _asInk, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Text('No matches',
                            style: TextStyle(color: _asMuted, fontSize: 13)),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final c = results[i];
                          return ListTile(
                            dense: true,
                            leading: Text(c.flag,
                                style: const TextStyle(fontSize: 18)),
                            title: Text(c.name,
                                style: const TextStyle(
                                    fontSize: 13, color: _asInk)),
                            trailing: Text('+${c.dialCode}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: _asMuted,
                                    fontWeight: FontWeight.w600)),
                            onTap: () => Navigator.of(context).pop(c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _asInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(sublabel!,
                      style:
                          const TextStyle(color: _asMuted, fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => Toast.info(context, 'Coming soon.'),
            activeColor: _asPurple,
          ),
        ],
      ),
    );
  }
}

/// Plain full-width value box with no label - used for the phone number
/// tied to the currently-selected notification channel (Text/WhatsApp).
class _PlainValueBox extends StatelessWidget {
  const _PlainValueBox({this.value});
  final String? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: Text(
        hasValue ? value! : 'Not provided',
        style: TextStyle(
          color: hasValue ? _asInk : _asMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _asPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _asPurple, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked, color: _asPurple, size: 17),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: _asPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? _asPurple.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? _asPurple : const Color(0xFFD1D5DB),
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? _asPurple : _asMuted,
            size: 17,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? _asPurple : _asInk,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
