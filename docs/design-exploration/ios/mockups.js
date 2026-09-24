// Static design fixtures: these compositions illustrate the iOS specification.
const icon = (name, extra = '') => `<span class="icon ${extra}" style="--symbol:url('symbols/${name}.png')" aria-hidden="true"></span>`;
const status = () => `<div class="statusbar"><span>9:41</span><div class="island"></div><div class="status-icons">${icon('signal')}${icon('wifi')}${icon('battery', 'battery')}</div></div>`;
const home = () => '<div class="home-indicator"></div>';
const tabbar = (active) => `<div class="tabbar">${[['sun', 'Today'], ['inbox', 'Inbox'], ['browse', 'Browse'], ['search', 'Search']].map(([symbol, label]) => `<div class="tab ${label === active ? 'active' : ''}">${icon(symbol)}<span>${label}</span></div>`).join('')}</div>${home()}`;
const circle = (priority = '') => `<span class="completion ${priority}">${priority === 'completed' ? icon('check') : ''}</span>`;
const toolbar = () => `<div class="toolbar"><span class="vault-label">${icon('cloud')} Personal</span><span class="spacer"></span><span class="icon-control">${icon('options')}</span><span class="icon-control"><span class="add-control">${icon('plus')}</span></span></div>`;
const task = (title, meta = '', priority = '', extra = '') => `<div class="task-row ${extra}">${circle(priority)}<div class="task-copy"><div class="task-title ${priority === 'completed' ? 'done-copy' : ''}">${title}</div>${meta ? `<div class="task-meta">${meta}</div>` : ''}</div></div>`;
const heading = (name, count) => `<div class="group-heading">${icon('folder')} ${name}<span class="count">${count}</span></div>`;
function todayContent(selected = false) {
  return `<div class="task-group">${heading('Autumn launch', '3')}
    ${task('Send the design proposal', `<span class="overdue">${icon('warning')} Overdue · Yesterday</span><span class="gap"></span><span>P1</span>`, 'p1')}
    ${task('Review the launch checklist', `${icon('calendar')} Due Fri, 25 Sep<span class="gap"></span>${icon('all')} 1 of 3`, 'p2', selected ? 'selected' : '')}
    ${task('Write the release notes', `${icon('tag')} writing`, '')}</div>
    <div class="task-group">${heading('Personal', '2')}
    ${task('Plan next week', `${icon('repeat')} Every Thursday`, 'p3')}
    ${task('Book a table for Saturday', `${icon('calendar')} Due tomorrow`, '')}</div>
    <div class="task-group">${heading('No project', '1')}${task('Pick up the parcel')}</div>
    <div class="completed-summary">${icon('down')} Completed today <span>2</span></div>`;
}
const today = (dark = false) => `<div class="device ${dark ? 'dark catppuccin' : ''}">${status()}${toolbar()}<div class="page-header"><h2>Today</h2><p>Thursday, 24 September · 6 tasks</p></div><div class="content">${todayContent()}</div>${tabbar('Today')}</div>`;
const property = (label, value, symbol = '', extra = '') => `<div class="property"><span>${label}</span><span class="value ${extra}">${symbol ? icon(symbol) : ''}${value}${icon('forward', 'disclosure')}</span></div>`;
function detailBody() {
  return `<div class="detail-body"><div class="detail-title">${circle('p2')}<h2>Review the launch<br>checklist</h2></div>
    <p class="notes">A final pass before we share the update.<br>Keep the release small and focused.</p>
    <div class="checklist"><div class="check-row"><span class="check-square checked">${icon('check')}</span><span class="done-copy">Check the release notes</span></div><div class="check-row"><span class="check-square"></span>Try a fresh install</div><div class="check-row"><span class="check-square"></span>Review the screenshots</div></div>
    <div class="property-section"><h3>Planning</h3>${property('Scheduled', 'Today', 'calendar')}${property('Deadline', 'Fri, 25 Sep', 'flag')}${property('Status', 'Next')}${property('Priority', 'P2 · Medium')}</div>
    <div class="property-section"><h3>Organization</h3>${property('Project', 'Autumn launch', 'folder')}${property('Area', 'Work', 'area')}${property('Tags', '<span class="tag-pill">launch</span><span class="tag-pill">review</span>')}${property('Repeat', 'Never', 'repeat')}</div>
    <div class="file-disclosure">${icon('forward')} File details<span class="saved">Saved to vault</span></div></div>`;
}
const detail = () => `<div class="device detail-screen">${status()}<div class="toolbar"><span class="back-link">${icon('back')} Today</span><span class="spacer"></span><span>Edit</span><span class="icon-control">${icon('more')}</span></div>${detailBody()}${home()}</div>`;
function keyboard() {
  const keys = (letters) => letters.split('').map(letter => `<span class="key">${letter}</span>`).join('');
  return `<div class="keyboard"><div class="suggestions"><span>“launch”</span><span>launch</span><span>launching</span></div><div class="key-row">${keys('qwertyuiop')}</div><div class="key-row">${keys('asdfghjkl')}</div><div class="key-row"><span class="key special">${icon('shift')}</span>${keys('zxcvbnm')}<span class="key special">${icon('delete')}</span></div><div class="key-row"><span class="key special middle">123</span><span class="key space">space</span><span class="key action middle">done</span></div><div class="keyboard-footer">${icon('globe')}${icon('mic')}</div></div>`;
}
const capture = () => `<div class="device">${status()}<div class="sheet-underlay"></div><div class="capture-sheet"><div class="drag-indicator"></div><div class="capture-toolbar"><span>Cancel</span><strong>New Task</strong><span class="save">Add</span></div><div class="capture-form"><div class="capture-title">Send the launch<br>update<span class="caret"></span></div><p class="placeholder">Add notes…</p><div class="capture-pills"><span class="capture-pill">${icon('inbox')} Inbox</span><span class="capture-pill">${icon('calendar')} Today</span><span class="capture-pill">${icon('flag')} Priority</span></div><div class="capture-extra"><span>Project, tags & repeat</span>${icon('forward')}</div></div></div>${keyboard()}${home()}</div>`;
const browseRow = (symbol, title, count = '', selected = false) => `<div class="browse-row ${selected ? 'selected' : ''}">${icon(symbol)}<span>${title}</span><span class="count">${count}</span>${icon('forward', 'disclosure')}</div>`;
const browseHeading = (title) => `<div class="browse-heading">${title}${icon('plus')}</div>`;
const browse = () => `<div class="device">${status()}<div class="toolbar"><span class="vault-label">${icon('cloud')} Personal</span><span class="spacer"></span><span class="icon-control">${icon('settings')}</span><span class="icon-control"><span class="add-control">${icon('plus')}</span></span></div><div class="page-header"><h2>Browse</h2><p>A place for everything.</p></div><div class="browse-content">${browseRow('next', 'Next', '12')}${browseRow('calendar', 'Upcoming', '8')}${browseRow('waiting', 'Waiting', '3')}${browseRow('someday', 'Someday', '9')}${browseRow('all', 'All Tasks', '38')}${browseHeading('Projects')}${browseRow('folder', 'Autumn launch', '7')}${browseRow('folder', 'Personal', '5')}${browseHeading('Your views')}${browseRow('area', 'Areas')}${browseRow('tag', 'Tags & priorities')}${browseRow('filter', 'Saved filters', '3')}<div class="browse-footer">${icon('cloud')} Personal · iCloud Drive ${icon('forward')}</div></div>${tabbar('Browse')}</div>`;
const palettes = [
  ['Taskmark', '#202226', '#191b1f', '#92b8ee'], ['Slate', '#1c2532', '#151d29', '#91bdf4'],
  ['Forest', '#1d2922', '#162019', '#91c9a3'], ['Sand', '#2b2520', '#211c17', '#dfb486'],
  ['Catppuccin', '#1e1e2e', '#11111b', '#cba6f7'], ['Dracula', '#282a36', '#22242e', '#bd93f9']
];
function themeTile([name, background, side, accent]) {
  return `<div class="theme-tile ${name === 'Catppuccin' ? 'is-selected' : ''}" style="--tile-bg:${background};--tile-side:${side};--tile-accent:${accent};--tile-ink:#e6e9ef;${name === 'Catppuccin' ? 'font-family:Figtree;' : name === 'Dracula' ? 'font-family:Inter;' : ''}"><div class="mini-preview"><div class="mini-side"></div><div class="mini-content"><b>Today</b>${[0, 1, 2].map(() => '<div class="mini-line"><span class="mini-circle"></span><span class="mini-rule"></span></div>').join('')}</div></div><div class="theme-name">${name}${name === 'Catppuccin' ? icon('check') : ''}</div></div>`;
}
const themes = () => `<div class="device dark catppuccin">${status()}<div class="toolbar"><span class="back-link">${icon('back')} Settings</span><span class="spacer"></span><span>Done</span></div><div class="page-header"><h2>Theme</h2><p>Your vault. Your way.</p></div><div class="settings-body"><h3>Appearance</h3><div class="segmented"><span class="segment">System</span><span class="segment">Light</span><span class="segment selected">Dark</span></div><h3>Palette</h3><div class="themes">${palettes.map(themeTile).join('')}</div><div class="property"><span style="color:var(--ink)">Apply vault stylesheet</span><span class="toggle"></span></div><p class="settings-note">Colors and spacing from <code>.config/style.css</code>.<br>These preferences travel with your vault.</p><span class="text-action">Reload stylesheet</span></div>${home()}</div>`;
const vault = () => `<div class="device dark standard">${status()}<div class="toolbar"><span class="back-link">${icon('back')} Settings</span><span class="spacer"></span><span class="icon-control">${icon('more')}</span></div><div class="page-header"><h2>Vault Status</h2><p>Your files, on this device.</p></div><div class="content"><div class="vault-identity">${icon('cloud')}<div><strong>Personal</strong><p>iCloud Drive / Taskmark</p></div></div><div class="vault-state"><h3>${icon('check')} Changes saved to vault</h3><p>Your latest edits are saved on this device.<br>iCloud controls delivery to other devices.</p></div><div class="vault-state"><h3>${icon('download')} 2 files waiting to download</h3><p>Available tasks are ready to use. These files will appear when iCloud provides them.</p><div class="vault-file">Projects/Weekend plans.md<br>Tasks/Choose a route.md</div><span class="text-action">Retry download</span></div><div class="vault-state"><h3>${icon('warning')} 1 file needs review</h3><p>There are two versions of a task. Review both before choosing which changes to keep.</p><span class="text-action">Review conflict</span></div><p class="settings-note" style="margin-top:20px">Last refreshed today at 9:41</p><span class="text-action">Refresh vault</span></div>${home()}</div>`;
function ipad() {
  return `<div class="device ipad">${status()}<div class="ipad-layout"><aside class="ipad-sidebar"><div class="side-title">Taskmark ${icon('sidebar')}</div>${browseRow('inbox', 'Inbox', '4')}${browseRow('sun', 'Today', '6', true)}${browseRow('next', 'Next', '12')}${browseRow('calendar', 'Upcoming', '8')}${browseRow('waiting', 'Waiting', '3')}${browseRow('someday', 'Someday', '9')}${browseRow('all', 'All Tasks', '38')}${browseHeading('Projects')}${browseRow('folder', 'Autumn launch', '7')}${browseRow('folder', 'Personal', '5')}${browseHeading('Your views')}${browseRow('area', 'Areas')}${browseRow('tag', 'Tags & priorities')}${browseRow('filter', 'Saved filters', '3')}<div class="browse-footer">${icon('cloud')} Personal ${icon('settings')}</div></aside><section class="ipad-list"><div class="toolbar"><span class="spacer"></span><span class="icon-control">${icon('search')}</span><span class="icon-control">${icon('options')}</span><span class="icon-control"><span class="add-control">${icon('plus')}</span></span></div><div class="page-header"><h2>Today</h2><p>Thursday, 24 September · 6 tasks</p></div><div class="content">${todayContent(true)}</div></section><section class="ipad-detail"><div class="toolbar"><span class="spacer"></span><span>Edit</span><span class="icon-control">${icon('more')}</span></div>${detailBody()}</section></div>${home()}</div>`;
}
const screens = { today: () => today(), detail, capture, browse, themes, 'today-dark': () => today(true), vault, ipad };
const boards = {
  daily: { title: 'A little more room for your day.', description: 'Taskmark on iPhone · familiar lists, readable details, and capture that stays out of the way.', screens: [['today', 'Today', 'Project groups keep six tasks easy to scan.'], ['detail', 'Task details', 'Notes first. Planning and organization close by.'], ['capture', 'Quick capture', 'Start with a title. Add structure when it helps.']] },
  personalization: { title: 'The same vault. A smaller screen.', description: 'Collections, themes and preferences follow you from your Mac — with native mobile navigation.', screens: [['browse', 'Browse', 'Every view, project and saved filter within reach.'], ['themes', 'Theme settings', 'Six palettes, paired appearances and vault styles.'], ['today-dark', 'Catppuccin · Mocha', 'The same quiet task canvas, in your chosen theme.']] }
};
const params = new URLSearchParams(location.search);
if (params.has('export')) document.body.classList.add('export');
const header = () => `<div class="board-header"><div class="brand"><img src="../../../Apps/LocalTodoApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="">Taskmark</div><span>iOS / iPadOS 18+ · Design exploration</span></div>`;
const footer = () => '<div class="board-footer"><span>Concept mockups · synthetic task content · not running app screenshots</span><span>September 2026</span></div>';
const artboard = document.getElementById('artboard');
if (params.has('screen') && screens[params.get('screen')]) {
  artboard.className = 'single-artboard';
  artboard.innerHTML = screens[params.get('screen')]();
} else if (params.get('board') === 'ipad') {
  artboard.className = 'board ipad-board';
  artboard.innerHTML = `${header()}<h1 class="board-heading">Everything in view. Nothing in the way.</h1><p class="board-description">Taskmark on iPad · sidebar, task list and details, with space for the work itself.</p>${ipad()}${footer()}`;
} else {
  const board = boards[params.get('board')] || boards.daily;
  artboard.className = 'board';
  artboard.innerHTML = `${header()}<h1 class="board-heading">${board.title}</h1><p class="board-description">${board.description}</p><div class="screen-grid">${board.screens.map(([id, title, description]) => `<section>${screens[id]()}<h2 class="screen-label">${title}</h2><p class="screen-description">${description}</p></section>`).join('')}</div>${footer()}`;
}
