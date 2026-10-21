// Mockup configuration: copy to <repo>\Task_<id>\mockups\mock-config.js and edit.
// Read by mock-shell.js (sidebar + header around each page) and index.html (tabbed viewer).
window.MOCK = {
  epic: 'Epic 00000',
  title: 'Feature name · UI Mockups',
  plan: '../PLAN_Task_00000_Feature_Name.html',          // link from the viewer header
  app: { name: 'Sentinel', sub: 'by MedStreaming', icon: 'bi-heart-pulse' },
  user: { name: 'Support Engineer', initials: 'SE', role: 'Support (RunRules)' },  // a page can override the role with data-role
  context: { label: 'PACS-PROD-01', sub: 'Customer: demo' },
  refreshed: '15 Oct 2026 10:42:18 AM',
  footer: { title: 'System Status', text: 'All systems operational' },
  // Sidebar. id must match <body data-page="...">; child:true indents; isNew shows a NEW pill; badge shows a count.
  nav: [
    { id: 'Dashboard', icon: 'bi-grid-1x2', label: 'Overview' },
    { id: 'Feature', icon: 'bi-diagram-3', label: 'Feature', badge: 2 },
    { id: 'FeatureDetail', icon: 'bi-list-check', label: 'Feature detail', child: true, isNew: true },
    { id: 'Alerts', icon: 'bi-bell', label: 'Alerts', badge: 3 }
  ],
  // Viewer tabs, in order.
  pages: [
    { file: '01-dashboard.html', name: 'Overview dashboard', meta: 'entry point', req: 'R1 · R2',
      desc: '<b>Overview</b> with the new cards and their states.' },
    { file: '02-main.html', name: 'Main page', meta: 'table · chart', req: 'R3',
      desc: '<b>Main page</b> description.' }
  ]
};
