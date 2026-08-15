import fs from 'node:fs';
import path from 'node:path';

const output = '/Users/williambarr/Documents/HTMLerFiles/DeskDashboard-HowTo';
fs.mkdirSync(output, { recursive: true });

const pages = [
  ['index.html', 'How-To Home'],
  ['add-widget.html', 'Add a Widget'],
  ['theme-layout.html', 'Theme + Layout'],
  ['local-run.html', 'Run Locally'],
  ['pi-deploy.html', 'Build for Pi'],
  ['kiosk-ops.html', 'Kiosk Operations'],
  ['now-playing.html', 'Now Playing']
];

const css = String.raw`
:root{color-scheme:dark;--bg:#101416;--panel:#182024;--panel2:#1d272c;--ink:#f2f5f4;--muted:#a9b6b3;--dim:#73817e;--line:#30403d;--green:#73d7a2;--green2:#183b2b;--amber:#ffc46b;--amber2:#3a2b12;--red:#ff8a8a;--red2:#3b1c1c;--blue:#83c8ff;--blue2:#173148;--shadow:0 12px 32px #0008;--r:18px}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:radial-gradient(circle at 80% 0,#17241f 0,transparent 34rem),var(--bg);color:var(--ink);font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{width:min(940px,100%);margin:auto;padding:56px clamp(16px,5vw,52px) 96px}h1{font-size:clamp(30px,6vw,48px);line-height:1.05;margin:0 0 14px;letter-spacing:-.035em}h2{font-size:clamp(23px,4vw,31px);line-height:1.15;margin:54px 0 18px;padding-left:13px;border-left:4px solid var(--green)}h3{font-size:19px;line-height:1.25;margin:0 0 8px}p{margin:0 0 12px;max-width:68ch}a{color:var(--green);text-underline-offset:3px}code{font:0.9em ui-monospace,SFMono-Regular,Menlo,monospace;color:#c9f7dc;background:#0c1112;padding:2px 5px;border-radius:6px;overflow-wrap:anywhere}pre{margin:12px 0 0;padding:15px 16px;overflow:auto;max-width:100%;background:#0b0f11;border:1px solid var(--line);border-radius:12px;box-shadow:inset 0 1px #ffffff08}pre code{padding:0;background:none;color:#d8eee2;white-space:pre}.lede{font-size:clamp(18px,3vw,22px);line-height:1.45;color:var(--muted)}.crumb{color:var(--dim);font-size:13px;margin-bottom:18px}.meta{display:flex;gap:7px;flex-wrap:wrap;margin:18px 0 26px}.pill,.label{display:inline-flex;align-items:center;border:1px solid var(--line);border-radius:999px;padding:4px 9px;color:var(--muted);font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase}.must{background:var(--green2);color:var(--green);border-color:#367a55}.important{background:var(--amber2);color:var(--amber);border-color:#755525}.optional{background:var(--blue2);color:var(--blue);border-color:#315d7e}.card,.step,.choice,.finish{background:linear-gradient(145deg,var(--panel2),var(--panel));border:1px solid var(--line);border-radius:var(--r);padding:20px;margin:14px 0;box-shadow:var(--shadow)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(260px,100%),1fr));gap:14px}.grid>*,.step>div:last-child{min-width:0}.grid>.card,.grid>.choice{margin:0}.step{display:grid;grid-template-columns:48px minmax(0,1fr);gap:15px}.num{width:44px;height:44px;border-radius:50%;display:grid;place-items:center;background:var(--green2);border:1px solid #397d59;color:var(--green);font-size:19px;font-weight:900}.step p:last-child,.card p:last-child{margin-bottom:0}.flow{display:flex;align-items:stretch;gap:8px;overflow:auto;max-width:100%;padding:4px 0 8px}.flow span{min-width:135px;display:grid;place-items:center;text-align:center;padding:14px;border-radius:12px;background:var(--panel);border:1px solid var(--line);font-weight:750}.flow b{align-self:center;color:var(--green);font-size:20px}.stop{border-color:#7d3434;background:linear-gradient(145deg,var(--red2),#241719)}.stop .label{color:var(--red);border-color:#7d3434}.check{border-color:#397d59;background:linear-gradient(145deg,var(--green2),var(--panel))}.finish{border:2px solid var(--green)}.biglink{display:block;color:inherit;text-decoration:none;transition:.15s}.biglink:hover{transform:translateY(-2px);border-color:var(--green)}.biglink .go{color:var(--green);font-weight:800}.path{font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;color:#bde9cf;overflow-wrap:anywhere}.mini{font-size:13px;color:var(--muted)}ul,ol{padding-left:22px;margin:10px 0}li{margin:6px 0}.checks{list-style:none;padding:0}.checks li{padding-left:28px;position:relative}.checks li:before{content:'✓';position:absolute;left:2px;color:var(--green);font-weight:900}.three{border-color:var(--green);background:linear-gradient(145deg,var(--green2),var(--panel))}.skip{position:fixed;z-index:20;left:18px;top:50%;transform:translateY(-50%);width:178px;padding:11px;background:var(--panel);border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow)}.skip button{display:none}.menu{display:flex;flex-direction:column;gap:3px}.menu strong{font-size:10px;color:var(--dim);letter-spacing:.12em;text-transform:uppercase;padding:5px 8px}.menu a{font-size:13px;color:var(--muted);text-decoration:none;padding:6px 8px;border-radius:7px}.menu a:hover{background:var(--bg);color:var(--green)}.foot{display:flex;flex-wrap:wrap;gap:7px;margin-top:48px}.foot a{padding:7px 10px;background:var(--panel);border:1px solid var(--line);border-radius:9px;text-decoration:none;font-size:13px}
@media(max-width:1180px){.skip{top:10px;left:10px;transform:none;width:auto;padding:5px}.skip button{display:grid;place-items:center;width:40px;height:40px;border:0;background:transparent;color:var(--muted);font-size:20px}.menu{display:none;min-width:170px;padding:4px}.skip.open .menu,.skip:focus-within .menu{display:flex}main{padding-top:74px}[id]{scroll-margin-top:82px}}
@media(max-width:560px){main{padding-inline:14px}.step{grid-template-columns:38px minmax(0,1fr);padding:15px;gap:10px}.num{width:36px;height:36px;font-size:16px}.flow{flex-direction:column}.flow b{text-align:center;transform:rotate(90deg)}.card,.choice,.finish{padding:16px}}
`;

const script = `<script>const n=document.querySelector('.skip');n.querySelector('button').onclick=()=>n.classList.toggle('open');document.addEventListener('click',e=>{if(!n.contains(e.target))n.classList.remove('open')});n.querySelectorAll('a').forEach(a=>a.onclick=()=>n.classList.remove('open'));</script>`;
const tag = (text, cls='must') => `<span class="label ${cls}">${text}</span>`;
const cmd = text => `<pre><code>${text}</code></pre>`;
const step = (n, title, html) => `<div class="step"><div class="num">${n}</div><div><h3>${title}</h3>${html}</div></div>`;
const card = (title, html, cls='') => `<div class="card ${cls}"><h3>${title}</h3>${html}</div>`;

function page({file,title,sentence,sections,remember,next}) {
  const nav = sections.map(s=>`<a href="#${s.id}">${s.nav || s.title}</a>`).join('');
  const body = sections.map(s=>`<section id="${s.id}"><h2>${s.title}</h2>${s.html}</section>`).join('\n');
  const footer = pages.filter(([f])=>f!==file).map(([f,l])=>`<a href="${f}">${l}</a>`).join('');
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} — DeskDashboard How-To</title><style>${css}</style></head><body><nav class="skip" aria-label="Page sections"><button aria-label="Open section menu">⌄</button><div class="menu"><strong>Jump to</strong><a href="#one">One sentence</a>${nav}<a href="#remember">Remember 3</a><a href="#next">Next move</a></div></nav><main><div class="crumb">DeskDashboard / Do-the-Thing Guides</div><h1>${title}</h1><p id="one" class="lede"><strong>One-sentence version:</strong> ${sentence}</p><div class="meta"><span class="pill">Source checked</span><span class="pill">Low-reading layout</span><span class="pill">360px ready</span></div>${body}<section id="remember"><h2>Remember Only 3 Things</h2><div class="card three"><ol>${remember.map(x=>`<li>${x}</li>`).join('')}</ol></div></section><section id="next"><h2>What To Do Next</h2><div class="finish"><h3>${next.title}</h3>${next.html}</div></section><div class="foot">${footer}</div></main>${script}</body></html>`;
  fs.writeFileSync(path.join(output,file), html);
}

page({file:'index.html',title:'Pick the Thing You Need to Do',sentence:'Choose a task card, follow the numbered blocks, and stop when the green completion box matches your screen.',sections:[
  {id:'pick',title:'Choose Your Task',html:`<div class="grid">
    <a class="card biglink" href="add-widget.html">${tag('Build','must')}<h3>Add a widget</h3><p>Service → model → tile → tests.</p><span class="go">Open steps →</span></a>
    <a class="card biglink" href="theme-layout.html">${tag('Design','optional')}<h3>Theme or layout</h3><p>Change tokens, tile structure, or a whole board.</p><span class="go">Open steps →</span></a>
    <a class="card biglink" href="local-run.html">${tag('Fastest','must')}<h3>Run it locally</h3><p>Console, browser preview, or native window.</p><span class="go">Open steps →</span></a>
    <a class="card biglink" href="pi-deploy.html">${tag('Pi','important')}<h3>Build the real UI</h3><p>Native GTK build with safe memory settings.</p><span class="go">Open steps →</span></a>
    <a class="card biglink" href="kiosk-ops.html">${tag('Operations','important')}<h3>Operate the kiosk</h3><p>Install, restart, inspect, screenshot, roll back.</p><span class="go">Open steps →</span></a>
    <a class="card biglink" href="now-playing.html">${tag('Data feed','optional')}<h3>Connect Now Playing</h3><p>HomePod → Mac producer → Pi widget.</p><span class="go">Open steps →</span></a>
  </div>`},
  {id:'map',title:'The Whole System in One Glance',html:`<div class="flow"><span>Real-world data</span><b>→</b><span>Service + model</span><b>→</b><span>Widget content</span><b>→</b><span>Layout + theme</span><b>→</b><span>Pi display</span></div>`},
  {id:'rules',title:'Before You Touch Anything',html:`<div class="grid">${card('Framework change','Start in Sources/Framework. Keep platform code out.','check')}${card('Dashboard product change','Start in Sources/App. Composition.swift wires the running system.','check')}${card('Pi visual change','The panel is the truth. Build, restart, then take a screenshot.','check')}</div>`}
],remember:['Composition.swift tells you what the appliance actually runs.','Widgets emit meaning; layouts and renderers decide shape and pixels.','The Pi UI must be built natively because GTK does not fit the static-musl route.'],next:{title:'Pick one card above',html:'<p>Do only that guide. Every guide ends with an observable “done” state.</p>'}});

page({file:'add-widget.html',title:'Add a New Widget',sentence:'Choose the smallest widget shape that works, then build data → transform → display and wire it once in Composition.swift.',sections:[
  {id:'choose',title:'First: Choose the Smallest Path',html:`<div class="grid"><div class="choice">${tag('Simple','must')}<h3>Static or self-contained</h3><p>Use <code>RenderableWidget</code>. Skip service and model.</p></div><div class="choice">${tag('Normal','optional')}<h3>Data-backed</h3><p>Use Service → WidgetModel → ServiceBackedWidget.</p></div><div class="choice">${tag('External push','important')}<h3>Data arrives by POST</h3><p>Add a locked store plus an ingest route.</p></div></div>`},
  {id:'files',title:'Make the Three Files',html:`<div class="flow"><span>&lt;Name&gt;Service.swift<br><small>raw data</small></span><b>→</b><span>&lt;Name&gt;WidgetModel.swift<br><small>format it</small></span><b>→</b><span>&lt;Name&gt;Widget.swift<br><small>display it</small></span></div><p class="path">Sources/App/DeskDashboardWidgets/&lt;Name&gt;/</p>`},
  {id:'steps',title:'Build It in This Order',html:
    step(1,'Define the raw data contract','<p>Make a Sendable value, a service protocol, and a typed <code>ServiceKey</code>. Store canonical values—not display strings.</p>')+
    step(2,'Add a simulated fallback','<p>Return believable data with no network or hardware. This keeps development fast and the tile non-empty.</p>')+
    step(3,'Transform in the model','<p>Put units, formatting, staleness, and cheap per-tick refresh here. Keep UI imports out.</p>')+
    step(4,'Render semantic content','<p>Return <code>WidgetContent</code>. Choose a preset with <code>.layout(.bigNumber)</code> or another named layout.</p>')+
    step(5,'Wire the running app','<p>Add the service and widget in <span class="path">Sources/App/DeskDashboardComposition/Composition.swift</span>.</p>')+
    step(6,'Only for push data','<p>Add the POST route in <span class="path">Sources/App/DeskDashboardIngest/PushIngest.swift</span>. Protect shared state with a lock.</p>')+
    step(7,'Prove the behavior','<p>Add model/widget tests, run the suite, then inspect the tile in the browser or native UI.</p>'+cmd('swift test\nswift run deskdashboard-dev'))},
  {id:'check',title:'Fast Accuracy Check',html:`<div class="card check"><ul class="checks"><li>No AppKit, HomeKit, or GTK in the service.</li><li>The model owns display formatting.</li><li>The widget returns semantic content, not fonts or pixels.</li><li>A simulated service works offline.</li><li>Composition.swift contains the live instance.</li><li>Tests cover missing data and the happy path.</li></ul></div>`},
  {id:'trouble',title:'If the Tile Is Blank',html:`<div class="grid">${card('No model value','Confirm activate() performs the first refresh. Tick-only refresh waits for the clock.','stop')}${card('Wrong service','Resolution order is direct binding → environment service → fallback.','stop')}${card('Push never appears','POST to the Pi or dev app on port 8642, not an unrelated localhost.','stop')}</div>`}
],remember:['Use the full three-layer pattern only when the widget has real data or transformation work.','Service stores facts; model creates display strings; widget creates WidgetContent.','Composition.swift is the final wiring point.'],next:{title:'You are done when…',html:'<ul class="checks"><li>The tile renders believable offline data.</li><li>Real data replaces it when connected.</li><li><code>swift test</code> passes.</li></ul>'}});

page({file:'theme-layout.html',title:'Add a Theme, Tile Layout, or Board',sentence:'Pick the layer that owns the change—theme for tokens, WidgetLayout for one tile, or app-side board files for the whole screen.',sections:[
  {id:'choose',title:'Which File Family Do You Need?',html:`<div class="grid"><div class="choice">${tag('Colors + type','must')}<h3>Theme</h3><p class="path">DashboardKit/Theme/Themes/</p></div><div class="choice">${tag('Inside one tile','optional')}<h3>WidgetLayout</h3><p class="path">DashboardKit/Widget/Layouts/</p></div><div class="choice">${tag('Whole screen','important')}<h3>Board + arrangement</h3><p class="path">DeskDashboardApp/Dashboard/</p></div></div>`},
  {id:'theme',title:'Make a Theme',html:
    step(1,'Copy one nearby theme','<p>Create one file under <code>Theme/Themes</code>. Keep its named color/type/shape tokens beside the theme.</p>')+
    step(2,'Declare only the differences',cmd(`public struct MyTheme: Theme, Sendable {
    public let name = "My Theme"
    public var colors: ThemeColors { .myPalette }
    public init() {}
}`))+
    step(3,'Use it at composition or arrangement','<p>The composition supplies the default. A specific <code>Arrangement</code> may override it.</p>')+`<div class="card stop">${tag('Native font trap','important')}<p><code>fontFamily</code> reaches the dev web renderer only. The Pi’s native font comes from GTK settings.</p></div>`},
  {id:'layout',title:'Make a Tile Layout',html:
    step(1,'Create one new layout file','<p>Do not add an enum case. <code>WidgetLayout</code> is a struct with named static values.</p>')+
    step(2,'Map content to semantic nodes',cmd(`public extension WidgetLayout {
    static let myLayout = Self(id: "myLayout") { content in
        .stack(.vertical, spacing: 6, [
            .text(content.primaryText, role: .hero)
        ])
    }
}`))+
    step(3,'Select it on the widget','<p>Use <code>.layout(.myLayout)</code>. Existing renderers interpret the same semantic tree.</p>')+`<div class="card stop">${tag('GTK interaction rule','important')}<p>Do not swap the node structure while a press is active. Keep tappable structure stable; change strings and state.</p></div>`},
  {id:'board',title:'Make or Change a Board',html:
    step(1,'Edit an app-side board file','<p>Board geometry is a product decision. Use the <code>BoardColumn</code>, <code>BoardRow</code>, and <code>BoardBand</code> DSL in the app.</p>')+
    step(2,'Add it to Arrangements.swift','<p>The array order is the switcher order. Index 0 is what the kiosk boots into.</p>')+
    step(3,'Verify at the target shape',cmd('swift run deskdashboard-ui --window 1920x440'))},
  {id:'check',title:'Visual Checkpoints',html:`<div class="card check"><ul class="checks"><li>Text still fits at 1920×440.</li><li>Bottom margin is visible.</li><li>Touch targets stay usable.</li><li>Theme contrast works on the physical panel.</li><li>Switcher order matches Arrangements.swift.</li></ul></div>`}
],remember:['Theme = tokens; WidgetLayout = one tile’s semantic tree; board = whole-screen geometry.','A new WidgetLayout is a standalone static value in its own file, not an enum case.','The physical Pi panel—not a desktop preview—is the final color and geometry check.'],next:{title:'You are done when…',html:'<p>The desktop preview is correct, tests pass, and a fresh Pi screenshot shows the intended board without clipping.</p>'}});

page({file:'local-run.html',title:'Run DeskDashboard Locally',sentence:'Use console for logic, the browser renderer for fast visual iteration, and the native window only for real renderer behavior.',sections:[
  {id:'choose',title:'Choose Your Feedback Speed',html:`<div class="grid"><div class="choice">${tag('Fastest','must')}<h3>Console</h3><p>Data and lifecycle only.</p>${cmd('swift run deskdashboard-dev --console')}</div><div class="choice">${tag('Best default','optional')}<h3>Browser</h3><p>Fast visual preview + ingest.</p>${cmd('swift run deskdashboard-dev')}</div><div class="choice">${tag('Real renderer','important')}<h3>Native window</h3><p>SwiftCrossUI behavior.</p>${cmd('swift run deskdashboard-ui --window 1920x440')}</div></div>`},
  {id:'browser',title:'Browser Preview',html:
    step(1,'Start it',cmd('swift run deskdashboard-dev'))+
    step(2,'Open the page','<p><a href="http://127.0.0.1:8642">http://127.0.0.1:8642</a></p>')+
    step(3,'Optional: change the port',cmd('swift run deskdashboard-dev --port 9000'))},
  {id:'native',title:'Native UI Preview',html:
    step(1,'Use the panel geometry',cmd('swift run deskdashboard-ui --window 1920x440'))+
    step(2,'Keep the arrangement switcher','<p>Do not pass <code>--kiosk</code> while iterating; that flag hides the switcher.</p>')+
    step(3,'Tune scale without editing tokens',cmd('DD_UI_SCALE=1.1 swift run deskdashboard-ui --window 1920x440'))},
  {id:'push',title:'Quick Push Test',html:`<p>Run either web or native UI, then POST to its ingest server on port 8642.</p>${cmd(`curl -X POST http://127.0.0.1:8642/ingest/now-playing \\
  -H 'Content-Type: application/json' \\
  -d '{"title":"Test Track","artist":"Test Artist","isPlaying":true}'`)}<p class="mini">If the payload contract changes, copy the current JSON shape from the ingest tests or producer.</p>`},
  {id:'trouble',title:'If It Does Not Start',html:`<div class="grid">${card('Port busy','Use <code>--port N</code>, or stop the process already using 8642.','stop')}${card('Native build fails','The UI has GUI dependencies. Use <code>deskdashboard-dev</code> for the dependency-light path.','stop')}${card('Push is invisible','Confirm you POSTed to the process that is actually displaying the dashboard.','stop')}</div>`}
],remember:['Console answers “is the data right?”','Browser answers “does the semantic layout look right?”','Native UI answers “does the real renderer behave right?”'],next:{title:'You are done when…',html:'<p>The chosen renderer stays running, the dashboard updates, and your test POST visibly changes the intended tile.</p>'}});

page({file:'pi-deploy.html',title:'Build the Real UI on Raspberry Pi',sentence:'Install GTK once, build deskdashboard-ui natively on the Pi with one job, then restart the kiosk that points at the release binary.',sections:[
  {id:'why',title:'Use the Correct Build Path',html:`<div class="flow"><span>deskdashboard-dev</span><b>→</b><span>static-musl cross-build is OK</span></div><div class="flow"><span>deskdashboard-ui</span><b>→</b><span>GTK + glibc</span><b>→</b><span>build natively on Pi</span></div><div class="card stop">${tag('Do not mix these','important')}<p>The GTK UI cannot use the static-musl route. That failure is architectural, not a missing flag.</p></div>`},
  {id:'once',title:'One-Time Pi Setup',html:step(1,'Install native dependencies',cmd('sudo apt update\nsudo apt install -y libgtk-4-dev clang pkg-config'))+step(2,'Confirm Swift is on PATH',cmd('swift --version\npkg-config --modversion gtk4'))},
  {id:'build',title:'Build What the Kiosk Actually Runs',html:
    step(1,'Enter the Pi checkout',cmd('cd ~/Desktop/DeskDashboard-MacMiniDev'))+
    step(2,'Build release with one job',cmd('CONFIG=release JOBS=1 bash scripts/build-ui-pi.sh'))+
    step(3,'Look for the final path','<p><code>built: …/.build/release/deskdashboard-ui</code></p>')+
    `<div class="card stop">${tag('Silent no-op trap','important')}<p>The current kiosk runs the release binary through <code>~/.config/sway/kiosk.conf</code>. A debug build can succeed and still change nothing on screen.</p></div>`},
  {id:'restart',title:'Restart and Verify',html:
    step(1,'Restart the service',cmd('sudo systemctl restart deskdashboard-ui'))+
    step(2,'Check that it is alive',cmd('systemctl is-active deskdashboard-ui\nsystemctl --no-pager -n 20 status deskdashboard-ui'))+
    step(3,'Check the actual launch path',cmd("grep -n 'deskdashboard-ui' ~/.config/sway/kiosk.conf"))},
  {id:'memory',title:'Keep the Pi Alive',html:`<div class="card check"><ul class="checks"><li>Use <code>JOBS=1</code> on the 4 GB Pi.</li><li>Expect release builds to be slow.</li><li>Do not delete <code>.build</code> during another build.</li><li>Read any dependency-patch warning printed by the script.</li></ul></div>`}
],remember:['The graphical UI is a native glibc + GTK build.','Use release + one job for the shipping kiosk path.','A successful build is not deployed until the active Sway config points at that binary and the service restarts.'],next:{title:'You are done when…',html:'<ul class="checks"><li>The build prints the release binary path.</li><li>The service is active.</li><li>The visible panel shows the new change.</li></ul>'}});

page({file:'kiosk-ops.html',title:'Install, Inspect, and Recover the Pi Kiosk',sentence:'Install once, switch to console boot before enabling, and use systemd plus Sway-aware checks for daily operation.',sections:[
  {id:'install',title:'First Installation',html:
    step(1,'Build the UI first',cmd('CONFIG=release JOBS=1 bash scripts/build-ui-pi.sh'))+
    step(2,'Install the service',cmd('sudo bash scripts/install-kiosk-pi.sh'))+
    step(3,'Free the display',cmd('sudo raspi-config nonint do_boot_behaviour B2'))+
    step(4,'Enable, then reboot',cmd('sudo systemctl enable deskdashboard-ui\nsudo reboot'))+
    `<div class="card stop">${tag('Stop','important')}<p>Do not start Cage while the desktop owns the display. Switch to console boot first.</p></div>`},
  {id:'daily',title:'Daily Commands',html:`<div class="grid"><div class="card"><h3>Restart</h3>${cmd('sudo systemctl restart deskdashboard-ui')}</div><div class="card"><h3>Status</h3>${cmd('systemctl status deskdashboard-ui')}</div><div class="card"><h3>Boot log</h3>${cmd('journalctl -u deskdashboard-ui -b')}</div><div class="card"><h3>Whole-system UI log</h3>${cmd("journalctl --since '-5min' --no-pager | grep -i deskdashboard")}</div></div><p class="mini">The current app is exec’d by Sway, so some stderr appears under Sway rather than under the systemd unit.</p>`},
  {id:'shot',title:'Take a Screenshot over SSH',html:step(1,'Capture with grim',cmd(`export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=$(basename $(ls $XDG_RUNTIME_DIR/wayland-* | grep -v '\\.lock' | head -1))
grim /tmp/dash.png`))+step(2,'Copy it to your Mac',cmd('scp willbarr@192.168.4.244:/tmp/dash.png .'))},
  {id:'bringup',title:'Bring Up the Whole System from the Mac',html:`<p>Kick local producers, SSH to the Pi, restart the kiosk, and print status:</p>${cmd('bash scripts/start-dashboard.sh')}<p>Override the host if needed:</p>${cmd('PI_HOST=user@pi-address bash scripts/start-dashboard.sh')}`},
  {id:'rollback',title:'Return to the Normal Desktop',html:`<div class="card stop">${tag('Recovery','important')}${cmd('sudo systemctl disable --now deskdashboard-ui\nsudo raspi-config nonint do_boot_behaviour B4\nsudo reboot')}</div>`}
],remember:['Never let the desktop and the kiosk compositor fight for the display.','Systemd owns restart policy, but Sway currently owns the actual binary command.','Rollback is disable service → restore desktop autologin → reboot.'],next:{title:'You are done when…',html:'<p>The panel boots directly into the dashboard, SSH still works, and you know the three-line desktop rollback.</p>'}});

page({file:'now-playing.html',title:'Connect HomePod Now Playing',sentence:'Install pyatv with Python 3.12 on the Mac, discover the HomePod ID, then run the installer with the Pi ingest URL.',sections:[
  {id:'flow',title:'Know the Route',html:`<div class="flow"><span>HomePod</span><b>→</b><span>pyatv on Mac</span><b>→</b><span>LaunchAgent every 5s</span><b>→</b><span>Pi :8642</span><b>→</b><span>Music tile</span></div>`},
  {id:'install',title:'Install the Reader',html:
    step(1,'Install pipx',cmd('brew install pipx\npipx ensurepath'))+
    step(2,'Pin pyatv to Python 3.12',cmd('pipx install --python /opt/homebrew/opt/python@3.12/libexec/bin/python3 pyatv'))+
    `<div class="card stop">${tag('Version trap','important')}<p>pyatv 0.18 crashes on Python 3.14. The symptom may look like “nothing playing.”</p></div>`},
  {id:'discover',title:'Find the HomePod',html:step(3,'Scan the network',cmd('atvremote scan'))+step(4,'Copy the HomePod ID','<p>You will use it as <code>DD_ATV_ID</code>.</p>')},
  {id:'agent',title:'Install the Push Agent',html:step(5,'Point it at the Pi',cmd(`DD_ATV_ID=<homepod-id> \\
DD_INGEST_URL=http://<pi-address>:8642/ingest/now-playing \\
bash producers/install-nowplaying-agent.sh`))+step(6,'Watch the log',cmd('tail -f /tmp/deskdashboard-nowplaying.log'))},
  {id:'verify',title:'What Success Looks Like',html:`<div class="card check"><ul class="checks"><li>A producer JSON line appears about every 5 seconds.</li><li>The response includes <code>"stored"</code>.</li><li>Playing music changes the Pi tile.</li><li>The ingest URL names the Pi—not 127.0.0.1 on the Mac.</li></ul></div>`},
  {id:'trouble',title:'If It Says “Nothing Playing”',html:
    step(1,'Query pyatv directly',cmd('~/.local/bin/atvscript --id <homepod-id> playing'))+
    step(2,'Read the error log',cmd('tail -100 /tmp/deskdashboard-nowplaying.err'))+
    step(3,'Reinstall on Python 3.12 if there is an event-loop traceback',cmd('pipx uninstall pyatv\npipx install --python /opt/homebrew/opt/python@3.12/libexec/bin/python3 pyatv'))}
],remember:['The producer runs on the Mac; the ingest server runs with the displayed dashboard.','Pin pyatv to Python 3.12.','For a Pi-hosted UI, the producer URL must point to the Pi’s port 8642.'],next:{title:'You are done when…',html:'<p>Music playing on the HomePod appears on the Pi within one producer interval—about five seconds.</p>'}});

for (const [file] of pages) {
  if (!fs.existsSync(path.join(output,file))) throw new Error(`Missing output: ${file}`);
}
console.log(`Generated ${pages.length} HTMLer how-to files in ${output}`);
