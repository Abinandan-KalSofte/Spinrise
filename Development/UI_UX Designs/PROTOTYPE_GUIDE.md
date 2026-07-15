# SpinRise UI Prototype System

This folder contains static HTML/CSS/JS prototypes for SpinRise ERP Purchase Requisition workflows.

## Canonical Pages

- `index.html` is the prototype hub.
- `SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1_1/index.html` is the canonical Foreclosure + Cancellation + Undo prototype.
- `SPINRISE_FSD_M01_PRAmendment_v2_3/SPINRISE_FSD_M01_PRAmendment_v2_3.html` is the canonical Amendment prototype.
- `SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1/SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1.html` is the canonical First Level Approval prototype.
- `SPINRISE_FSD_M01_PRForeclosure_v1_1/...` and `SPINRISE_FSD_M01_PRCancellationUndo_v1_1/...` are retained as legacy standalone references.

## Shared Assets

- `assets/css/prototype-system.css` adds shared accessibility, responsive, modal, focus, and hub styles.
- `assets/js/prototype-system.js` adds shared route helpers, keyboard support, semantic enhancement, and safe HTML utilities.

## Creating A New Prototype

1. Copy the closest canonical module folder.
2. Keep module-specific CSS/JS inside that page until the pattern is reused by at least two pages.
3. Include the shared CSS in the page head:

   ```html
   <link rel="stylesheet" href="../assets/css/prototype-system.css">
   ```

4. Include the shared JS before the closing body tag:

   ```html
   <script src="../assets/js/prototype-system.js"></script>
   ```

5. Add the new route to `assets/js/prototype-system.js` and the hub cards in `index.html`.
6. Use real controls for interactions: `<button>` for commands, `<a>` for navigation, labels or `aria-label` for form inputs.
7. Escape dynamic data before writing it into `innerHTML`, or prefer `textContent` and DOM nodes.
8. Test at desktop, tablet, and mobile widths before sharing for review.
