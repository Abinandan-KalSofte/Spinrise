(function () {
  'use strict';

  const routes = {
    hub: 'index.html',
    dashboard: 'index.html',
    pr: 'index.html',
    foreclosure: 'SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1_1/index.html',
    foreclosureLegacy: 'SPINRISE_FSD_M01_PRForeclosure_v1_1/SPINRISE_FSD_M01_PRForeclosure_v1_1.html',
    cancellation: 'SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1_1/index.html#cancellation',
    cancellationLegacy: 'SPINRISE_FSD_M01_PRCancellationUndo_v1_1/SPINRISE_FSD_M01_PRCancellationUndo_v1_1.html',
    amendment: 'SPINRISE_FSD_M01_PRAmendment_v2_3/SPINRISE_FSD_M01_PRAmendment_v2_3.html',
    'first-approval': 'SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1/SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1.html',
    PRFinalLevelApproval: 'SPINRISE_FSD_M01_PRFinalLevelApproval_v1_1/SPINRISE_FSD_M01_PRFinalLevelApproval_v1_2.html',
  };

  function depthPrefix() {
    const path = window.location.pathname.replace(/\\/g, '/');
    const marker = '/UI_UX%20Designs/';
    const markerPlain = '/UI_UX Designs/';
    let rel = path;
    if (path.includes(marker)) rel = path.split(marker)[1] || '';
    else if (path.includes(markerPlain)) rel = path.split(markerPlain)[1] || '';
    const depth = Math.max(0, rel.split('/').length - 1);
    return '../'.repeat(depth);
  }

  function route(target) {
    const href = routes[target] || routes.hub;
    return depthPrefix() + href;
  }

  function navigate(target) {
    if ((target === 'foreclosure' || target === 'cancellation') && document.getElementById('pane-' + target)) {
      document.querySelectorAll('.menu-item,.menu-solo').forEach((el) => el.classList.remove('active'));
      const navEl = document.getElementById(target === 'foreclosure' ? 'nav-foreclosure' : 'nav-cancellation');
      if (navEl) navEl.classList.add('active');
      document.querySelectorAll('.module-pane').forEach((pane) => pane.classList.remove('active'));
      document.getElementById('pane-' + target).classList.add('active');
      if (typeof window.activeModule !== 'undefined') window.activeModule = target;
      if (target === 'cancellation' && typeof window.openCancelModal === 'function' && !window.selectedCancelPR) {
        setTimeout(() => window.openCancelModal(), 120);
      }
      return;
    }
    window.location.href = route(target);
  }

  function escapeHtml(value) {
    if (value === null || value === undefined) return '';
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function setFormatted(el, parts) {
    if (!el) return;
    el.textContent = '';
    (parts || []).forEach((part) => {
      if (typeof part === 'string') {
        el.appendChild(document.createTextNode(part));
        return;
      }
      const node = document.createElement(part.tag || 'span');
      if (part.className) node.className = part.className;
      node.textContent = part.text || '';
      el.appendChild(node);
    });
  }

  function sanitizeConfirmHtml(html) {
    const template = document.createElement('template');
    template.innerHTML = String(html || '');
    const allowed = new Set(['STRONG', 'EM', 'BR', 'CODE', 'SPAN']);
    template.content.querySelectorAll('*').forEach((node) => {
      if (!allowed.has(node.tagName)) {
        node.replaceWith(document.createTextNode(node.textContent || ''));
        return;
      }
      Array.from(node.attributes).forEach((attr) => {
        if (attr.name !== 'class') node.removeAttribute(attr.name);
      });
    });
    return template.innerHTML;
  }

  function enhanceClickable(el) {
    if (!el || el.dataset.srEnhanced) return;
    el.dataset.srEnhanced = '1';
    if (!el.hasAttribute('role')) el.setAttribute('role', 'button');
    if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex', '0');
    el.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter' || ev.key === ' ') {
        ev.preventDefault();
        el.click();
      }
    });
  }

  function enhanceShell() {
    const sider = document.querySelector('.sider');
    const main = document.querySelector('.main-area');
    const page = document.querySelector('.page-content');
    const header = document.querySelector('.app-header');

    if (sider) {
      sider.setAttribute('role', 'navigation');
      sider.setAttribute('aria-label', 'SpinRise module navigation');
    }
    if (main && main.tagName !== 'MAIN') main.setAttribute('role', 'main');
    if (page && !page.hasAttribute('aria-label')) page.setAttribute('aria-label', 'Prototype workspace');
    if (header) header.setAttribute('role', 'banner');

    document
      .querySelectorAll('.menu-item,.menu-group,.menu-solo,.sider-logo,.hdr-user')
      .forEach(enhanceClickable);

    document.querySelectorAll('.overlay,.modal-backdrop,.confirm-overlay').forEach((overlay) => {
      overlay.setAttribute('aria-modal', 'true');
      overlay.setAttribute('role', 'dialog');
    });

    document.querySelectorAll('.modal-x').forEach((btn) => {
      if (!btn.getAttribute('aria-label')) btn.setAttribute('aria-label', 'Close dialog');
    });

    document.querySelectorAll('.fg').forEach((group) => {
      const label = group.querySelector('.fld-lbl');
      const control = group.querySelector('input,select,textarea');
      if (!label || !control) return;
      if (!control.id) control.id = 'sr-field-' + Math.random().toString(36).slice(2);
      if (label.tagName !== 'LABEL') {
        control.setAttribute('aria-label', label.textContent.replace('*', '').trim());
      }
    });
  }

  function closeTopDialog() {
    const visible = Array.from(document.querySelectorAll('.overlay,.modal-backdrop,.confirm-overlay'))
      .filter((el) => !el.classList.contains('hidden') && getComputedStyle(el).display !== 'none');
    const top = visible.pop();
    if (!top) return false;
    if (top.id && typeof window.closeOverlay === 'function') {
      window.closeOverlay(top.id);
    } else {
      top.classList.add('hidden');
    }
    return true;
  }

  function focusDialog(overlay) {
    if (!overlay || overlay.classList.contains('hidden')) return;
    const target = overlay.querySelector('button:not([disabled]), [href], input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])');
    if (target) setTimeout(() => target.focus(), 0);
  }

  function observeDialogs() {
    document.querySelectorAll('.overlay,.modal-backdrop,.confirm-overlay').forEach((overlay) => {
      const observer = new MutationObserver(() => focusDialog(overlay));
      observer.observe(overlay, { attributes:true, attributeFilter:['class', 'style'] });
    });
  }

  function installKeyboardSupport() {
    document.addEventListener('keydown', (ev) => {
      if (ev.key === 'Escape' && closeTopDialog()) ev.preventDefault();
    });
  }

  function patchRouteLinks() {
    document.querySelectorAll('[data-route]').forEach((el) => {
      const target = el.getAttribute('data-route');
      if (el.tagName === 'A') el.setAttribute('href', route(target));
      else {
        enhanceClickable(el);
        el.addEventListener('click', () => navigate(target));
      }
    });
  }

  window.SpinRiseProto = {
    routes,
    route,
    navigate,
    escapeHtml,
    sanitizeConfirmHtml,
    setFormatted,
    enhanceShell
  };
  window.navigate = navigate;

  document.addEventListener('DOMContentLoaded', () => {
    enhanceShell();
    patchRouteLinks();
    observeDialogs();
    installKeyboardSupport();
    const hashTarget = window.location.hash.replace('#', '');
    if (hashTarget === 'foreclosure' || hashTarget === 'cancellation') navigate(hashTarget);
  });
})();
