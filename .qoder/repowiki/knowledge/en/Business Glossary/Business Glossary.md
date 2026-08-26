---
kind: business_term
name: Business Glossary
category: business_term
scope:
    - '**'
---

### Leadership Edge Live
- Definition：The product name of this Flutter LMS application, as declared in `pubspec.yaml` description and used throughout the codebase for branding and labeling.
- Aliases：LMS、lms

### ui-design branch
- Definition：The active Git branch on which UI enhancements are being developed to match a React/Tailwind reference prototype located under `src/`; commits on this branch progressively clone CSS styles (card radius/shadow tokens, section headings, filter panel) from the reference into Flutter widgets.
- Aliases：ui-design

### FigmaTokens
- Definition：Centralized design-token file (`lib/app/core/design/figma_tokens.dart`) that defines the app's color palette (primary purple #693D94, page bg #F4F5F7), typography (Inter/Roboto), spacing, shadows, and other visual constants consumed by feature screens.
- Aliases：design tokens、figma_tokens.dart

### CoursesPageV2
- Definition：The current entry-point widget for the course catalog screen; it delegates rendering to `CoursesPage` in `courses_page.dart` and is the target of ongoing pixel-perfect cloning against the CSS reference.
- Aliases：catalog page、course catalog

### virtual session
- Definition：A course session whose content is delivered via an in-app WebView (flutter_inappwebview) so that existing session/auto-login state carries over without handing off to the system browser.
- Aliases：Attend Class、in-app web session
