import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';

const _purple = FigmaTokens.primaryPurple;
const _purpleHover = FigmaTokens.purpleHover;

/// "Confirm Your Mentor" modal shown on Dashboard load, matching
/// design_folder/app/App.tsx's showMentorModal dialog. Skip/Confirm both
/// just dismiss it for now - there's no backend endpoint yet to actually
/// submit the mentor details to (only the mentor_popup_month gating field
/// exists on the profile), so this is UI-only until that's wired up.
Future<void> showConfirmMentorModal(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: const Color(0x8DB4B9E6), // rgba(180,185,230,0.55)
    builder: (_) => const _ConfirmMentorDialog(),
  );
}

class _ConfirmMentorDialog extends StatefulWidget {
  const _ConfirmMentorDialog();

  @override
  State<_ConfirmMentorDialog> createState() => _ConfirmMentorDialogState();
}

class _ConfirmMentorDialogState extends State<_ConfirmMentorDialog> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirm Your Mentor',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF364153),
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _MentorField(label: 'First Name', controller: _firstNameCtrl),
                  const SizedBox(height: 16),
                  _MentorField(label: 'Last Name', controller: _lastNameCtrl),
                  const SizedBox(height: 16),
                  _MentorField(
                    label: 'Email',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: 'Note: ',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4A5565),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        TextSpan(
                          text: "We ask that you confirm your mentor's "
                              'information every three months. If the above '
                              'information is correct, click Confirm. You can '
                              "edit your mentor's information at anytime "
                              'through your profile.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6A7282),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 20 / 12,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6A7282),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ConfirmButton(onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: Color(0xFF99A1AF), size: 22),
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

class _MentorField extends StatelessWidget {
  const _MentorField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF364153),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 50,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(color: const Color(0xFF374151), fontSize: 15),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _purple),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hovering ? _purpleHover : _purple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          'Confirm',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
