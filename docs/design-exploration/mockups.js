/* Discussion prototype: synthetic data and in-memory interactions only. */
'use strict';
const $ = selector => document.querySelector(selector);
const shapes = {
  circle:'<circle cx="12" cy="12" r="8.5"/>',
  check:'<circle cx="12" cy="12" r="8.5"/><path d="m8 12 3 3 5-6"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
  inbox:'<path d="M5 4h14l3 11v5H2v-5L5 4Z"/><path d="M2 15h6l2 3h4l2-3h6"/>',
  next:'<circle cx="12" cy="12" r="9"/><path d="M8 12h8m-4-4 4 4-4 4"/>',
  calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 10h18m-13 5h2m4 0h2"/>',
  waiting:'<path d="M6 3h12M6 21h12M7 3c0 5 1 6 5 9-4 3-5 4-5 9m10-18c0 5-1 6-5 9 4 3 5 4 5 9"/>',
  someday:'<path d="M3 8h18v13H3zM2 3h20v5H2zm7 10h6"/>',
  list:'<path d="m3 6 1.5 1.5L7 4m-4 9 1.5 1.5L7 11m-4 9 1.5 1.5L7 18M11 6h10M11 13h10M11 20h10"/>',
  project:'<rect x="4" y="5" width="16" height="16" rx="3"/><path d="M8 2h11a4 4 0 0 1 4 4v10"/>',
  search:'<circle cx="10" cy="10" r="6.5"/><path d="m15 15 6 6"/>',
  sliders:'<path d="M3 6h5m4 0h9M3 12h11m4 0h3M3 18h3m4 0h11"/><circle cx="10" cy="6" r="2"/><circle cx="16" cy="12" r="2"/><circle cx="8" cy="18" r="2"/>',
  plus:'<path d="M12 4v16M4 12h16"/>',
  close:'<path d="m6 6 12 12M6 18 18 6"/>',
  sidebar:'<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M9 4v16"/>',
  inspector:'<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M15 4v16"/>',
  chevron:'<path d="m8 9 4 4 4-4"/>',
  flag:'<path d="M5 22V3m0 1c5-4 9 4 14 0v10c-5 4-9-4-14 0"/>',
  note:'<path d="M5 2h9l5 5v15H5zM14 2v6h5M8 12h8M8 16h6"/>',
  repeat:'<path d="m17 2 4 4-4 4M3 10V8a2 2 0 0 1 2-2h16M7 22l-4-4 4-4m14 0v2a2 2 0 0 1-2 2H3"/>',
  tag:'<path d="M3 3h8l11 11-8 8L3 11V3Z"/><circle cx="7.5" cy="7.5" r="1"/>',
  area:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  more:'<circle cx="4" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="20" cy="12" r="1"/>',
  warning:'<circle cx="12" cy="12" r="9"/><path d="M12 7v6m0 3v1"/>'
};
const icon = name => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${shapes[name] || shapes.circle}</svg>`;
const escapeHTML = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
document.querySelectorAll('[data-icon]').forEach(element => { element.innerHTML = icon(element.dataset.icon); });
const palettes = {
  standard:[['#f7f8fa','#edf0f3','#f1f3f6','#365f99'],['#202226','#191b1f','#25282d','#92b8ee']],
  slate:[['#f1f5f9','#e4ebf3','#eaf0f7','#315e9d'],['#1c2532','#151d29','#232e3d','#91bdf4']],
  forest:[['#f2f7f3','#e4ede6','#ebf2ed','#306b49'],['#1d2922','#162019','#25332a','#91c9a3']],
  sand:[['#faf6ef','#efe7da','#f4ede2','#8b562c'],['#2b2520','#211c17','#342d25','#dfb486']],
  catppuccin:[['#eff1f5','#dce0e8','#e6e9ef','#8839ef'],['#1e1e2e','#11111b','#181825','#cba6f7']],
  dracula:[['#fffbeb','#f4f0e1','#f8f4e5','#644ac9'],['#282a36','#22242e','#2e303d','#bd93f9']]
};
const concepts = {
  split:{title:'A · Quiet split',description:'The familiar three-column workspace, with a calmer list and a notes-first inspector. Organization stays visible without the stacked form containers.',principle:'The smallest behavioral change',tradeoff:'A reliable first step. You keep task context side by side, but a narrow center column still limits the sense of space.',instructions:'Select a task to change the inspector. Toggle details at the top right. Compare the same layout across light and dark palettes.'},
  focus:{title:'B · Focused canvas',description:'A generous task surface and a quiet navigation rail. Details open only when requested, so selecting a task no longer reshapes the window.',principle:'Recommended direction',tradeoff:'Closest to the calm of Things. Keep A’s inspector as an optional tool; make the two-column view the daily default.',instructions:'Select a row, then use the top-right inspector button or double-click the title. Try a project to see notes above its tasks.'},
  inline:{title:'C · Inline workspace',description:'Open a task where it lives. Notes, checklist and compact properties expand inside the list, on the same opaque working surface.',principle:'The most Things-like interaction',tradeoff:'Very direct for one task at a time. Expansion moves nearby rows and needs careful keyboard, editing and drag behavior.',instructions:'Click a task to expand it; click it again to collapse. Edit its notes, toggle checklist steps, or select another task.'}
};
const tasks = [
  {id:1,title:'Send the revised proposal',project:'Studio website',area:'Work',tags:'Writing',priority:'p1',deadline:'Yesterday',overdue:true,scheduled:'Today',notes:'A short summary of the revised scope, with the updated estimate attached.',checklist:['Confirm the revised scope','Send to Olivia'],route:'Today'},
  {id:2,title:'Simplify the opening story',project:'Prepare presentation',area:'Work',tags:'Design',priority:'p2',deadline:'Friday',scheduled:'Today',notes:'Keep the introduction to three ideas. Lead with the customer’s problem, then show what changes for them.',checklist:['Choose the opening example','Reduce the introduction to three slides'],route:'Today'},
  {id:3,title:'Review the deck with Olivia',project:'Prepare presentation',area:'Work',tags:'Design',scheduled:'Today',notes:'Walk through the narrative together. Leave the final ten minutes for feedback.',checklist:[],route:'Today'},
  {id:4,title:'Book a rehearsal room',project:'Prepare presentation',area:'Work',tags:'',scheduled:'Today',notes:'Find a quiet space with a screen and enough room to rehearse standing up.',checklist:[],route:'Today'},
  {id:5,title:'Sketch the new project page',project:'Studio website',area:'Work',tags:'Design',priority:'p3',scheduled:'Today',notes:'Start with a single project. Let the work lead; keep the introduction short.',checklist:[],route:'Today'},
  {id:6,title:'Book the bike service',project:'Personal',area:'Personal',tags:'Errands',scheduled:'Today',notes:'Ask them to check the rear brake and replace the chain if needed.',checklist:[],route:'Today'},
  {id:7,title:'Plan meals for the week',project:'Personal',area:'Personal',tags:'Home',scheduled:'Today',repeat:'Weekly',notes:'Three easy dinners, one new recipe.',checklist:[],route:'Today'},
  {id:8,title:'Read the conference brief',project:'Prepare presentation',area:'Work',tags:'Reading',scheduled:'Tomorrow',notes:'Check the audience profile and the session length.',checklist:[],route:'Upcoming'},
  {id:9,title:'Try the new coffee place',project:'Personal',area:'Personal',tags:'',notes:'The little place near the station.',checklist:[],route:'Inbox'},
  {id:10,title:'Collect examples for the case study',project:'Studio website',area:'Work',tags:'Writing',notes:'Keep the examples specific.',checklist:[],route:'Inbox'}
];
let state = {concept:'focus',route:'Today',selected:null,inspector:false,query:'',metadata:false};
const routes = [['Inbox','inbox'],['Today','sun'],['Next','next'],['Upcoming','calendar'],['Waiting','waiting'],['Someday','someday'],['All Tasks','list']];
function navigate(route){state.route=route;state.selected=null;state.query='';$('#search-input').value='';$('#project-notes').hidden=!['Prepare presentation','Studio website'].includes(route);$('#page-title').textContent=route;$('#page-subtitle').textContent=route==='Today'?'Monday, 21 September':route==='Prepare presentation'?'Work':route==='Studio website'?'Work':'Personal vault';$('#page-symbol').innerHTML=icon(routes.find(r=>r[0]===route)?.[1] || 'project');$('#toolbar-context').textContent='Personal';render();}
function visibleTasks(){return tasks.filter(task=>{const routeMatch=state.route==='All Tasks'||task.route===state.route||task.project===state.route||(state.route==='Next'&&task.area==='Work');return routeMatch&&task.title.toLowerCase().includes(state.query.toLowerCase());});}
function renderNavigation(){
  $('#routes').innerHTML=routes.map(([route,symbol])=>`<button class="nav-row" data-route="${route}" ${state.route===route?'aria-current="page"':''}>${icon(symbol)}<span>${route}</span>${['Inbox','Today'].includes(route)?`<span class="count">${tasks.filter(t=>t.route===route&&!t.done).length}</span>`:''}</button>`).join('');
  $('#projects').innerHTML=['Prepare presentation','Studio website','Personal'].map(route=>`<button class="nav-row project" data-route="${route}" ${state.route===route?'aria-current="page"':''}>${icon('project')}<span>${route}</span></button>`).join('');
  document.querySelectorAll('[data-route]').forEach(button=>button.onclick=()=>navigate(button.dataset.route));
}
function metadata(task){return [['next','Status','Next'],['flag','Priority',task.priority?.toUpperCase()||'None'],['calendar','Scheduled',task.scheduled||'Not scheduled'],['flag','Deadline',task.deadline||'No deadline'],['project','Project',task.project],['area','Area',task.area],['tag','Tags',task.tags||'No tags'],['repeat','Repeat',task.repeat||'Does not repeat']].map(([symbol,label,value])=>`<div class="meta-line"><span>${icon(symbol)}${label}</span><span class="meta-value ${label==='Scheduled'?'accent':''}">${escapeHTML(value)}</span></div>`).join('');}
function checklist(task){return task.checklist.length?`<div class="checklist">${task.checklist.map((label,index)=>`<label><input type="checkbox" data-step="${index}" data-task="${task.id}" ${task.steps?.[index]?'checked':''}>${escapeHTML(label)}</label>`).join('')}</div>`:'';}
function taskDetails(task,inline=false){
  if(!task)return '<p class="empty">Select a task to see its notes and details.</p>';
  return `${inline?'':`<div class="detail-heading"><span class="task-check ${task.priority||''}">${icon(task.done?'check':'circle')}</span><h3>${escapeHTML(task.title)}</h3></div>`}<${inline?'button':'p'} class="detail-notes ${inline?'edit-notes':''}" ${inline?`data-edit-notes="${task.id}" title="Edit notes"`:''}>${escapeHTML(task.notes)}</${inline?'button':'p'}>${checklist(task)}<div class="${inline?'inline-properties':'detail-meta'}">${metadata(task)}</div><div class="detail-actions"><span>Example details · in memory only</span>${inline?'<button data-collapse>Close details</button>':''}</div>`;
}
function render(){
  renderNavigation();const visible=visibleTasks();const groups=new Map();visible.forEach(task=>{const group=state.route===task.project?'Tasks':task.project;if(!groups.has(group))groups.set(group,[]);groups.get(group).push(task);});
  $('#tasks').innerHTML=visible.length?[...groups].map(([name,items])=>`<section class="task-group"><h3 class="group-title">${escapeHTML(name)}<span>${items.filter(t=>!t.done).length}</span></h3>${items.map(task=>`<div class="task-row ${state.selected===task.id?'selected':''} ${task.overdue&&!task.done?'overdue':''} ${task.done?'done':''}"><button class="task-check ${task.priority||''}" data-complete="${task.id}" aria-label="${task.done?'Reopen':'Complete'} ${escapeHTML(task.title)}">${icon(task.done?'check':'circle')}</button><button class="task-main" data-select="${task.id}" aria-expanded="${state.concept==='inline'&&state.selected===task.id}" aria-label="${state.concept==='inline'?'Expand':'Select'} ${escapeHTML(task.title)}"><span class="task-title">${escapeHTML(task.title)}${task.id===2||task.id===5?`<span class="row-note">${icon('note')}</span>`:''}</span>${state.metadata?`<span class="task-subtitle">${escapeHTML(task.area)}${task.tags?` · #${escapeHTML(task.tags.toLowerCase())}`:''}</span>`:''}</button><span class="row-trailing ${task.overdue&&!task.done?'overdue':''}">${task.priority?`<span class="priority-label">${task.priority.toUpperCase()}</span>`:''}${task.overdue&&!task.done?`${icon('warning')}Overdue`:task.deadline?`${icon('flag')}${escapeHTML(task.deadline)}`:task.repeat?`${icon('repeat')}Weekly`:''}</span></div>${state.concept==='inline'&&state.selected===task.id?`<div class="inline-editor">${taskDetails(task,true)}</div>`:''}`).join('')}</section>`).join(''):'<div class="empty">No example tasks in this view.<br>Add one above, or choose Today.</div>';
  const showInspector=state.inspector&&state.concept!=='inline';$('#inspector').hidden=!showInspector;$('.workspace').classList.toggle('has-inspector',showInspector);$('#inspector').innerHTML=taskDetails(tasks.find(t=>t.id===state.selected));$('#inspector-toggle').setAttribute('aria-pressed',String(showInspector));$('#inspector-toggle').setAttribute('aria-label',showInspector?'Hide inspector':'Show inspector');$('#inspector-toggle').title=showInspector?'Hide inspector':'Show inspector';$('#inspector-toggle').hidden=state.concept==='inline';
  document.querySelectorAll('[data-select]').forEach(button=>{button.onclick=()=>{const id=Number(button.dataset.select);state.selected=state.concept==='inline'&&state.selected===id?null:id;if(state.concept==='split')state.inspector=true;render();document.querySelector(`[data-select="${id}"]`)?.focus({preventScroll:true});};button.ondblclick=()=>{if(state.concept==='focus'){state.inspector=true;render();}};});
  document.querySelectorAll('[data-complete]').forEach(button=>button.onclick=()=>{const task=tasks.find(t=>t.id===Number(button.dataset.complete));task.done=!task.done;render();document.querySelector(`[data-complete="${task.id}"]`)?.focus({preventScroll:true});$('#announcement').textContent=`${task.title} ${task.done?'completed':'reopened'} in the mockup.`;});
  document.querySelectorAll('[data-step]').forEach(input=>input.onchange=()=>{const task=tasks.find(t=>t.id===Number(input.dataset.task));task.steps??={};task.steps[input.dataset.step]=input.checked;});
  document.querySelector('[data-collapse]')?.addEventListener('click',()=>{const previous=state.selected;state.selected=null;render();document.querySelector(`[data-select="${previous}"]`)?.focus();});
  document.querySelector('[data-edit-notes]')?.addEventListener('click',event=>{const task=tasks.find(t=>t.id===Number(event.currentTarget.dataset.editNotes));const editor=document.createElement('textarea');editor.value=task.notes;editor.setAttribute('aria-label','Edit example task notes');editor.onblur=()=>{task.notes=editor.value;render();};editor.onkeydown=key=>{if(key.key==='Escape')editor.blur();};event.currentTarget.replaceWith(editor);editor.focus();});
}
function chooseConcept(concept){state.concept=concept;state.inspector=concept==='split';state.selected=concept==='focus'?null:2;$('#app').dataset.concept=concept;document.querySelectorAll('[data-concept]').forEach(button=>{if(button.tagName==='BUTTON')button.setAttribute('aria-pressed',String(button.dataset.concept===concept));});const content=concepts[concept];$('#concept-title').textContent=content.title;$('#concept-description').textContent=content.description;$('#concept-principle').textContent=content.principle;$('#concept-tradeoff').textContent=content.tradeoff;$('#concept-instructions').textContent=content.instructions;render();$('#content-scroll').scrollTop=0;const url=new URL(location.href);url.searchParams.set('concept',concept);history.replaceState(null,'',url);}
function applyPalette(){const dark=$('#dark').getAttribute('aria-pressed')==='true';const palette=$('#palette').value;$('#app').dataset.dark=String(dark);$('#app').dataset.theme=palette;palettes[palette][Number(dark)].forEach((color,index)=>$('#app').style.setProperty(['--paper','--side','--detail','--accent'][index],color));}
document.querySelectorAll('button[data-concept]').forEach(button=>button.onclick=()=>chooseConcept(button.dataset.concept));
$('#palette').onchange=applyPalette;$('#dark').onclick=()=>{$('#dark').setAttribute('aria-pressed',String($('#dark').getAttribute('aria-pressed')!=='true'));applyPalette();};$('#solid').onclick=()=>{const value=$('#solid').getAttribute('aria-pressed')!=='true';$('#solid').setAttribute('aria-pressed',String(value));$('#app').dataset.solid=String(value);};
$('#inspector-toggle').onclick=()=>{state.inspector=!state.inspector;if(state.inspector&&!state.selected)state.selected=visibleTasks()[0]?.id;render();};
$('#options-toggle').onclick=()=>{$('#view-options').hidden=!$('#view-options').hidden;$('#options-toggle').setAttribute('aria-expanded',String(!$('#view-options').hidden));};$('#extra-metadata').onchange=event=>{state.metadata=event.target.checked;render();};
$('#search-toggle').onclick=()=>{$('#search-field').hidden=false;$('#search-input').focus();};$('#close-search').onclick=()=>{$('#search-field').hidden=true;state.query='';$('#search-input').value='';render();$('#search-toggle').focus();};$('#search-input').oninput=event=>{state.query=event.target.value;render();};
function capture(){ $('#capture').hidden=false;$('#content-scroll').scrollTop=0;$('#capture-input').focus(); }
$('#new-task').onclick=capture;$('#add-row').onclick=capture;$('#cancel-capture').onclick=()=>{$('#capture').hidden=true;$('#new-task').focus();};
$('#capture').onsubmit=event=>{event.preventDefault();const title=$('#capture-input').value.trim();if(!title)return;const project=routes.some(r=>r[0]===state.route)?'Personal':state.route;tasks.push({id:Math.max(...tasks.map(t=>t.id))+1,title,project,area:project==='Personal'?'Personal':'Work',tags:'',scheduled:state.route==='Today'?'Today':undefined,notes:'Add a note…',checklist:[],route:state.route});$('#capture-input').value='';$('#capture').hidden=true;render();$('#new-task').focus();$('#announcement').textContent='Example task added. Nothing was saved to a vault.';};
document.addEventListener('keydown',event=>{if(event.key==='Escape'){if(!$('#capture').hidden){$('#capture').hidden=true;$('#new-task').focus();}$('#view-options').hidden=true;$('#options-toggle').setAttribute('aria-expanded','false');}if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='n'){event.preventDefault();capture();}});
const initial=new URLSearchParams(location.search);if(initial.get('dark')==='true')$('#dark').setAttribute('aria-pressed','true');if(palettes[initial.get('palette')])$('#palette').value=initial.get('palette');navigate('Today');applyPalette();chooseConcept(concepts[initial.get('concept')]?initial.get('concept'):'focus');
