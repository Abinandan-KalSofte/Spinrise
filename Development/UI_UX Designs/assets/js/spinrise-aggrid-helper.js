/*
  SpinRise AG Grid Helper
  Thin wrapper over agGrid.createGrid() with project-standard defaults.
  Requires AG Grid Community v35 loaded from CDN before this script.

  Usage:
    const api = SpinRiseGrid.create('gridDivId', { columnDefs, rowData, onGridReady });

  Column cell class helpers (set via cellClass):
    'cell-num'   — centred, monospace (row numbers)
    'cell-mono'  — monospace bold (codes / IDs)
    'cell-right' — right-aligned (amounts / quantities)
*/
(function () {
  'use strict';

  var DEFAULT_COL = {
    sortable:        true,
    resizable:       true,
    filter:          true,
    suppressMovable: false,
  };

  var DEFAULT_OPTS = {
    defaultColDef:            DEFAULT_COL,
    rowSelection:             'multiple',
    suppressRowClickSelection: true,   // select via checkbox column only
    animateRows:              true,
    suppressCellFocus:        false,
    headerHeight:             34,
    rowHeight:                34,
    suppressPaginationPanel:  false,
    suppressScrollOnNewData:  true,
    tooltipShowDelay:         500,
    loadingOverlayComponent:  null,    // uses theme default
  };

  /* Merge two objects one level deep (does not deep-clone arrays). */
  function merge(base, user) {
    var result = {};
    var key;
    for (key in base) result[key] = base[key];
    for (key in user) result[key] = user[key];
    return result;
  }

  /**
   * Create an AG Grid instance.
   * @param {string} containerId  — id of the div element (no #)
   * @param {object} userOptions  — gridOptions overrides (columnDefs, rowData, callbacks…)
   * @returns {object|null}       — AG Grid API, or null if container not found
   */
  function create(containerId, userOptions) {
    var container = document.getElementById(containerId);
    if (!container) {
      console.warn('SpinRiseGrid.create: element #' + containerId + ' not found');
      return null;
    }

    var options = merge(DEFAULT_OPTS, userOptions || {});

    /* Merge defaultColDef separately so the caller can extend it. */
    options.defaultColDef = merge(DEFAULT_COL, (userOptions || {}).defaultColDef || {});

    return agGrid.createGrid(container, options);
  }

  /**
   * Build a standard serial-number column (always pinned left, non-sortable).
   * @param {number} [width=48]
   */
  function serialCol(width) {
    return {
      headerName:    '#',
      valueGetter:   'node.rowIndex + 1',
      width:         width || 48,
      pinned:        'left',
      sortable:      false,
      filter:        false,
      resizable:     false,
      suppressMovable: true,
      cellClass:     'cell-num',
    };
  }

  /**
   * Build a checkbox selection column (pinned left).
   */
  function checkboxCol() {
    return {
      headerName:          '',
      checkboxSelection:   true,
      headerCheckboxSelection: true,
      width:               38,
      pinned:              'left',
      sortable:            false,
      filter:              false,
      resizable:           false,
      suppressMovable:     true,
    };
  }

  window.SpinRiseGrid = {
    create:      create,
    serialCol:   serialCol,
    checkboxCol: checkboxCol,
  };
})();
