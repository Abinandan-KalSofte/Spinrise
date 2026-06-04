# PROMPT_02 — UI/UX HTML Blueprint Generation
**Use before building any new ERP screen or modal.**
Fill every `[PLACEHOLDER]` before sending. Remove unused OPTIONAL sections.

---

## Context load (send these @references first)

```
Read @CLAUDE.md for project memory and all coding rules.
Read @[FSD_filename.md or .docx] — §[section number] only.
Read @Development/spinrise-web/src/features/[feature]/types.ts
Read @Development/spinrise-web/src/features/[feature]/api/[name]Api.ts
```

---

## Task

You are my senior React + Ant Design 5 UI architect for Spinrise ERP V2.

**Module:** [MODULE NAME — e.g. M01 Purchase Requisition]
**Screen:** [Screen name — e.g. "PR Entry Form"]
**FSD reference:** §[x.x] — [Screen / Business Rule name]
**Blueprint file (if exists):** `Docs/Blueprints/[filename]`

Build this screen following the Spinrise frontend conventions below.

---

## Screen specification

### Layout

- **Page header:** Title + breadcrumb (`<PageHeader>` or `<Breadcrumb>` from Ant Design)
- **Form header section:** `<Form>` with `<Row>` / `<Col>` layout — [describe fields]
- **Line grid:** [describe columns, editable or read-only]
- **Action footer:** [Save / Submit / Cancel / Print — list required buttons]

### Fields (header)

| Field | Label | Type | Mandatory | Validation |
|---|---|---|---|---|
| [fieldName] | [Label] | [Input/Select/DatePicker/etc.] | [Y/N] | [Rule] |

### Grid columns

| Column | Label | Width | Editable | Format |
|---|---|---|---|---|
| [colName] | [Label] | [px or %] | [Y/N] | [text/number/date] |

### Decimal formats (non-negotiable)

| Type | Format |
|---|---|
| Qty | 3 decimal places |
| Rate | 4 decimal places |
| Value / Amount | 2 decimal places |

---

## Build rules

### Component structure

```
src/features/[feature]/
├── api/[name]Api.ts          — API calls only
├── components/[screen]/
│   ├── [Screen]Page.tsx      — route-level page shell
│   ├── [Screen]Header.tsx    — header form fields
│   ├── [Screen]LineGrid.tsx  — grid/table
│   └── [Screen]Footer.tsx    — action buttons (OPTIONAL)
├── store/[feature]Store.ts   — Zustand if state is cross-component
└── types.ts                  — all TypeScript types
```

### Styling rules

- Ant Design 5 components only — no raw HTML `<input>` or `<select>`
- Grid headers: use `ERP_TH` / `ERP_TD` from `@/shared/styles/erpTable`
  ```ts
  import { ERP_TH as TH, ERP_TD as TD, erpRowBg } from '@/shared/styles/erpTable'
  ```
- No inline `background: '#1e293b'` — that constant is in the shared style module
- Labels: **Title Case** — never ALL CAPS
- No inline styles for spacing that an Ant Design prop can handle
- No hardcoded colours outside of the shared style module

### State management

- Shared across components → Zustand store
- Component-only transient state → `useState`
- Auto-loading data (dropdowns, lookups) → `useApiQuery<T>` from `@/shared/hooks/useApiQuery`
- User-triggered actions (save, submit) → `useAsync` or manual `try/catch`

### Error handling

- Surface errors via `getErrorMessage()` from `@/shared/lib/errorHandler`
- Never `alert()` or `console.error()` as the only user feedback
- Loading states: show `<Spin>` or disable buttons, never leave the user with a frozen screen

### TypeScript

- Strict mode is ON — no `any`, no `!` non-null assertions without comment
- All API response types defined in `types.ts`
- Props interfaces named `[ComponentName]Props`

---

## OPTIONAL sections

### Lookup modals (include if screen has code lookups)

- Pattern: `[Entity]LookupModal.tsx` — see `MachineLookupModal.tsx` as reference
- Use `LOOKUP_TH` / `LOOKUP_TD` from `@/shared/styles/erpTable`
- `destroyOnClose` on `<Modal>` — remounts fresh each open
- Debounced search: 300ms timer on `onChange`
- Click = single-select highlight, double-click = immediate confirm

### Print button (include if screen has PDF print)

- Call `prApi.getPrint(...)` → opens `/api/[module]/print/[id]` in new tab or triggers download
- Do not embed PDF in the page — open in browser tab

---

## Hard rules (non-negotiable)

| Rule | Detail |
|---|---|
| No `any` | Strict TypeScript throughout |
| Shared table styles | Import from `@/shared/styles/erpTable` — never duplicate |
| Ant Design 5 only | No raw HTML form controls |
| Labels: Title Case | Never ALL CAPS, never lowercase |
| Decimal format | Qty=3dp, Rate=4dp, Value=2dp — use `toFixed()` or Ant `InputNumber` precision |
| No business logic in UI | Validation rules come from FSD — ask if unclear |
| `useApiQuery` for lookups | Never fetch inside `useEffect` manually when `useApiQuery` fits |
| No hardcoded IDs | Use props or store values |

---

## Self-check (output this table before finishing)

| Layer | Rule checked | PASS / FAIL |
|---|---|---|
| Component structure | Follows `src/features/[feature]/components/[screen]/` pattern | |
| TypeScript | No `any`, strict mode compliant | |
| Styles | Uses shared `ERP_TH`/`ERP_TD` (not local duplicates) | |
| Labels | All Title Case | |
| Decimal format | Qty=3dp, Rate=4dp, Value=2dp enforced | |
| Error handling | Uses `getErrorMessage()`, no silent failures | |
| State | Zustand for shared state, `useState` for local | |
| Types | All types in `types.ts`, not inline | |

Ask me ONE question if anything is unclear. Do not assume any business rule.
