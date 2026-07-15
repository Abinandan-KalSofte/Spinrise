# Reports Module - Configuration-Driven Architecture

This module implements a reusable, configuration-driven report generation system that eliminates code duplication and makes adding new reports trivial.

## Architecture Overview

Instead of creating separate pages for each report, all reports now use a single unified `PeriodicReportPage` component that reads report definitions from a configuration file.

### Key Files

```
reports/
├── configs/
│   └── reportConfigs.ts           # Report definitions (add new reports here)
├── pages/
│   └── PeriodicReportPage.tsx      # Single unified report page
├── components/
│   ├── ReportModuleSelector.tsx    # Dropdown to switch between reports
│   ├── ReportTabs.tsx              # Dynamic tab renderer
│   ├── DynamicFilterRenderer.tsx    # Dynamic filter controls
│   ├── SummaryBar.tsx              # Summary KPI cards
│   └── ReportPreview.tsx           # Report preview panel
├── hooks/
│   └── useReport.ts                # Unified report logic
├── store/
│   └── useReportStore.ts           # Unified state management
├── api/
│   ├── poReportApi.ts              # Purchase Order report API
│   └── supplierApi.ts              # Supplier lookups
└── types/
    └── reportTypes.ts              # Shared type definitions
```

## How Reports Work

### 1. Report Configuration

Each report is defined in `reportConfigs.ts`:

```typescript
export const REPORT_CONFIGS: Record<string, ReportConfig> = {
  'pr-report': {
    id: 'pr-report',
    title: 'Purchase Requisition List',
    subtitle: 'Purchase Requisition',
    tabs: ['Datewise', 'Departmentwise', 'Itemwise'],
    defaultTab: 'Datewise',
    filters: {
      Datewise: [{ type: 'date', label: 'Date Range' }],
      Departmentwise: [
        { type: 'date', label: 'Date Range' },
        { type: 'department', label: 'Department Filter' },
      ],
      Itemwise: [
        { type: 'date', label: 'Date Range' },
        { type: 'item', label: 'Item Filter' },
      ],
      Supplierwise: [],
    },
    hints: {
      Datewise: 'Select a date range and click Generate Report...',
      Departmentwise: 'Select a date range and a Department...',
      Itemwise: 'Select a date range. Use All Items or choose specific items...',
      Supplierwise: '',
    },
    docBandTitle: 'Purchase Requisition Report',
    previewTitle: 'Purchase Requisition Report Preview',
    fetchBlob: fetchPrReportBlob,  // API function to fetch the PDF
    getFilename: (type, from, to) => `PRDatewise_${from}_${to}.pdf`,
  },
}
```

### 2. User Experience

**Left Panel (Filter Configuration):**
- Report Module Selector dropdown at the top
- Dynamic tabs based on report config
- Dynamic filter controls (date, department, item, supplier)
- Only relevant filters shown for selected tab

**Right Panel (Summary + Preview):**
- KPI summary bar (Date Range, Report Type, Selected Filters, Output Format)
- Report preview area (shows hint text and generation state)

**Toolbar:**
- Generate Report button (Alt+R keyboard shortcut)
- Exit button

### 3. State Management

The `useReportStore` Zustand store manages:
- Current report ID and selected tab
- Date range, selected department/items/supplier
- Lookup data (departments, items, suppliers)
- Preview state (blob URL, filename, loading)

### 4. Data Flow

```
ReportModuleSelector
    ↓ (onChange)
PeriodicReportPage (updates report ID in URL)
    ↓ (notifies)
useReport hook (reads route, initializes config)
    ↓ (fetches lookups)
useReportStore (loads departments, items, suppliers)
    ↓ (displays)
DynamicFilterRenderer (renders filters based on config)
    ↓ (user selects filters & clicks Generate)
handleGenerate in useReport
    ↓ (calls API)
config.fetchBlob(params)
    ↓ (returns blob)
ReportPreviewModal (opens PDF viewer)
```

## Adding a New Report

### Step 1: Implement Backend API

Create an API endpoint in your backend to generate the report PDF. It should accept parameters like:
- `divCode`: Division code
- `reportType`: Tab type (Datewise, Departmentwise, etc.)
- `fromDate`, `toDate`: Date range (YYYY-MM-DD)
- `depCode`: Department code (for Departmentwise)
- `itemCodes`: Array of item codes (for Itemwise)
- `supplierCode`: Supplier code (for Supplierwise)

### Step 2: Create API Function (if needed)

If your report needs a different API path or special handling, create an API file in `src/features/reports/api/`:

```typescript
// src/features/reports/api/myReportApi.ts
import api from '@/shared/api/client'
import type { DownloadReportParams } from '../../pr/types/prReportTypes'

const BASE = 'my-report'

export const fetchMyReportBlob = async (params: DownloadReportParams) => {
  const response = await api.get(`${BASE}/report/download?${buildQueryString(params)}`, {
    responseType: 'blob',
  })
  
  const blobUrl = URL.createObjectURL(new Blob([response.data], { type: 'application/pdf' }))
  const filename = `MyReport_${params.fromDate}_${params.toDate}.pdf`
  
  return { blobUrl, filename }
}
```

### Step 3: Add Report to Configuration

Add your report definition to `reportConfigs.ts`:

```typescript
import { fetchMyReportBlob } from '../api/myReportApi'

export const REPORT_CONFIGS: Record<string, ReportConfig> = {
  // ... existing reports ...
  
  'my-report': {
    id: 'my-report',
    title: 'My Custom Report',
    subtitle: 'My Report',
    tabs: ['Datewise', 'Departmentwise', 'Itemwise'],  // Define which tabs are available
    defaultTab: 'Datewise',
    filters: {
      Datewise: [{ type: 'date', label: 'Date Range' }],
      Departmentwise: [
        { type: 'date', label: 'Date Range' },
        { type: 'department', label: 'Department Filter' },
      ],
      Itemwise: [
        { type: 'date', label: 'Date Range' },
        { type: 'item', label: 'Item Filter' },
      ],
      Supplierwise: [],
    },
    hints: {
      Datewise: 'Select a date range...',
      Departmentwise: 'Select date range and department...',
      Itemwise: 'Select date range and items...',
      Supplierwise: '',
    },
    docBandTitle: 'My Custom Report',
    previewTitle: 'My Custom Report Preview',
    fetchBlob: fetchMyReportBlob,
    getFilename: (type, from, to) => `MyReport_${from}_${to}.pdf`,
  },
}
```

### Step 4: Add Navigation Link (Optional)

Update `src/shared/components/AppShell.tsx` to add a navigation item:

```typescript
mk('grp-reports', 'Reports', <FileExclamationOutlined />, [
  mk('grp-reports-pr', wrapLabel('Periodic Reports'), '', [
    mk('/pr-report', wrapLabel('Purchase Requisition List'), <FilePdfOutlined />),
    mk('/pending-pr-report', wrapLabel('Pending Purchase Requisition List'), <FilePdfOutlined />),
    mk('/my-report', wrapLabel('My Custom Report'), <FilePdfOutlined />),  // Add this
  ]),
]),
```

### Step 5: Update App.tsx Routing

Add the route to handle your report:

```typescript
const PeriodicReportPage = lazy(() => import('./features/reports/pages/PeriodicReportPage'))

// In router children:
{ path: '/my-report', element: <PeriodicReportPage /> },
```

Then update the route mapping in `PeriodicReportPage.tsx`:

```typescript
const ROUTE_TO_REPORT_ID: Record<string, string> = {
  '/pr-report': 'pr-report',
  '/pending-pr-report': 'pending-pr-report',
  '/periodic-report': 'pr-report',
  '/my-report': 'my-report',  // Add this
}
```

## Filter Types

The system supports these filter types:

- **date**: Date range (From Date / To Date) - always shown
- **department**: Department dropdown - shows "All Departments" option
- **item**: Item multi-select with "All Items" checkbox
- **supplier**: Supplier dropdown with "All Suppliers" checkbox

Define which filters appear for each tab in the report config's `filters` property.

## Existing Reports

### Purchase Requisition List (`pr-report`)
- **Route**: `/pr-report`
- **Tabs**: Datewise, Departmentwise, Itemwise
- **Filters**: Date range, Department (for Departmentwise), Items (for Itemwise)

### Pending Purchase Requisition List (`pending-pr-report`)
- **Route**: `/pending-pr-report`
- **Tabs**: Datewise, Departmentwise, Itemwise
- **Filters**: Date range, Department (for Departmentwise), Items (for Itemwise)

### Purchase Order List (`po-report`) - Configuration Ready
- **Route**: Not yet routed (can be added following the steps above)
- **Tabs**: Datewise, Departmentwise, Itemwise, Supplierwise
- **Filters**: Date range, Department, Items, Supplier

## Key Design Decisions

1. **Single Page, Multiple Reports**: One `PeriodicReportPage` handles all reports, reducing code duplication
2. **Configuration-Driven**: All report-specific logic (tabs, filters, APIs, filenames) is in `reportConfigs.ts`
3. **Dynamic Rendering**: Filters, tabs, and hints are rendered dynamically based on config
4. **Backward Compatible**: Old routes (`/pr-report`, `/pending-pr-report`) still work
5. **Extensible**: New reports can be added by just adding a config entry—no page creation needed

## Testing

To verify the refactored module works:

1. Navigate to `/pr-report` - Purchase Requisition List should load
2. Navigate to `/pending-pr-report` - Pending PR List should load
3. Switch between reports using the "Report Module" dropdown
4. Change report tabs - filters should update dynamically
5. Generate a report - PDF should open in preview modal

## Future Enhancements

- Add supplier lookup API and enable PO report route
- Add schedule/email report functionality
- Add saved report templates
- Add multi-report generation (batch)
