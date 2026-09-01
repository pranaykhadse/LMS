import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_flags/country_flags.dart';
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

class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
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
      onRefresh:
          () => ref.read(AccountSettingsViewModel.provider.notifier).fetch(),
      body: switch (state.state) {
        DataProviderState.idle || DataProviderState.loading => const Center(
          child: CircularProgressIndicator(color: _asPurple),
        ),
        DataProviderState.error =>
          _redirectingUnauthorized
              ? const Center(child: CircularProgressIndicator(color: _asPurple))
              : _ErrorView(
                message: friendlyErrorMessage(
                  state.error,
                  'Unable to load your profile.',
                ),
                onRetry:
                    () =>
                        ref
                            .read(AccountSettingsViewModel.provider.notifier)
                            .fetch(),
              ),
        DataProviderState.data =>
          state.data == null
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
            const Icon(Icons.error_outline, color: _asMuted, size: 44),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _asMuted, height: 1.5),
            ),
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
  ConsumerState<_AccountSettingsBody> createState() =>
      _AccountSettingsBodyState();
}

class _AccountSettingsBodyState extends ConsumerState<_AccountSettingsBody> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isSavingReminders = false;

  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _linkedInCtrl;
  late final TextEditingController _divisionCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _phoneCtrl;
  String? _countryCode;
  String? _countryIso;

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
    _countryIso = p.countryIso?.toString();
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
    _countryIso = p.countryIso?.toString();
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

  /// Immediate save (not part of the Edit/Save flow) - flips right away on
  /// toggle, same pattern as [_pickAndUploadAvatar].
  Future<void> _toggleTextReminders(bool value) async {
    if (_isSavingReminders) return;
    setState(() => _isSavingReminders = true);
    final error = await ref
        .read(AccountSettingsViewModel.provider.notifier)
        .setEnableTextMessages(value);
    if (!mounted) return;
    setState(() => _isSavingReminders = false);
    if (error != null) {
      _showErrorOrRedirect(error);
    } else {
      Toast.success(
        context,
        value
            ? 'Text message reminders enabled.'
            : 'Text message reminders disabled.',
      );
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
          countryIso: _countryIso,
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
    final name = [
      profile.firstname,
      profile.lastname,
    ].where((s) => (s ?? '').trim().isNotEmpty).join(' ');
    final notificationTypeSelection =
        (profile.notificationType?.toString() ?? '').toLowerCase();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Responsive.isTablet(context) ? 16 : 10,
        16,
        Responsive.isTablet(context) ? 16 : 10,
        32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Container(
              // CSS ref: .profile-block padding 24px desktop, 12px ≤768px.
              padding: EdgeInsets.all(Responsive.isTablet(context) ? 24 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title bar — matches .profile-title ──────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        // ≤540px: the edit/save buttons drop below the title
                        // (web: .profile-edit-btns { margin: 45px 0 10px auto; }).
                        final actions = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEditing) ...[
                              TextButton(
                                onPressed: _isSaving ? null : _cancelEditing,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B7280),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              HoverBuilder(
                                builder:
                                    (context, hovering) => ElevatedButton(
                                      onPressed: _isSaving ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            hovering
                                                ? FigmaTokens.purpleHover
                                                : _asPurple,
                                        foregroundColor: Colors.white,
                                        elevation: hovering ? 4 : 0,
                                        shadowColor: FigmaTokens.primaryPurple.withValues(alpha: 0.2),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: Responsive.isTablet(context) ? 16 : 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      child:
                                          _isSaving
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
                              ),
                            ] else
                              HoverBuilder(
                                builder:
                                    (context, hovering) => ElevatedButton.icon(
                                      onPressed: _startEditing,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 9,
                                      ),
                                      label: const Text('Edit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            hovering
                                                ? FigmaTokens.purpleHover
                                                : _asPurple,
                                        foregroundColor: Colors.white,
                                        elevation: hovering ? 4 : 0,
                                        shadowColor: FigmaTokens.primaryPurple.withValues(alpha: 0.2),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: Responsive.isTablet(context) ? 16 : 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                              ),
                          ],
                        );
                        final title = Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              color: _asPurple,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                                height: 1.2,
                              ),
                            ),
                          ],
                        );
                        // Web keeps Profile title + Edit/Save/Cancel on a single
                        // flex row (space-between) at every width — same here.
                        return Row(
                          children: [
                            title,
                            const Spacer(),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                      // ── Profile header ──────────────────────────────
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
                  // ── Each section is its own bordered, rounded-corner box
                  // (CSS: .personal-details — white, padding 15, radius 16,
                  // border #f3f4f6; blocks are flush, only the Primary Group
                  // carries an explicit 24px bottom margin) ──────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Personal Details ──────────────────────────────────
                      _SectionBlock(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Details',
                        spacing: 22.5,
                        children: [
                          // Not yet returned by the profile API - shown as
                          // "Not provided" like Supervisor Name/Email below, ready
                          // to wire up once the backend exposes it.
                          _FieldRow(label: 'State', value: null, isEditing: _isEditing),
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
                            countryIso: _countryIso,
                            onCountryChanged:
                                _isEditing
                                    ? (country) => setState(() {
                                      _countryCode = country.dialCode;
                                      _countryIso = country.iso2;
                                    })
                                    : null,
                          ),
                          _CheckboxRow(
                            label: 'Receive Text Message Reminders',
                            value: widget.detail.enableTextMessages,
                            onChanged:
                                _isSavingReminders ? null : _toggleTextReminders,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Work Information ──────────────────────────────────
                      _SectionBlock(
                        icon: Icons.work_rounded,
                        title: 'Work Information',
                        spacing: 22.5,
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
                          // CSS ref: real Work Information section is
                          // Division/Department/Cost Code/Supervisor Name/
                          // Supervisor Email only — "Employee ID" doesn't
                          // exist anywhere in `account.php`, removed.
                          _FieldRow(label: 'Cost Code', value: user.costCode, isEditing: _isEditing),
                          _FieldRow(
                            label: 'Supervisor Name',
                            value: null,
                            isEditing: _isEditing,
                          ),
                          _FieldRow(
                            label: 'Supervisor Email',
                            value: null,
                            isEditing: _isEditing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Preferences (Two-Factor Auth) ─────────────────
                      // CSS ref, confirmed against `origin/staging`'s
                      // sign-in/auth.php (rendered via
                      // `renderPartial('auth')` between Work Information
                      // and Primary Group in account.php — missed on an
                      // earlier pass because it lives in a separate
                      // partial file, not account.php itself, and was
                      // wrongly deleted as if invented; restored here).
                      _SectionBlock(
                        icon: Icons.tune_rounded,
                        title: 'Preferences',
                        children: [
                          _ToggleRow(
                            label: 'Two-Factor Auth',
                            sublabel: 'Add an extra layer of security',
                            value: user.enableTwoFactorAuth == 1,
                            boxed: true,
                            isEditing: _isEditing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Primary Group ─────────────────────────────────────
                      // Web: .personal-details style="margin-bottom: 24px;"
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: _SectionBlock(
                          icon: Icons.groups_rounded,
                          title: 'Primary Group',
                          children: [
                            // Web renders the user's groups as a full radio
                            // list (same .custom-radio look as Notification
                            // Type); our API only returns the primary one, so
                            // show it as the checked radio row.
                            _RadioRow(
                              label:
                                  user.primaryGroupLabel ?? 'Not assigned',
                              selected: user.primaryGroupLabel != null,
                            ),
                          ],
                        ),
                      ),
                      // ── Notification Type ─────────────────────────────────
                      _SectionBlock(
                        icon: Icons.notifications_rounded,
                        title: 'Notification Type',
                        // CSS: each .custom-radio has margin-bottom 12px
                        spacing: 12,
                        children: [
                          ..._notificationOptions.map(
                            (label) => _RadioRow(
                              label: label,
                              selected: notificationTypeSelection.contains(
                                label.split(' ').first.toLowerCase(),
                              ),
                            ),
                          ),
                          // The number that channel actually sends to - only shown
                          // once that channel is selected, matching the reference.
                          if (notificationTypeSelection.contains('text') ||
                              notificationTypeSelection.contains('sms'))
                            _PlainValueBox(
                              value: profile.textPhoneNumber?.toString(),
                              isEditing: _isEditing,
                            )
                          else if (notificationTypeSelection.contains(
                            'whatsapp',
                          ))
                            _PlainValueBox(
                              value: profile.whatsappPhoneNumber?.toString(),
                              isEditing: _isEditing,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Security ──────────────────────────────────────────
                      _SectionBlock(
                        icon: Icons.security_rounded,
                        title: 'Security',
                        children: [
                          // CSS ref: .reset-block h2 a — border #d1d5db, radius 12,
                          // padding 12, w500 #374151 14px, centered, white bg,
                          // box-shadow 0 1px 2px rgba(0,0,0,0.05);
                          // hover → bg #f9fafb, border #9ca3af.
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: HoverBuilder(
                              builder: (context, hovering) => SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => showDialog(
                                        context: context,
                                        builder:
                                            (_) => const _ResetPasswordDialog(),
                                      ),
                                  icon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                  label: const Text('Reset Password'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF374151),
                                    backgroundColor: hovering
                                        ? const Color(0xFFF9FAFB)
                                        : Colors.white,
                                    overlayColor: Colors.transparent,
                                    side: BorderSide(
                                      color: hovering
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFFD1D5DB),
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
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
        const SizedBox(height: 20),
        const AppFooter(),
      ],
    );
  }
}

const _notificationOptions = [
  'Email',
  'Slack',
  'Teams',
  'Text Message(SMS)',
  'WhatsApp',
];

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
    // CSS ref: .profile-header-container — flex, gap 30px,
    // padding 10px 0 30px 0, border-bottom 1px #f1f5f9, margin-bottom 30px.
    // ≤768px: flex-direction column, text-align center, gap 20px.
    final wide = Responsive.isTablet(context);
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        _Avatar(url: profile.avatarUrl),
        if (isUploadingAvatar)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (isEditing)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
child: HoverBuilder(
                    builder:
                        (context, hovering) => Material(
                          color: hovering
                              ? FigmaTokens.purpleHover
                              : _asPurple,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: isUploadingAvatar ? null : onPickAvatar,
                            customBorder: const CircleBorder(),
                            child: Transform.scale(
                              scale: hovering ? 1.1 : 1,
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                  ),
            ),
          ),
      ],
    );

    // Name + email — CSS ref: .profile-info-section flex:1, gap 12px.
    // Desktop: align-items flex-end. Mobile: centered (≤768px).
    // Edit mode mirrors the web's .name-inputs-combined (two boxed name
    // inputs, no labels) + .profile-email-row (boxed muted email, no label).
    final info = isEditing
        ? Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Stack the name boxes full-width when there isn't room for
                // the two side-by-side (web: .name-inputs-combined goes
                // column on ≤768px).
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EditableName(
                        controller: firstnameController,
                        hint: 'First name',
                      ),
                      const SizedBox(height: 10),
                      _EditableName(
                        controller: lastnameController,
                        hint: 'Last name',
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _EditableName(
                        controller: firstnameController,
                        hint: 'First name',
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _EditableName(
                        controller: lastnameController,
                        hint: 'Last name',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _EditableEmail(value: email),
          ],
        )
        : Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.center,
          children: [
            Text(
              name,
              textAlign: wide ? TextAlign.end : TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              email,
              textAlign: wide ? TextAlign.end : TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 10, bottom: wide ? 30 : 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      margin: const EdgeInsets.only(bottom: 30),
      // Desktop: avatar left, info right. Mobile: column, centered.
      child: wide
          ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(width: 30),
              Expanded(child: info),
            ],
          )
          : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: info,
              ),
            ],
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
    // CSS ref: .avatar-div — 110x110, bg #f9fafb, 2px dashed #d1d5db,
    // border-radius 50%. Flutter has no dashed border, so the ring is drawn
    // on top with a CustomPainter.
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child:
                  valid
                      ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF6B7280),
                            size: 52,
                          ),
                        ),
                      )
                      : const Center(
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF6B7280),
                          size: 52,
                        ),
                      ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DashedCirclePainter(
                  color: const Color(0xFFD1D5DB),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a dashed circular ring - used for the avatar's dashed border, which
/// Flutter cannot express with a plain [Border] (BorderStyle only knows
/// solid/none).
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final path = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _EditableName extends StatefulWidget {
  const _EditableName({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  State<_EditableName> createState() => _EditableNameState();
}

class _EditableNameState extends State<_EditableName> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .profile-heading-input — text-align center on mobile (≤768px).
    final centered = !Responsive.isTablet(context);
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // CSS ref: Course Catalog search input :focus — soft purple glow
          // ring outside the border (InputDecoration's border can't draw it).
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: const Color(0xFF5457C1).withValues(alpha: 0.1),
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: TextField(
          controller: widget.controller,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 20,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: _asMuted,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.5,
            ),
            filled: true,
            fillColor: Colors.white,
            hoverColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _asPurple, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableEmail extends StatelessWidget {
  const _EditableEmail({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .profile-email-input — smaller, muted, no label; bordered
    // white box in edit mode (the web keeps email readonly even when editing).
    final hasValue = value.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        hasValue ? value : 'Email/username',
        style: TextStyle(
          color: hasValue ? const Color(0xFF64748B) : _asMuted,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog();

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
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
      setState(
        () => _errorText = 'New password and confirm password do not match.',
      );
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
                  style: TextStyle(
                    color: _asInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: -4,
                  child: IconButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 16, color: _asMuted),
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
            _PasswordField(
              label: 'Confirm Password',
              controller: _confirmPasswordCtrl,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12.5, height: 1.5),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HoverBuilder(
                  builder:
                      (context, hovering) => ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hovering ? FigmaTokens.purpleHover : _asPurple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(90, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Okay',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                      ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(90, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
            children: [
              TextSpan(text: widget.label),
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5457C1).withValues(alpha: 0.1),
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              style: const TextStyle(color: _asInk, fontSize: 14, height: 1.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _asPurple, width: 1.5),
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 14,
                    color: _asMuted,
                  ),
                ),
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
    this.spacing = 15,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  // CSS: each .row / .custom-radio inside carries its own margin — 15px for
  // the detail rows (inline style), 12px for the notification radios.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .personal-details — white, radius 16, border #f3f4f6.
    // Desktop padding 15px; ≤768px padding 16px 20px.
    final sectionPadding = Responsive.isTablet(context)
        ? const EdgeInsets.all(15)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return Container(
      width: double.infinity,
      padding: sectionPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.translate(
                offset: const Offset(0, -0.5),
                child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...List.generate(children.length * 2 - 1, (i) {
            if (i.isOdd) return SizedBox(height: spacing);
            return children[i ~/ 2];
          }),
        ],
      ),
    );
  }
}

class _FieldRow extends StatefulWidget {
  const _FieldRow({
    required this.label,
    this.value,
    this.controller,
    this.isEditing = false,
  });
  final String label;
  final String? value;
  final TextEditingController? controller;
  // True while the page is in edit mode, so even rows we can't edit (State,
  // Cost Code, ...) render as white boxes next to the editable inputs
  // instead of grey read-only-looking ones. Grey is only for true
  // read-only (page not editing).
  final bool isEditing;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final labelText = Text(
      '${widget.label}:',
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
    final field =
        widget.controller != null
            ? Focus(
              onFocusChange: (focused) =>
                  setState(() => _focused = focused),
              child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: const Color(0xFF5457C1).withValues(alpha: 0.1),
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(
                  color: _asInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Not provided',
                  hintStyle: const TextStyle(color: _asMuted, fontSize: 15, height: 1.5),
                  filled: true,
                  fillColor: Colors.white,
                  hoverColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFD1D5DB),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFD1D5DB),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _asPurple, width: 1.5),
                  ),
                  suffixIcon: null,
                ),
              ),
            ),
            )
            : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isEditing ? Colors.white : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
              ),
              child: Text(
                (widget.value ?? '').trim().isNotEmpty ? widget.value! : 'Not provided',
                style: TextStyle(
                  color: (widget.value ?? '').trim().isNotEmpty ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            );

    // Phone (<700px): label above field, full-width - a fixed 160px label
    // leaves too little room for the input on a narrow screen.
    if (!Responsive.isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(left: 14), child: labelText),
          const SizedBox(height: 6),
          field,
        ],
      );
    }

    // Desktop: matches the web's Bootstrap col-md-6 / col-md-6 split - the
    // label occupies the left half (strong, vertically centred), the field
    // the right half. CSS ref: .personal-details strong { height:100% }.
    // The label column is nudged right by 8px (col's own left gutter).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: labelText,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: field),
      ],
    );
  }
}

/// Same layout as [_FieldRow], but for the phone number: while editing, a
/// country picker (flag + dial code) sits in front of the number field so
/// `country_code` and the number are captured separately, matching the
/// API's own `country_code` / `text_phone_number` split. Read-only mode
/// collapses that back down to a single "+1 555" line instead of
/// showing the picker.
class _PhoneFieldRow extends StatefulWidget {
  const _PhoneFieldRow({
    required this.label,
    this.value,
    this.controller,
    this.countryCode,
    this.countryIso,
    this.onCountryChanged,
  });

  final String label;
  final String? value;
  final TextEditingController? controller;
  final String? countryCode;
  final String? countryIso;
  final ValueChanged<Country>? onCountryChanged;

  @override
  State<_PhoneFieldRow> createState() => _PhoneFieldRowState();
}

class _PhoneFieldRowState extends State<_PhoneFieldRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final isEditing = widget.controller != null;
    // countryIso is unambiguous; countryCode (dial code) alone is not -
    // many countries share one (every NANP country is "+1"), so it's only
    // a fallback for when no iso2 is known yet.
    final country =
        countryForIso2(widget.countryIso) ?? countryForDialCode(widget.countryCode);

    final labelText = Text(
      '${widget.label}:',
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
    final field =
        isEditing
            ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _CountryCodePicker(
                    country: country,
                    onSelected: (c) => widget.onCountryChanged?.call(c),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onFocusChange: (focused) =>
                          setState(() => _focused = focused),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _focused
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF5457C1).withValues(alpha: 0.1),
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: TextField(
                          controller: widget.controller,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: _asInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Not provided',
                            hintStyle: const TextStyle(color: _asMuted, fontSize: 15, height: 1.5),
                            filled: true,
                            fillColor: Colors.white,
                            hoverColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: _asPurple,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
            : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
              ),
              child: Row(
                children: [
                  if (country != null && (widget.value ?? '').trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CountryFlag.fromCountryCode(
                        country.iso2,
                        height: 14,
                        width: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    (widget.value ?? '').trim().isNotEmpty
                        ? [
                          if (country != null) '+${country.dialCode}',
                          widget.value!.trim(),
                        ].join(' ')
                        : 'Not provided',
                    style: TextStyle(
                      color:
                          (widget.value ?? '').trim().isNotEmpty ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );

    if (!Responsive.isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(left: 14), child: labelText),
          const SizedBox(height: 6),
          field,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: labelText,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: field),
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
    return HoverBuilder(
      builder: (context, hovering) => InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hovering ? _asPurple : const Color(0xFFD1D5DB),
              width: hovering ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              country != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: CountryFlag.fromCountryCode(
                      country!.iso2,
                      height: 14,
                      width: 20,
                    ),
                  )
                  : const Icon(Icons.public_rounded, size: 12, color: _asMuted),
              const SizedBox(width: 6),
              Text(
                country != null ? '+${country!.dialCode}' : 'Code',
                style: const TextStyle(
                  color: _asInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 12,
                color: _asMuted,
              ),
            ],
          ),
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
  bool _searchFocused = true;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results =
        query.isEmpty
            ? kCountries
            : kCountries
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(query) ||
                      c.dialCode.contains(query),
                )
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
                  color: _asInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Focus(
                onFocusChange: (focused) =>
                    setState(() => _searchFocused = focused),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _searchFocused
                        ? [
                            BoxShadow(
                              color: const Color(0xFF5457C1).withValues(alpha: 0.1),
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Search country or code',
                      prefixIcon: const Icon(Icons.search, size: 14),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      hoverColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _asPurple, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    results.isEmpty
                        ? const Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: _asMuted, fontSize: 13, height: 1.5),
                          ),
                        )
                        : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final c = results[i];
                            return ListTile(
                              dense: true,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: CountryFlag.fromCountryCode(
                                  c.iso2,
                                  height: 16,
                                  width: 22,
                                ),
                              ),
                              title: Text(
                                c.name,
style: const TextStyle(
                  fontSize: 13,
                  color: _asInk,
                  height: 1.5,
                ),
                              ),
                              trailing: Text(
                                '+${c.dialCode}',
style: const TextStyle(
                  fontSize: 13,
                  color: _asMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                              ),
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

/// Plain checkbox row for "Receive Text Message Reminders" - the web renders
/// it as a raw `<input type="checkbox" class="my-checkbox">` (Bootstrap
/// checkbox), distinct from the custom switch used for Two-Factor Auth.
class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      '$label:',
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
    final control = Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
          activeColor: _asPurple,
          checkColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
        ),
      ],
    );
    if (!Responsive.isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 14), child: labelText),
          const SizedBox(height: 6),
          control,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: labelText,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: control),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    this.sublabel,
    required this.value,
    this.boxed = false,
    this.isEditing = false,
  });
  final String label;
  final String? sublabel;
  final bool value;
  final bool boxed;
  // White while the page is being edited; grey only in read-only mode.
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: boxed ? 16 : 0, vertical: boxed ? 12 : 4),
      decoration: BoxDecoration(
        color: boxed
            ? (isEditing ? Colors.white : const Color(0xFFF9FAFB))
            : Colors.white,
        borderRadius: BorderRadius.circular(boxed ? 12 : 10),
        border: boxed ? Border.all(color: const Color(0xFFE5E7EB)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: boxed ? const Color(0xFF111827) : _asInk,
                    fontWeight: FontWeight.w600,
                    fontSize: boxed ? 15 : 15,
                    height: 1.5,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: TextStyle(
                      color: boxed ? const Color(0xFF6B7280) : _asMuted,
                      fontSize: boxed ? 13 : 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => Toast.info(context, 'Coming soon.'),
            activeThumbColor: Colors.white,
            activeTrackColor: _asPurple,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }
}

/// Plain full-width value box with no label - used for the phone number
/// tied to the currently-selected notification channel (Text/WhatsApp).
class _PlainValueBox extends StatelessWidget {
  const _PlainValueBox({this.value, this.isEditing = false});
  final String? value;
  // White while the page is being edited (matches the editable inputs);
  // grey only in true read-only mode.
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isEditing ? Colors.white : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: Text(
        hasValue ? value! : 'Not provided',
        style: TextStyle(
          color: hasValue ? _asInk : _asMuted,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
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
    // CSS ref: .custom-radio — bg #fff, border 1px #e2e8f0, radius 12px,
    // padding 14px 20px; :checked → bg #f5f3ff, border #5c52d4.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF5F3FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _asPurple : const Color(0xFFE2E8F0),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _asPurple,
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? _asPurple : _asMuted,
            size: 16,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: selected ? _asPurple : const Color(0xFF334155),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
