# Mobile Responsiveness Conversion Plan
## Spinrise ERP V2 — Implementation Reference

**Status:** Pending — to be executed by Claude Code  
**Stack:** React 18 + TypeScript + Vite + Ant Design 5 + Zustand + React Router v7  
**Created:** 2026-06-02

---

## Phase 0 — Discovery & Assessment

Answer these before touching any code.

---

### 0-A: Baseline Architecture Questions

| # | Question | Why It Matters |
|---|---|---|
| A1 | What is your minimum supported screen width? (320px / 375px / 768px?) | Sets your CSS breakpoint floor |
| A2 | Are users expected to use the ERP on phones, or only tablets/desktop? | ERP on phones requires different interaction patterns than tablets |
| A3 | Do you have analytics showing current mobile traffic? | Tells you if users are already trying and failing, or if this is greenfield |
| A4 | Is the app deployed behind a corporate VPN / internal network only? | May restrict real-device testing options |
| A5 | Are there any pages/modules that are explicitly out-of-scope for mobile? | Scopes the effort |

**Key Ant Design 5 question:**

> **A6: Are you using Ant Design's Grid system (`<Row>/<Col>`)? Or custom CSS/flex layouts?**
> - If Grid: `xs/sm/md/lg/xl` breakpoint props are already available — mobile is a config change, not a rewrite.
> - If custom CSS: a systematic audit of every layout file is required.

---

### 0-B: Urgency Triage Framework

Score each major screen on these three axes (1–3 each):

```
User Frequency   : How often is this screen used daily?       (1=rarely, 3=daily)
Mobile Likelihood: How likely is a user to need this on mobile? (1=unlikely, 3=high)
Complexity       : How layout-complex is this screen?         (1=simple, 3=data-dense tables)

Priority Score = (User Frequency × Mobile Likelihood) — Complexity
```

Screens with the highest score = do first. Negative score = defer to last phase.

**Spinrise typical priority stack:**
1. Dashboard / Home (high frequency, low complexity)
2. List views — PR List, etc. (high frequency, data-dense)
3. Header + Navigation (blocks everything else if broken)
4. Detail/form views (moderate frequency, high complexity)
5. Print/PDF screens — **exclude, mobile-irrelevant**

---

### 0-C: Decision Gates (Must Decide Before Starting)

**Gate 1 — Breakpoint Strategy**
- [ ] Option A: Three-breakpoint (mobile ≤768, tablet 768–1024, desktop >1024)
- [ ] Option B: Two-breakpoint (mobile ≤1024, desktop >1024) — simpler for ERP
- [ ] Option C: Fluid/continuous — no hard breakpoints

*Recommended for ERP:* Option B. ERP mobile users are almost always on tablets.

**Gate 2 — Retrofit vs. Rebuild**
- [ ] Option A: Add responsive CSS to existing components (less disruption, slower result)
- [ ] Option B: Refactor layout components to use Ant Design Grid properly (cleaner, more upfront work)
- [ ] Option C: Hybrid — rebuild navigation/headers, retrofit tables and forms

*If using Ant Design 5 throughout:* Option B/C is preferred.

**Gate 3 — Table Strategy** (hardest problem in ERP mobile)
- [ ] Horizontal scroll (simplest, least mobile-friendly)
- [ ] Column hide/show at breakpoint (medium complexity — AntD Table supports this)
- [ ] Card view on mobile, table on desktop (highest effort, best UX)

> **Decision must be made once and applied consistently across all modules.**

---

## Phase 1 — Foundation (Prerequisite — Do First)

---

### 1-A: Viewport & Global CSS

- [ ] **1.1** Confirm `<meta name="viewport" content="width=device-width, initial-scale=1">` is in `index.html`
- [ ] **1.2** Audit global CSS for hardcoded `width: NNpx` on layout containers
- [ ] **1.3** Remove or override any `min-width` values preventing shrink below desktop
- [ ] **1.4** Set CSS custom properties for chosen breakpoints in one file

```css
/* Lock in after Gate 1 decision */
:root {
  --bp-mobile: 768px;
  --bp-tablet: 1024px;
}
```

> **Risk:** Ant Design 5 ships its own breakpoints (`xs: 0, sm: 576, md: 768, lg: 992, xl: 1200`).
> Team must use AntD breakpoints exclusively — mixing causes drift.

---

### 1-B: Navigation / Sidebar

- [ ] **1.5** Decide: Hamburger menu, bottom nav bar, or collapsible sidebar?
    - `<Layout.Sider breakpoint="lg" collapsedWidth="0">` handles this natively in Ant Design
- [ ] **1.6** Ensure topbar/header reflows on small screens (logo + user info + breadcrumb)
- [ ] **1.7** Decide if breadcrumb collapses to back-button on mobile (drives component changes)
- [ ] **1.8** Test navigation touch accessibility

---

### 1-C: Typography & Spacing

- [ ] **1.9** Confirm base font-size is `rem`-based, not `px`-based
- [ ] **1.10** Audit for fixed-height containers that clip text on small screens
- [ ] **1.11** All interactive elements: **minimum 44×44px touch target** (WCAG 2.5.5)
- [ ] **1.12** Input font-size ≥ 16px — below 16px triggers auto-zoom on iOS Safari

---

## Phase 2 — Layout Conversion (Screen by Screen)

Complete each screen fully before moving to the next.

---

### 2-A: Per-Screen Conversion Checklist

Run this for every screen in priority order:

```
Screen: ___________________________  Priority Score: ___

Layout
  [ ] Flex/Grid containers use responsive units (%, fr, auto-fill)
  [ ] No overflow-x on page body
  [ ] Columns stack vertically at mobile breakpoint

Forms
  [ ] Form fields full-width on mobile
  [ ] Labels above inputs (not inline) at mobile breakpoint
  [ ] Date pickers / dropdowns touch-friendly (minimum 44px height)
  [ ] Buttons full-width or appropriately grouped on mobile

Tables
  [ ] Gate 3 strategy selected and applied
  [ ] Pagination controls usable on touch

Modals / Drawers
  [ ] Width is 100% on mobile (not fixed px)
  [ ] Scroll works inside modal on iOS (known iOS overflow:scroll bug)

Actions / Buttons
  [ ] Action buttons accessible without horizontal scroll
  [ ] Sticky footer / floating action buttons considered for key actions
```

---

### 2-B: Spinrise Screen Sequencing

| Order | Screen / Component | Complexity | Gate 3 Needed? |
|---|---|---|---|
| 1 | App shell (header, nav, sidebar) | Medium | No |
| 2 | Dashboard / Home | Low | No |
| 3 | PR List view | High | Yes |
| 4 | PR Header form | High | No |
| 5 | PR Line items table | Very High | Yes |
| 6 | PR Print preview | **Skip — PDF only** | N/A |
| 7 | Approval screens | Medium | Yes |
| 8 | Security / admin screens | Low | No |

> **Parallel opportunity:** Items 3 and 4 can be worked simultaneously if devs agree on shared layout container width upfront.

---

## Phase 3 — Touch & Interaction Refinement

---

### 3-A: Touch Interactions

- [ ] **3.1** Replace hover-only interactions with tap-accessible alternatives
- [ ] **3.2** Audit drag-and-drop — does any exist? Is it needed on mobile?
- [ ] **3.3** Swipe gestures — decide scope explicitly (e.g., swipe to approve in list)
- [ ] **3.4** Form focus must not cause layout jump (iOS: font-size < 16px on inputs triggers zoom)

**Ant Design components known to have iOS Safari friction:**
- `Select` dropdown positioning
- `DatePicker` keyboard behaviour
- `Modal` scroll inside overlay

---

### 3-B: Performance

- [ ] **3.5** Lazy-load all route components — `React.lazy()` + React Router v7 (already mandated in CLAUDE.md)
- [ ] **3.6** Audit image/asset sizes — logos, icons served at full resolution?
- [ ] **3.7** Check bundle size: `npm run build -- --report` — flag chunks >200KB
- [ ] **3.8** API response time target: <500ms (per Spinrise quality standard)

---

## Phase 4 — Testing

---

### 4-A: Testing Layers

| Layer | Tool | What It Catches |
|---|---|---|
| Browser DevTools | Chrome / Edge responsive mode | Layout breakage, overflow |
| Real device | Android + iOS | Touch bugs, iOS Safari quirks, keyboard behaviour |
| Vitest | Unit tests with `window.innerWidth` mocks | Component render at mobile widths |
| Manual walkthrough | Real device | Workflow usability |

**Minimum test matrix:**

| Device Class | Screen Width | OS | Browser |
|---|---|---|---|
| Small phone | 375px | iOS | Safari |
| Large phone | 414px | Android | Chrome |
| Tablet | 768px | Android or iPad | Chrome / Safari |
| Desktop | 1440px | Windows | Chrome |

---

### 4-B: iOS-Specific Watch List

- [ ] `position: fixed` inside scrollable containers
- [ ] `overflow: scroll` inside modals — requires `-webkit-overflow-scrolling: touch`
- [ ] Input font-size < 16px — triggers automatic zoom
- [ ] `Select` dropdown positioning on small screens

---

## Phase 5 — Governance & Definition of Done

---

### 5-A: Definition of Done (per screen)

A screen is not "mobile done" until:

1. Renders without horizontal scroll at 375px width
2. All interactive elements meet 44×44px touch target
3. Forms usable with on-screen keyboard visible
4. Tested on at least one real iOS and one real Android device
5. No console errors on mobile browsers

---

### 5-B: Handoff Checklist

- [ ] Gate 1 breakpoint decision documented
- [ ] Gate 3 table strategy documented and consistent across all modules
- [ ] Shared responsive layout components catalogued (prevent per-screen reinvention)
- [ ] iOS-specific fixes documented

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Ant Design component quirks on iOS Safari | High | Medium | Test AntD components in isolation first |
| Hardcoded pixel widths in legacy screens | High | High | Run global CSS audit in Phase 1 before per-screen work |
| Table UX on mobile degrades business workflows | Medium | High | Get stakeholder sign-off on Gate 3 decision |
| Team diverges on breakpoints (custom vs AntD) | Medium | High | Lock approach in Phase 1; add lint rule if possible |
| No real devices available for testing | Medium | Medium | Use BrowserStack or iOS Simulator (Mac, free) |
| Performance regression from images / bundle size | Low | Medium | Baseline bundle size before starting; re-measure after Phase 3 |

---

## Execution Notes for Claude Code

When starting implementation, work in this order:

1. Read this document and confirm Gate 1, 2, and 3 decisions with the developer before writing any code.
2. Complete Phase 1 entirely before touching any individual screen.
3. Use Ant Design 5 responsive props (`xs/sm/md/lg` on `<Col>`, `breakpoint` on `<Layout.Sider>`) as the primary mechanism — avoid custom CSS breakpoints unless AntD cannot cover the case.
4. Update the per-screen checklist in this file as screens are completed.
5. Do not mark a screen done until the Definition of Done (5-A) is fully met.
