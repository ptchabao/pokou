---
name: Terre de Confiance
colors:
  surface: '#fff8f6'
  surface-dim: '#e1d8d6'
  surface-bright: '#fff8f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fbf1ef'
  surface-container: '#f6ecea'
  surface-container-high: '#f0e6e4'
  surface-container-highest: '#eae0de'
  on-surface: '#1f1b1a'
  on-surface-variant: '#55433b'
  inverse-surface: '#342f2e'
  inverse-on-surface: '#f8efec'
  outline: '#887369'
  outline-variant: '#dac1b6'
  surface-tint: '#96491b'
  primary: '#873e11'
  on-primary: '#ffffff'
  primary-container: '#a65527'
  on-primary-container: '#ffe9e0'
  inverse-primary: '#ffb691'
  secondary: '#665d51'
  on-secondary: '#ffffff'
  secondary-container: '#ebdece'
  on-secondary-container: '#6a6155'
  tertiary: '#735c00'
  on-tertiary: '#ffffff'
  tertiary-container: '#cca72f'
  on-tertiary-container: '#4e3d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbcb'
  primary-fixed-dim: '#ffb691'
  on-primary-fixed: '#341100'
  on-primary-fixed-variant: '#773204'
  secondary-fixed: '#ede1d1'
  secondary-fixed-dim: '#d1c5b5'
  on-secondary-fixed: '#211b11'
  on-secondary-fixed-variant: '#4e463a'
  tertiary-fixed: '#ffe088'
  tertiary-fixed-dim: '#e9c349'
  on-tertiary-fixed: '#241a00'
  on-tertiary-fixed-variant: '#574500'
  background: '#fff8f6'
  on-background: '#1f1b1a'
  surface-variant: '#eae0de'
  brand-terracotta-100: '#F5DCCB'
  brand-terracotta-500: '#A65527'
  brand-terracotta-700: '#8A4520'
  brand-cuivre-500: '#B86D3B'
  brand-or-500: '#D4AF37'
  neutral-creme-50: '#FFF7EC'
  neutral-beige-100: '#F2E5D5'
  neutral-sable-200: '#E4D3BF'
  neutral-taupe-500: '#8C7D73'
  neutral-taupe-600: '#6B5E57'
  feedback-danger-500: '#B3261E'
  feedback-danger-50: '#FBE4E1'
  feedback-success-500: '#1E7A46'
  feedback-success-50: '#E3F2E8'
  feedback-warning-500: '#8A5A00'
  feedback-warning-50: '#FBF0D9'
  feedback-info-500: '#245C9E'
  feedback-info-50: '#E3ECF7'
typography:
  display:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.2px
  display-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.2px
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: 0px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: 0px
  title:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0px
  label-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  caption:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.2px
  overline:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.6px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

### Brand Personality & Core Identity
The brand personality is deeply grounded, protective, and culturally rooted in West African dignity and everyday craft. It merges contemporary mobile precision with organic warmth, invoking textures of sun-baked earth, polished brass, and woven textile fibers. The UI balances communal closeness with structural clarity, acting as a trusted digital companion for everyday communication, community funds, and healthcare delivery.

The target audience encompasses urban and peri-urban individuals, couriers, and health professionals navigating mobile-first environments. The emotional response sought is immediate reassurance, clarity under pressure, and a sense of shared belonging. Interfaces communicate integrity through unambiguous information hierarchy, high contrast, and tactile warmth.

### Design Movement: Warm Humanist Minimalism
The visual language rejects cold clinical grays and ungrounded tech abstraction in favor of a **Warm Humanist Minimalism**. 

1. **Substance Over Gloss:** Solid, earthy color planes replace translucent blurs and synthetic neon gradients. Every color choice reflects physical materials (terracotta clay, raw cream linen, polished ebony wood, and tempered copper).
2. **Accessible High Contrast (WCAG 2.2 AAA Target):** Contrast is never compromised for aesthetic softness. Critical structural text achieves over 7:1 contrast on canvas backgrounds, while interactive outlines and functional icons strictly exceed 3:1 contrast against surface layers.
3. **Intentional Geometry:** Form dictates trust. Structural cards employ gentle, stable radii (12px to 16px), while micro-actions and input pills embrace fully rounded organic contours (999px). Identity badges use distinct silhouettes (rosettes versus hexagons) so status is never conveyed by hue alone.

## Colors

### Hierarchy & Functional Assignment
The color palette creates intuitive spatial relationships through distinct material associations:

- **Primary (`#A65527` - Terracotta 500):** The primary interactive anchor. Used for primary CTA button fills, key navigation states, active toggles, and outgoing chat bubble backgrounds. Pressed states transition to Terracotta 700 (`#8A4520`) for clear physical feedback.
- **Secondary (`#F2E5D5` - Beige 100):** The primary container surface. It lifts modules, message cards, and section groupings off the warm canvas without relying on pure synthetic white or harsh dropshadows.
- **Tertiary (`#D4AF37` - Or 500):** The ceremonial and verified accent. Reserved strictly for non-text accents, professional certification markers (Pro hex badge accents), and dark-mode premium iconography. Never used for body text on light backgrounds due to contrast requirements.
- **Neutral (`#1A1615` - Ébène 900):** The visual grounding rod. Used for primary typography, resting state icons, high-emphasis UI structures, and deep shadows. Secondary neutral (`#6B5E57` - Taupe 600) handles metadata, subheadings, and secondary captions.
- **Canvas Base (`#FFF7EC` - Crème 50):** The baseline application foundation across the entire light theme.

### Accessibility & Contrast Rules
- **Color Independence:** Color is never the sole indicator of status. Error, warning, and success banners always pair distinct iconography with descriptive semantic copy. Certification badges enforce separate geometries (rosette for individuals, hexagon for verified professionals).
- **Legibility Guardrails:** Cuivre (`#B86D3B`) is restricted to large decorative headings, illustrations, and feature icons. Group participant colors must meet or exceed a minimum contrast ratio of 4.5:1 against card backgrounds (`#FFFFFF` and `#F2E5D5`). Form input borders (`#8C7D73`) guarantee a 3.1:1 ratio against light surfaces to satisfy WCAG 2.2 AA non-text contrast guidelines.

## Typography

### Structural Selection & Script Support
`Inter` is selected as the primary typographic engine. It guarantees comprehensive Unicode coverage for West African languages, rendering specialized phonetic glifs (`ɖ`, `ɛ`, `ƒ`, `ɣ`, `ŋ`, `ɔ`, `ʋ`), combining tonal accents, and narrow non-breaking spaces (`U+202F`) without clipping or unintended fallback behavior.

### Hierarchy & Scale Guidelines
- **Display (`32px` / Mobile `28px`):** Used strictly for high-impact onboarding banners and top-level screen titles.
- **Headlines (`24px` & `20px`):** Applied to primary screen headers, modal titles, and major category dividers.
- **Title (`17px`):** Serves as the primary card heading and structured list separator. Formatted in medium/semibold weight for rapid scanning.
- **Body (`16px` & `14px`):** Body-lg is calibrated to conversational speech bubbles and standard informational text blocks. Body-sm governs metadata descriptions, secondary instructions, and compact transactional records.
- **Labels & Overlines (`15px`, `12px`, `11px`):** High-density functional typography. Labels govern buttons and input field placeholders. Overlines provide category chips with uppercase tracking (`+0.6px`) to ensure distinct visual presence.

## Layout & Spacing

### Layout Philosophy & Mobile Reference
The design system prioritizes a handheld standard canvas of **390px × 844px** using a 4px spatial rhythm. Layouts use a fluid single-column structure for mobile viewports, evolving to multi-column arrangements on broader displays:

- **Vertical Layer Stack:** 
  1. *Top Bar (56px fixed):* Back navigation, screen identity, contextual actions.
  2. *Scroll Area:* Variable fluid content with a default 16px (`space-md`) horizontal canvas margin.
  3. *Bottom Action / Input Bar (52px to 64px fixed):* Persistent high-priority actions or messaging composer.
  4. *Tab Navigation (64px base):* Main module routing.
  5. *Bottom Sheet Overlay:* Modal interactions elevated above the active screen.

### Adaptive Density & Touch Guardrails
Interactive touch areas enforce a strict minimum target of **48px** on Android and **44px** on iOS (`size.touch-min`). Input elements adhere to a uniform height of 52px. Internal card spacing relies on `space-md` (16px) for breathable structural padding, while tight list-item arrangements use `space-sm` (8px).

## Elevation & Depth

### Tonal Layering & Warm Shadows
Visual hierarchy is articulated through physical tonal layering rather than sterile gray drop shadows. Base canvases (`#FFF7EC`) support resting surfaces (`#FFFFFF` or `#F2E5D5`), creating soft structural contrast.

Shadows are tinted directly using the brand's deepest neutral, Ébène 900 (`#1A1615`), generating warm ambient depth:

- **Level 1 (Resting Cards & Tiles):** `0px 1px 2px 0px rgba(26, 22, 21, 0.08)`. Provides crisp surface separation without raising elements off the plane.
- **Level 2 (Floating Action Bars & Popovers):** `0px 4px 12px 0px rgba(26, 22, 21, 0.10)`. Used for sticky headers, active dropdown menus, and scrolling quick-action panels.
- **Level 3 (Modal Sheets & Alert Banners):** `0px 8px 24px 0px rgba(26, 22, 21, 0.14)`. Applied to bottom sheets, dialog modals, and floating callout modules.

### Scrim & Overlay Directives
Modal sheets and critical system alerts implement a dark tinted backdrop scrim (`rgba(26, 22, 21, 0.50)`). This draws focus directly to the elevated sheet while signaling that background interactions are suspended.

## Shapes

### Structural Rounding & Pill Foundations
The shape language uses rounded surfaces to project hospitality, balanced by structured containment for transactional data:

- **Pill (Radius 999px):** Applied to primary and secondary interactive buttons, filter chips, input search pills, and floating notification badges. This communicates effortless interactivity and tactile responsiveness.
- **Containers & Cards (Radius 12px to 16px):** Form inputs and regular card surfaces use 12px (`radius.md`). Complex surfaces, chat message bubbles, and bottom sheets adopt 16px (`radius.lg`) to preserve interior space while softening exterior borders.
- **Large Hero Panels (Radius 20px):** High-priority containers (such as collective savings pot cards) feature a 20px radius (`radius.xl`), visually separating them from ordinary list items.

## Components

### Buttons
- **Primary Button:** Pill-shaped (999px), 48px height, solid Terracotta fill (`#A65527`), white text (`#FFFFFF`) in label-md semibold. Active/pressed state transitions to `#8A4520`. Focus states display a 2px offset border in Terracotta.
- **Secondary Button:** Pill-shaped, 48px height, transparent fill with a 1.5px border in Taupe 500 (`#8C7D73`), Ébène text (`#1A1615`).
- **Destructive Button:** Pill-shaped, solid Danger fill (`#B3261E`), white text. Reserved for permanent actions (cancellation, emergency dispatch, deletion).

### Chips & Filter Pills
- Compact 32px height, pill-shaped.
- **Default:** Neutral Beige surface (`#F2E5D5`), Taupe 600 text (`#6B5E57`), no border.
- **Selected:** Light Terracotta tint (`#F5DCCB`) with a 1px border in Terracotta 500 (`#A65527`), Ébène 900 text (`#1A1615`).

### Form Inputs & Text Fields
- Standard height of 52px with 12px rounded corners.
- Background uses pure White (`#FFFFFF`) set within the Cream canvas.
- Resting border uses 1px Taupe 500 (`#8C7D73`), exceeding 3:1 WCAG contrast against surfaces. Active focus transitions to a 2px Terracotta 500 ring (`#A65527`).
- Error states enforce a 1.5px Danger border (`#B3261E`) accompanied by a caption-level error message and icon below the input.

### Cards & Surface Containers
- **Standard Card:** 12px radius, pure White background (`#FFFFFF`), subtle border in Sable 200 (`#E4D3BF`), and Level 1 elevation shadow.
- **Secondary / Informational Card:** 12px radius, Beige 100 background (`#F2E5D5`), without borders or shadows.
- **Terracotta Highlight Card:** 16px to 20px radius, solid Terracotta fill (`#A65527`), white typography, Level 2 elevation. Used exclusively for collective pot targets and key emergency highlights.

### Chat Bubbles
- **Sent Bubble:** Terracotta 500 fill (`#A65527`), text and timestamps in solid 100% White (`#FFFFFF`). Radius 16px with the bottom-right corner tucked to 4px.
- **Received Bubble:** Pure White fill (`#FFFFFF`), Ébène 900 text (`#1A1615`), Taupe 600 timestamps (`#6B5E57`), Level 1 shadow. Radius 16px with the bottom-left corner tucked to 4px.
- **Proof/Strikethrough Bubbles:** Canceled or amended messages maintain an explicit strikethrough style (`~~texte~~`) with timestamp metadata and an accessible auditory state announcement.

### Verification Badges
- **Individual Verified:** Rosette shape in Terracotta 500 with a centered white checkmark.
- **Professional Verified:** Hexagon shape in Ébène 900 with a centered gold checkmark (`#D4AF37`) and subtle gold rim when rendered against dark surfaces.