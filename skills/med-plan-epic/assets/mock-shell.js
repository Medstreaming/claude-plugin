// Mockup shell: wraps <div id="content"> in the app layout (sidebar + header) using window.MOCK from mock-config.js.
// The markup mirrors the HIP2 Sentinel layout (_DashboardLayout.cshtml: .sidebar, .main-header, .main-content).
// For another app, change the class names here to match its layout. Static data only, no network.
(function () {
  var M = window.MOCK || {}, b = document.body, page = b.dataset.page || '';
  var app = M.app || {}, user = M.user || {}, ctx = M.context || {}, foot = M.footer || {};
  var links = (M.nav || []).map(function (n) {
    return '<a href="#" class="' + (n.id === page ? 'active' : '') + '"' + (n.child ? ' style="padding-left:34px;font-size:13px"' : '') + '>' +
      '<span class="nav-icon"><i class="bi ' + n.icon + '"></i></span><span>' + n.label + '</span>' +
      (n.badge ? '<span class="sidebar-badge">' + n.badge + '</span>' : '') + (n.isNew ? '<span class="mk-new">NEW</span>' : '') + '</a>';
  }).join('');
  var shell =
    '<aside class="sidebar"><div class="sidebar-brand"><div class="sidebar-brand-icon"><i class="bi ' + (app.icon || 'bi-app') + '"></i></div>' +
    '<div><h1>' + (app.name || '') + '</h1><small>' + (app.sub || '') + '</small></div></div><nav class="sidebar-nav">' + links + '</nav>' +
    '<div class="sidebar-footer"><div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;"><span class="status-dot"></span>' +
    '<strong style="font-size:12px;">' + (foot.title || '') + '</strong></div><div style="font-size:11px;opacity:0.6;">' + (foot.text || '') + '</div></div></aside>' +
    '<header class="main-header"><div class="header-left"><div class="header-title">' + (b.dataset.title || '') + '</div>' +
    '<div class="header-breadcrumb">' + (b.dataset.crumb || '') + '</div></div><div class="header-right">' +
    (ctx.label ? '<div class="env-selector" style="padding:6px 10px;"><span class="env-dot"></span> ' + ctx.label + ' <span style="font-size:11px;color:var(--gray-400);margin-left:6px;">' + (ctx.sub || '') + '</span></div>' : '') +
    (M.refreshed ? '<div class="header-timestamp"><i class="bi bi-clock"></i> Last Refresh: <span>' + M.refreshed + '</span></div>' : '') +
    '<button class="header-icon-btn"><i class="bi bi-arrow-clockwise"></i></button>' +
    '<button class="header-icon-btn"><i class="bi bi-bell"></i><span class="notif-badge">3</span></button>' +
    '<div class="header-user"><div class="header-user-info"><div class="header-user-name">' + (user.name || '') + '</div>' +
    '<div class="header-user-role">' + (b.dataset.role || user.role || '') + '</div></div><div class="header-avatar">' + (user.initials || '') + '</div></div>' +
    '</div></header><div class="mk-ribbon">MOCKUP · ' + (M.epic || '') + '</div>';
  var content = document.getElementById('content');
  b.insertAdjacentHTML('afterbegin', shell);
  var main = document.createElement('main');
  main.className = 'main-content';
  content.parentNode.insertBefore(main, content);
  main.appendChild(content);
})();

// Inline-SVG chart helpers, so mockups need no chart library.
function mkSpark(id, pts, color) {
  var el = document.getElementById(id); if (!el) return;
  var w = 160, h = 36, max = Math.max.apply(null, pts), min = Math.min.apply(null, pts), r = (max - min) || 1;
  var d = pts.map(function (p, i) { return (i ? 'L' : 'M') + (i * w / (pts.length - 1)).toFixed(1) + ' ' + (h - 3 - (p - min) / r * (h - 6)).toFixed(1); }).join(' ');
  el.innerHTML = '<svg viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none" style="width:100%;height:36px"><path d="' + d + '" fill="none" stroke="' + color + '" stroke-width="2"/></svg>';
}
// series: [{c:color, data:[...], fill:bool, bars:bool}]; opts: {h, max, labels:[...], bands:[{v, c, t}]}
function mkLines(id, series, opts) {
  var el = document.getElementById(id); if (!el) return;
  opts = opts || {};
  var W = 760, H = opts.h || 220, L = 40, B = 24, T = 10, R = 10, all = [];
  series.forEach(function (s) { all = all.concat(s.data); });
  var max = opts.max || Math.max.apply(null, all) * 1.1, n = series[0].data.length;
  function x(i) { return L + i * (W - L - R) / (n - 1); }
  function y(v) { return T + (H - T - B) * (1 - v / max); }
  var g = '';
  for (var k = 0; k <= 4; k++) { var v = max * k / 4; g += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y(v) + '" y2="' + y(v) + '" stroke="#eef0f3"/><text x="' + (L - 6) + '" y="' + (y(v) + 4) + '" font-size="10" text-anchor="end" fill="#9ca3af">' + Math.round(v) + '</text>'; }
  (opts.labels || []).forEach(function (t, i) { if (t) g += '<text x="' + x(i) + '" y="' + (H - 6) + '" font-size="10" text-anchor="middle" fill="#9ca3af">' + t + '</text>'; });
  (opts.bands || []).forEach(function (b2) { g += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y(b2.v) + '" y2="' + y(b2.v) + '" stroke="' + b2.c + '" stroke-dasharray="5 4"/><text x="' + (W - R - 2) + '" y="' + (y(b2.v) - 4) + '" font-size="10" text-anchor="end" fill="' + b2.c + '">' + b2.t + '</text>'; });
  series.forEach(function (s) {
    var d = s.data.map(function (v, i) { return (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + y(v).toFixed(1); }).join(' ');
    if (s.bars) {
      var bw = (W - L - R) / n * 0.6;
      s.data.forEach(function (v, i) { g += '<rect x="' + (x(i) - bw / 2) + '" y="' + y(v) + '" width="' + bw + '" height="' + (H - B - y(v)) + '" rx="2" fill="' + s.c + '" opacity="0.85"/>'; });
    } else {
      if (s.fill) g += '<path d="' + d + ' L' + x(n - 1) + ' ' + (H - B) + ' L' + L + ' ' + (H - B) + ' Z" fill="' + s.c + '" opacity="0.12"/>';
      g += '<path d="' + d + '" fill="none" stroke="' + s.c + '" stroke-width="2"/>';
    }
  });
  el.innerHTML = '<svg viewBox="0 0 ' + W + ' ' + H + '" style="width:100%;height:' + H + 'px">' + g + '</svg>';
}
function mkRing(id, value, max, color) {
  var el = document.getElementById(id); if (!el) return;
  var r = 42, c = 2 * Math.PI * r, f = Math.min(1, value / max);
  el.innerHTML = '<svg viewBox="0 0 100 100" style="width:110px;height:110px"><circle cx="50" cy="50" r="' + r + '" fill="none" stroke="#e5e7eb" stroke-width="9"/>' +
    '<circle cx="50" cy="50" r="' + r + '" fill="none" stroke="' + color + '" stroke-width="9" stroke-linecap="round" stroke-dasharray="' + (c * f) + ' ' + c + '" transform="rotate(-90 50 50)"/></svg>';
}
