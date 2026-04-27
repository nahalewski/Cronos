# Design System Specification: The Desktop Native Experience

## 1. Overview & Creative North Star: "The Digital Curator"
This design system is not a collection of widgets; it is a philosophy of space. The **Creative North Star** for this system is **"The Digital Curator."** It treats the desktop application not as a webpage, but as a high-end physical gallery—where the interface recedes to allow the user’s content to take center stage. 

We break the "template" look by rejecting the rigid, boxy constraints of traditional web-based UI. Instead, we utilize **intentional asymmetry**, **glassmorphism**, and **tonal layering**. This approach moves away from a "grid of containers" toward an organic flow of information that feels native to macOS, yet elevated through bespoke editorial precision.

---

## 2. Colors & Surface Philosophy
The palette is built on a foundation of neutral sophistication, punctuated by a high-energy primary accent.

### Primary Palette
- **Primary (`#0058bc`)**: "Electric Cobalt." This is our primary engine for interaction.
- **Primary Container (`#0070eb`)**: Use for hover states or high-impact focal points.
- **Surface (`#f9f9fb`)**: The "Paper" layer. This is the base of the entire application.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section off the UI. Separation must be achieved through:
1.  **Background Shifts:** Placing a `surface-container-low` component against a `surface` background.
2.  **Negative Space:** Using the spacing scale to create clear mental groupings.
3.  **Tonal Transitions:** Subtle shifts in grey values to indicate a change in context.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of materials. 
- **Backdrop:** `surface-container-lowest` (#ffffff) for the most recessed areas.
- **Main Canvas:** `surface` (#f9f9fb).
- **Interactive Elements:** `surface-container` (#eeeef0).
- **Active/Focused Elements:** `surface-container-high` (#e8e8ea).

### The "Glass & Gradient" Rule
To achieve the macOS "Desktop" feel, use **Glassmorphism** for sidebars and floating panels. Apply a `surface` color at 70% opacity with a `backdrop-blur` of 20px. 
**Signature Texture:** Use a subtle linear gradient on primary CTAs—from `primary` (#0058bc) to `primary_container` (#0070eb)—at a 135-degree angle to provide "soul" and depth.

---

## 3. Typography: Editorial Authority
We use **Inter** (as a high-end alternative to SF Pro) to create a sense of refined utility.

- **Display (Display-LG: 3.5rem):** Reserved for "Moment" screens or empty states. High tracking (-0.02em) for a premium feel.
- **Headlines (Headline-SM: 1.5rem):** Used for view titles. These should sit with generous top-padding to let the layout breathe.
- **Body (Body-MD: 0.875rem):** The workhorse. Line height should be generous (1.5) to ensure high readability on high-density displays.
- **Labels (Label-MD: 0.75rem):** Use `on_surface_variant` (#414755) in all-caps with +0.05em letter spacing for metadata and headers.

---

## 4. Elevation & Depth
In this system, depth is a functional tool, not a stylistic flourish.

- **The Layering Principle:** Avoid shadows for static layout pieces. Achieve "lift" by stacking `surface-container-lowest` cards on `surface-container-low` sections. This creates a soft, natural distinction.
- **Ambient Shadows:** For floating menus or modals, use a "Cloud Shadow":
  - `box-shadow: 0 12px 40px rgba(26, 28, 29, 0.06);`
  - The shadow color is a tinted version of `on-surface` (#1a1c1d) at 6% opacity, mimicking natural light.
- **The "Ghost Border":** If a boundary is required for accessibility, use the `outline_variant` (#c1c6d7) at **15% opacity**. Never use 100% opaque borders.

---

## 5. Components

### Buttons
- **Primary:** Gradient fill (`primary` to `primary_container`), `rounded-md` (0.75rem), white text. No border.
- **Secondary:** `surface-container-highest` background with `on-surface` text. Feels "carved" into the UI.
- **Tertiary:** Ghost style. No background; `primary` text. Transitions to a 5% `primary` background on hover.

### Sidebars (Translucent)
The sidebar is the anchor of the app. It must use a semi-transparent `surface_container_low` with a 30px backdrop blur. It should never have a vertical divider line; it is separated from the main content by its translucency and a subtle tonal difference.

### Input Fields
- **Base:** `surface_container_lowest` background. 
- **States:** On focus, use a 2px "Ghost Border" of `primary` at 30% opacity. 
- **Error:** Background shifts to `error_container` (#ffdad6) with `error` (#ba1a1a) text.

### Cards & Lists
- **The Divider Ban:** Strictly forbid `<hr>` or border-bottom lines. 
- **Alternative:** Use 16px of vertical padding and a background shift to `surface_container_low` on hover to define the list item's hit area.

### Chips
- **Filter Chips:** `rounded-full`, using `surface_container_high`. When selected, they move to `primary` with `on_primary` text.

---

## 6. Do’s and Don’ts

### Do:
- **Do** use `xl` (1.5rem) rounded corners for large containers and `md` (0.75rem) for interactive components like buttons.
- **Do** allow the background color of the desktop to "bleed" through the sidebar via glassmorphism.
- **Do** use typography as the primary driver of hierarchy—scale and weight over color and lines.

### Don't:
- **Don't** use pure black (#000000). Use `on_surface` (#1a1c1d) for text to maintain a premium, ink-like softness.
- **Don't** use standard 4px "web" shadows. They look "cheap." Always use diffused, low-opacity ambient shadows.
- **Don't** use a divider between the navigation and the main content. The shift in surface material is the divider.

---

## 7. Interaction Note
All transitions (hover, active, focus) must use a **250ms "Ease-Out-Expo"** curve. This mimics the fluid, organic feel of macOS animations, ensuring the application feels responsive and high-end.