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
  on-surface-variant: '#55433c'
  inverse-surface: '#342f2e'
  inverse-on-surface: '#f8efec'
  outline: '#88736a'
  outline-variant: '#dbc1b7'
  surface-tint: '#974721'
  primary: '#853a14'
  on-primary: '#ffffff'
  primary-container: '#a4512a'
  on-primary-container: '#ffe3d8'
  inverse-primary: '#ffb597'
  secondary: '#735c00'
  on-secondary: '#ffffff'
  secondary-container: '#fed65b'
  on-secondary-container: '#745c00'
  tertiary: '#005d30'
  on-tertiary: '#ffffff'
  tertiary-container: '#1a7743'
  on-tertiary-container: '#a2fcbb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbcd'
  primary-fixed-dim: '#ffb597'
  on-primary-fixed: '#360f00'
  on-primary-fixed-variant: '#79310b'
  secondary-fixed: '#ffe088'
  secondary-fixed-dim: '#e9c349'
  on-secondary-fixed: '#241a00'
  on-secondary-fixed-variant: '#574500'
  tertiary-fixed: '#9df6b6'
  tertiary-fixed-dim: '#81d99b'
  on-tertiary-fixed: '#00210d'
  on-tertiary-fixed-variant: '#00522a'
  background: '#fff8f6'
  on-background: '#1f1b1a'
  surface-variant: '#eae0de'
  surface-cream: '#FBF7F2'
  surface-card: '#FFFFFF'
  surface-tile: '#F3EAE1'
  border-hairline: '#EADED2'
  ink-secondary: '#6B5E57'
  ink-muted: '#8C7D73'
  terracotta-dark: '#7F3D1E'
  terracotta-light: '#F7E2D4'
  amber-baba: '#D97706'
  status-warning: '#8A5A00'
  status-danger: '#B3261E'
  info-assime: '#245C9E'
  read-receipt: '#53BDEB'
  dark-bg: '#1A1615'
  dark-surface: '#2A2320'
  dark-primary: '#E8A57C'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 26px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.005em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  caption-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  overline-xs:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

The design system establishes a warm, grounded, and dignified mobile aesthetic tailored for West Africa (Togo, Côte d'Ivoire, and regional neighbors). It balances Google Material 3 structural clarity with human warmth, avoiding folkloric clichés or superficial wax prints in favor of rich earth minerals, warm creams, sun-baked terracotta, and gold accents.

### Personality & Tone
- **Dignified & Reassuring:** Built around end-to-end cryptographic trust, verified identity, and financial neutrality (the application never touches money directly).
- **Direct & Grounded:** Communicates in clear, everyday language ("tu", wallet, tontine, coursier), avoiding technical obscurity. Every edge state has an immediate human explanation and an action.
- **Sunlight & Device Resilient:** Engineered for high legibility under harsh equatorial midday sun on entry-level hardware (2 GB RAM, modest GPU budgets) through deep typographic contrast and crisp contours.

### Movement & Influence
Tactile Modernism rooted in Material 3: soft pill actions, generous tap boundaries, lightweight multi-pass ambient shadows that perform smoothly without blur lag, and tactile micro-interactions that feel natural across both RTL (Arabic) and LTR languages.

## Colors

The palette adheres to a strict 60 / 30 / 10 compositional distribution to preserve clarity and visual calm:
- **60% Canvas & Neutral Ground:** `#FBF7F2` (fond crème) establishes an organic, glare-reducing foundation, supported by `#FFFFFF` for primary content cards and elevated surfaces.
- **30% Structure & Typographic Weight:** Deep soot `#1A1615` for primary text and headings, softened by `#6B5E57` (secondary metadata) and `#F3EAE1` (subtle tile surfaces, filters, pill backgrounds).
- **10% Brand Energy & Intent:** Primary terracotta `#A4512A` commands primary calls-to-action, active indicators, and brand surfaces. Deep terracotta `#7F3D1E` and tinted terracotta `#F7E2D4` provide responsive pressed and active container states.

### Semantic Intent & Prohibitions
- **Gold (`#D4AF37` / `#D97706`):** Dedicated exclusively to Pokou Certifié validation rings, verified trust badges, and the Baba AI assistant. Purple/violet is strictly forbidden for AI interfaces.
- **Success (`#1E7A46`):** Reserved for confirmed tontine payouts, delivered orders, and secure key verifications.
- **Read Cyan (`#53BDEB`):** Strictly isolated to double-check message delivery states (`✓✓`); never repurposed as generic decorative accent.
- **Color Independence:** In adherence to WCAG AA requirements, state shifts must never rely on color alone; every status combines chromatic tint with an icon and explicit copy.

## Typography

The typography relies on Inter, selected for its comprehensive Unicode support covering West African extended Latin glyphs (such as Éwé, Mina, and Kabiyè: `ɖ`, `ɛ`, `ƒ`, `ɣ`, `ŋ`, `ɔ`, `ʋ`). Arabic is matched via Noto Sans Arabic with equivalent weight proportions.

### Numeric & Currency Formatting
All monetary amounts (e.g., `75 000 FCFA`), countdown timers, and contribution tallies must utilize tabular figures (`tnum`) with a non-breaking thin space (`\u202F`) between numeric triplets and the currency symbol. The currency suffix is displayed in brand terracotta or muted ink to maintain clean scanability.

### Handling Text Overflow & Localized Copy
Because translations (English, Arabic, Russian, etc.) may expand text length by up to 30%, horizontal truncation is prohibited on core instructions. Text wraps naturally into available card height; action buttons switch to labeled icon configurations rather than truncating labels into ellipsis. Pure emoji messages (1 to 3 glyphs) scale dynamically from 32px up to 48px without text bubble borders.

## Layout & Spacing

The layout is built upon an 8-point base grid (subdivided into 4pt for micro-adjustments and icon alignment). Content margins conform strictly to 16px (`1rem`) on standard viewports (375pt to 390pt), scaling down safely to 320pt screens without content clipping.

### Mobile Ergonomics & Bottom Anchoring
All primary operational decisions, interactive buttons, modal triggers, and text inputs live within the bottom 35% of the viewport (the thumb-reach zone). The top app bar remains light and flat to preserve viewable content real estate.

### Spacing Step Rules
- `space-xs` (4px): Inner badge padding, micro-spacing between status checkmarks and time indicators.
- `space-sm` (8px): Gaps between chips, vertical stacking between title and subtitle lines, message bubble cluster margins.
- `space-md` (12px): Inner padding for compact tiles and input field interiors.
- `space-lg` (16px): Standard canvas screen margins, standard card body padding, gap between card sections.
- `space-xl` (24px): Structural separators between distinct screen modules (e.g., between Greeting Card and "Que veux-tu faire ?").

## Elevation & Depth

To preserve fluid 60fps rendering across entry-tier mobile hardware (2GB RAM chipsets common in regional markets), heavy gaussian blurs, backdrop filters, and heavy multi-stop drop shadows are prohibited.

### Tonal Layering System
Elevation is achieved primarily through warm surface contrast and thin structural separation lines rather than simulated atmospheric z-index:
- **Level 0 (App Canvas):** `#FBF7F2` (cream surface ground).
- **Level 1 (Default Card):** `#FFFFFF` surface with a subtle dual-pass low-spread ambient shadow:
  `box-shadow: 0 1px 2px rgba(44, 31, 24, 0.045), 0 8px 22px rgba(73, 50, 36, 0.055);`
  accompanied by a 1px hairline border `#EADED2` for bright outdoor sunlight contrast.
- **Level 2 (Brand Hero Card):** Gradient background (`#AD5A31` to `#8B4221`) elevated with a warm tinted shadow:
  `box-shadow: 0 12px 26px rgba(127, 61, 30, 0.20);`
- **Level 3 (Floating Action Button & Bottom Modals):**
  `box-shadow: 0 10px 24px rgba(127, 61, 30, 0.30);` for primary actions; modals feature top corner radii of 24px with a scrim overlay of `rgba(26, 22, 21, 0.40)`.
- **Level 4 (Message Bubbles):** Outgoing bubbles feature soft warm tint (`#F7E2D4` to `#FFFFFF`) with micro-shadow:
  `box-shadow: 0 3px 10px rgba(44, 31, 24, 0.055);`

## Shapes

The design system establishes a welcoming, organic geometry combining generous card curves with tactile pill actions:

- **Cards (Standard):** 18px corner radius (`1.125rem`). Balances friendly organic curvature with maximum usable internal surface area.
- **Greeting / Hero Cards:** 22px corner radius (`1.375rem`) to highlight the primary visual anchor on the home screen.
- **Internal Tuiles / Nested Modules:** 13px corner radius (`0.8125rem`) providing mathematical visual harmony nested inside parent 18px cards.
- **Message Bubbles:** 16px corner radius (`1rem`) on outer corners, with the attaching sender corner pinned down to a tight 4px radius.
- **Actions, Search & Inputs:** Full pill curvature (`radius: 9999px`) for all action buttons, chips, filter tabs, and text input containers.
- **Bottom Sheets:** 24px top-left and top-right corner radii, square bottom.
- **Avatars & Floating Triggers:** Full circular geometry (`circle`).

## Components

### Buttons & Interactive Touch Targets
- **Dimensions:** Minimum tap area is 44 × 44px regardless of visual size. Standard primary button height is 48px to 52px.
- **Primary Pill:** Background `#A4512A`, text `#FFFFFF` (14px, weight 600). Pressed state transitions to `#7F3D1E`.
- **Secondary Pill:** Background `#F3EAE1`, text `#1A1615`. Hover/pressed state shifts to `#EADED2`.
- **Certification/Action Accent:** Solid gold `#D4AF37` with `#1A1615` typography for verified mode triggers and Baba interactions.

### Inputs & Search Bars
- **Container:** Full pill radius (`9999px`), minimum height 48px, background `#FFFFFF` with hairline border `#EADED2`.
- **States:** Focused state displays a 1.5px border in `#A4512A` without loud outer glow rings. Error displays `#B3261E` border accompanied by an inline status label and icon.
- **Chat Input Bar:** Flat white bar floating above bottom navigation or keyboard dock; left icon trigger for attachments, expanding multiline text zone, right voice-note microphone pill transforming to terracotta send arrow on text input.

### Cards & Service Tiles (Kory, Honam, Assimé)
- **Structure:** 18px rounded white surface `#FFFFFF` with 16px internal padding.
- **Header Badge:** Overline label (11px, weight 700) paired with an earthy colored badge icon (cauris motif for Kory, prescription leaf for Honam, market stall for Assimé).
- **Direct Action:** Every card contains an integrated, high-affordance CTA button (e.g., "⊕ Créer une cagnotte") in the card footer to bypass intermediate routing screens.

### Bottom Navigation Bar
- **Surface:** Solid `#FFFFFF` background with a 1px `#EADED2` top boundary line. Elevation is flat to preserve performance.
- **Active State High-Sun Accessibility:** The active destination combines three distinct cues:
  1. 2px solid `#A4512A` indicator bar above the tab.
  2. Pill container background `#F7E2D4` around the active icon.
  3. Bold text label (12px, weight 700) in `#1A1615` (inactive tabs rest at `#8C7D73`).

### Avatars & Status Rings
- **Sizing:** 32px (App Bar), 44px (Home screen summary), 48px (Conversation lists), 72–96px (Profile and active call screens).
- **Fallback Rule:** When an avatar image is absent, generate a two-letter monogram on a warm tinted ground (`#F3EAE1` with `#7F3D1E` text). Never render blank anonymous silhouettes.
- **Status Ring:** Unseen stories/statuts render an exterior 2px copper ring `#A4512A` offset by 2px white gap.

### Informational Callouts & Badges
- **Structure:** Rounded container (13px radius) with light tinted background, leading icon, and single explanatory phrase.
- **Tonal Matrix:**
  - *Amber / Baba:* Background `#FEF3C7`, border `#FDE68A`, icon/text `#8A5A00`.
  - *Success / Confirmed:* Background `#DCFCE7`, border `#BBF7D0`, icon/text `#1E7A46`.
  - *Error / Irreversible:* Background `#FEE2E2`, border `#FECACA`, icon/text `#B3261E`.
  - *Info / Assimé:* Background `#E0F2FE`, border `#BAE6FD`, icon/text `#245C9E`.