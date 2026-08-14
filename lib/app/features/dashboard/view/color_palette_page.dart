import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';

const _purple = FigmaTokens.primaryPurple;
const _bg = FigmaTokens.pageBackground;

class _Swatch {
  const _Swatch(this.name, this.hex, {this.gradient});
  final String name;
  final String hex;
  final List<Color>? gradient;
}

class _SwatchGroup {
  const _SwatchGroup(this.label, this.swatches);
  final String label;
  final List<_Swatch> swatches;
}

// Design ref: design_folder/app/App.tsx's showColorSwatches view - the
// app's own internal design-token reference, not a user-facing feature.
const _groups = [
  _SwatchGroup('Primary Brand', [
    _Swatch('Primary Purple', '#693D94'),
    _Swatch('Purple Hover', '#5a3480'),
    _Swatch('Gradient End', '#aa399f'),
  ]),
  _SwatchGroup('Backgrounds', [
    _Swatch('Page Background', '#f4f5f7'),
    _Swatch('Card Background', '#ffffff'),
    _Swatch('Badge Background', '#f0e8f7'),
    _Swatch('Top Bar Navy', '#1a1a2e'),
    _Swatch('Avatar Pill', '#2d2d4a'),
    _Swatch('Row Hover', '#f8f8ff'),
    _Swatch('Image Placeholder', '#f3f4f6'),
    _Swatch('Button Background', '#f8fafc'),
    _Swatch('Active Nav (Mobile)', '#f5f5ff'),
  ]),
  _SwatchGroup('Text', [
    _Swatch('Card Titles', '#1e2939'),
    _Swatch('Modal Labels', '#364153'),
    _Swatch('Note Bold Text', '#4a5565'),
    _Swatch('Note Body Text', '#6a7282'),
    _Swatch('Close Button', '#99a1af'),
  ]),
  _SwatchGroup('Borders & Dividers', [
    _Swatch('Card Borders', '#e5e7eb'),
    _Swatch('Modal Input Borders', '#e5e7eb'),
  ]),
  _SwatchGroup('Status & Utility', [
    _Swatch('Overdue / Error', '#dc2626'),
    _Swatch('Overdue Hover', '#b91c1c'),
    _Swatch('Status Dots', '#ef4444'),
  ]),
  _SwatchGroup('Gradients', [
    _Swatch(
      'Hero & OLP Gradient',
      '#693d94 → #aa399f',
      gradient: [Color(0xFF693D94), Color(0xFFAA399F)],
    ),
  ]),
];

/// Internal design-token reference page - shows every color used across
/// the app's redesigned screens, matching design_folder/app/App.tsx's
/// "Color Palette" debug view. Not linked from primary nav; reachable from
/// Account Settings > Security for whoever needs to check a hex value.
class ColorPalettePage extends StatelessWidget {
  const ColorPalettePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: _bg,
      title: 'Color Palette',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => safePop(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 14, color: _purple),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: _purple,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 16, color: const Color(0xFFD1D5DB)),
              const SizedBox(width: 12),
              Text(
                'Color Palette',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1F2937),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          for (final group in _groups) ...[
            _GroupSection(group: group),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group});
  final _SwatchGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFF9CA3AF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 5
                : constraints.maxWidth >= 560
                    ? 3
                    : 2;
            const spacing = 16.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final swatch in group.swatches)
                  SizedBox(width: tileWidth, child: _SwatchTile(swatch: swatch)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({required this.swatch});
  final _Swatch swatch;

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: swatch.gradient == null ? _parseHex(swatch.hex) : null,
            gradient: swatch.gradient != null
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: swatch.gradient!,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          swatch.name,
          style: GoogleFonts.inter(
            color: const Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        Text(
          swatch.hex,
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF9CA3AF),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
