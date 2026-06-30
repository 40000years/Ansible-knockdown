
                    // ============================================================
                    // Helpers
                    // ============================================================
                    const COLORS = {
                    vpc: '#818cf8', subnet: '#22d3ee', ec2: '#34d399', stopped: '#f43f5e',
                    nat: '#fbbf24', igw: '#c084fc', rt: '#94a3b8', sg: '#f472b6'
                    };
                    const shortId = (id) => id.length > 14 ? id.slice(0, 6) + '…' + id.slice(-4) : id;

                    function showTooltip(e, html) {
                    const tt = document.getElementById('tooltip');
                    tt.innerHTML = html;
                    tt.style.left = e.clientX + 'px';
                    tt.style.top = (e.clientY - 8) + 'px';
                    tt.classList.add('show');
                    }
                    function hideTooltip() {
                    document.getElementById('tooltip').classList.remove('show');
                    }

                    function svgEl(tag, attrs = {}, parent) {
                    const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
                    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
                    if (parent) parent.appendChild(el);
                    return el;
                    }

                    // ============================================================
                    // Alpine: dashboard component
                    // ============================================================
                    function dashboard() {
                    return {
                    activeTab: 'summary',
                    searchQuery: '',
                    envFilter: 'all',
                    data: {
                    region: '', updatedAt: '',
                    ec2_running_detail: {}, ec2_stopped_ids: [],
                    vpc_details: {}, subnet_details: {}, route_table_details: {},
                    internet_gateways: {}, nat_gateways: {}, security_groups: {},
                    network_topology: {}
                    },
                    tabs: [
                    { id: 'summary', label: 'Summary', icon: 'fa-chart-pie' },
                    { id: 'ec2', label: 'EC2 Instances', icon: 'fa-server' },
                    { id: 'topology', label: 'Topology', icon: 'fa-network-wired' },
                    { id: 'gateways', label: 'Routing & Gateways', icon: 'fa-route' },
                    { id: 'security', label: 'Security Groups', icon: 'fa-shield-halved' },
                    ],
                    legendItems: [
                    { label: 'VPC', color: COLORS.vpc },
                    { label: 'Subnet', color: COLORS.subnet },
                    { label: 'EC2', color: COLORS.ec2 },
                    { label: 'IGW', color: COLORS.igw },
                    { label: 'NAT', color: COLORS.nat },
                    { label: 'Route', color: COLORS.rt },
                    { label: 'SG', color: COLORS.sg },
                    ],

                    init() {
                    this.loadData();
                    this.$watch('activeTab', (t) => {
                    this.$nextTick(() => {
                    if (t === 'topology') this.renderTopology();
                    if (t === 'gateways') this.renderRouteFlow();
                    });
                    });
                    },

                    loadData() {
                    const raw = document.getElementById('infra-data').textContent.trim();
                    try {
                    const j = JSON.parse(raw);
                    this.data = {
                    ec2_running_detail: j.ec2_running_detail || {},
                    ec2_stopped_ids: j.ec2_stopped_ids || [],
                    vpc_details: j.vpc_details || {},
                    subnet_details: j.subnet_details || {},
                    route_table_details: j.route_table_details || {},
                    internet_gateways: j.internet_gateways || {},
                    nat_gateways: j.nat_gateways || {},
                    security_groups: j.security_groups || {},
                    network_topology: j.network_topology || {},
                    region: j.region || 'unknown',
                    updatedAt: this.formatTime(j.updated_at || ''),
                    };
                    } catch (e) {
                    console.error('Failed to parse infra data', e);
                    }
                    },

                    formatTime(raw) {
                    if (!raw) return 'unknown';
                    try {
                    const d = new Date(raw);
                    if (isNaN(d)) return raw;
                    return d.toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
                    } catch { return raw; }
                    },

                    get environments() {
                    const set = new Set();
                    Object.values(this.data.ec2_running_detail).forEach(i => set.add(i.environment || 'untagged'));
                    return [...set].sort();
                    },

                    get instances() {
                    const run = Object.entries(this.data.ec2_running_detail).map(([id, i]) => ({
                    id, running: true, name: i.name || id, environment: i.environment || 'untagged',
                    role: i.role || 'untagged', private_ip: i.private_ip || 'N/A',
                    public_ip: i.public_ip || 'No Public IP', instance_type: i.instance_type || 'N/A',
                    availability_zone: i.availability_zone || 'N/A'
                    }));
                    const stop = this.data.ec2_stopped_ids.map(id => ({
                    id, running: false, name: id, environment: 'untagged', role: 'unknown',
                    private_ip: 'Offline', public_ip: 'No Public IP', instance_type: 'unknown',
                    availability_zone: 'unknown'
                    }));
                    return [...run, ...stop];
                    },

                    get filteredInstances() {
                    const q = this.searchQuery.toLowerCase();
                    return this.instances.filter(i => {
                    const envOk = this.envFilter === 'all' || i.environment === this.envFilter;
                    const qOk = !q || i.id.toLowerCase().includes(q) || (i.name || '').toLowerCase().includes(q);
                    return envOk && qOk;
                    });
                    },

                    get statCards() {
                    const d = this.data;
                    return [
                    { label: 'Running EC2', value: Object.keys(d.ec2_running_detail).length, icon: 'fa-circle-play',
                    badge: 'bg-emerald-500/10 text-emerald-300 border-emerald-500/25' },
                    { label: 'Stopped EC2', value: d.ec2_stopped_ids.length, icon: 'fa-circle-stop', badge:
                    'bg-rose-500/10 text-rose-300 border-rose-500/25' },
                    { label: 'VPCs', value: Object.keys(d.vpc_details).length, icon: 'fa-circle-nodes', badge:
                    'bg-indigo-500/10 text-indigo-300 border-indigo-500/25' },
                    { label: 'Subnets', value: Object.keys(d.subnet_details).length, icon: 'fa-diagram-project', badge:
                    'bg-cyan-500/10 text-cyan-300 border-cyan-500/25' },
                    { label: 'Route Tables', value: Object.keys(d.route_table_details).length, icon: 'fa-route', badge:
                    'bg-slate-500/10 text-slate-300 border-slate-500/25' },
                    { label: 'NAT Gateways', value: Object.keys(d.nat_gateways).length, icon: 'fa-network-wired', badge:
                    'bg-amber-500/10 text-amber-300 border-amber-500/25' },
                    { label: 'Internet GW', value: Object.keys(d.internet_gateways).length, icon: 'fa-globe', badge:
                    'bg-violet-500/10 text-violet-300 border-violet-500/25' },
                    { label: 'Security Groups', value: Object.keys(d.security_groups).length, icon: 'fa-shield-halved',
                    badge: 'bg-fuchsia-500/10 text-fuchsia-300 border-fuchsia-500/25' },
                    ];
                    },

                    get contextItems() {
                    const d = this.data;
                    return [
                    { label: 'AWS Region', value: d.region, icon: 'fa-location-dot' },
                    { label: 'Subnets', value: Object.keys(d.subnet_details).length, icon: 'fa-diagram-project' },
                    { label: 'Route Tables', value: Object.keys(d.route_table_details).length, icon: 'fa-route' },
                    { label: 'Security Groups', value: Object.keys(d.security_groups).length, icon: 'fa-shield-halved'
                    },
                    ];
                    },

                    get allSubnets() {
                    return Object.entries(this.data.subnet_details).map(([id, s]) => ({
                    id, ...s, shortId: shortId(id)
                    })).sort((a, b) => a.cidr_block.localeCompare(b.cidr_block));
                    },

                    // ---------- TOPOLOGY SVG ----------
                    renderTopology() {
                    const wrap = document.getElementById('topology-svg-wrap');
                    if (!wrap) return;
                    wrap.innerHTML = '';

                    const data = this.data;
                    const vpcIds = Object.keys(data.network_topology);
                    if (vpcIds.length === 0) {
                    wrap.innerHTML = '<p class="text-center text-slate-500 py-12 text-sm">No VPC data.</p>';
                    return;
                    }

                    const W = Math.max(1100, wrap.clientWidth || 1100);
                    const vpcCount = vpcIds.length;
                    const sectionW = W / vpcCount;
                    const H = 560;
                    const svg = svgEl('svg', { width: '100%', viewBox: `0 0 ${W} ${H}`, preserveAspectRatio: 'xMidYMid meet' });
                    svg.style.minWidth = '900px';

                    // defs: glow filters keyed by color name
                    const defs = svgEl('defs', {}, svg);
                    const glowSet = ['vpc', 'subnet', 'ec2', 'nat', 'igw', 'stopped'];
                    glowSet.forEach(name => {
                    const col = COLORS[name];
                    const f = svgEl('filter', { id: `glow-${name}`, x: '-60%', y: '-60%', width: '220%', height: '220%' }, defs);
                    svgEl('feGaussianBlur', { stdDeviation: '3.5', result: 'b' }, f);
                    const m = svgEl('feMerge', {}, f);
                    svgEl('feMergeNode', { in: 'b' }, m);
                    svgEl('feMergeNode', { in: 'SourceGraphic' }, m);
                    });

                    const linkLayer = svgEl('g', { fill: 'none' }, svg);
                    const nodeLayer = svgEl('g', {}, svg);

                    vpcIds.forEach((vpcId, vi) => {
                    const vpc = data.network_topology[vpcId];
                    const cx = sectionW * vi + sectionW / 2;
                    const cy = 290;

                    // IGW node
                    const igwEntry = Object.entries(data.internet_gateways).find(([vid]) => vid === vpcId);
                    const igw = igwEntry ? igwEntry[1] : null;
                    if (igw) {
                    const ix = cx, iy = cy - 160;
                    this.topoNode(nodeLayer, ix, iy, 'igw', 'globe', shortId(igw.igw_id),
                    `Internet Gateway\n${igw.igw_id}\nstate: ${igw.state}`, 15, true);
                    svgEl('line', { x1: ix, y1: iy, x2: cx, y2: cy, stroke: COLORS.igw, 'stroke-width': '1.8', opacity:
                    '0.7' }, linkLayer);
                    }

                    // VPC node (center)
                    this.topoNode(nodeLayer, cx, cy, 'vpc', 'circle-nodes', vpcId,
                    `VPC\n${vpcId}\nCIDR ${vpc.cidr_block}${vpc.is_default ? ' (default)' : ''}`, 28, true);

                    // NAT nodes
                    const nats = Object.entries(data.nat_gateways).filter(([_, n]) => n.vpc_id === vpcId && n.state ===
                    'available');

                    // Subnets ring
                    const subnetIds = Object.keys(vpc.subnets);
                    const ringR = 135;
                    const subPos = {};
                    subnetIds.forEach((sid, i) => {
                    const ang = (i / subnetIds.length) * Math.PI * 2 - Math.PI / 2;
                    const sx = cx + Math.cos(ang) * ringR;
                    const sy = cy + Math.sin(ang) * ringR * 0.7;
                    subPos[sid] = { x: sx, y: sy };
                    this.topoNode(nodeLayer, sx, sy, 'subnet', 'diagram-project', shortId(sid),
                    `Subnet ${sid}\nCIDR ${vpc.subnets[sid].cidr_block}\n${vpc.subnets[sid].availability_zone} ·
                    ${vpc.subnets[sid].available_ips} IPs · ${vpc.subnets[sid].is_public ? 'Public' : 'Private'}`,
                    12);
                    svgEl('line', { x1: cx, y1: cy, x2: sx, y2: sy, stroke: COLORS.subnet, 'stroke-width': '1.1', opacity: '0.55' }, linkLayer);
                    });

                    // NAT nodes positioned near top between IGW and VPC
                    nats.forEach(([natId, nat], i) => {
                    const nx = cx - 70 + i * 140;
                    const ny = cy - 95;
                    this.topoNode(nodeLayer, nx, ny, 'nat', 'network-wired', shortId(natId),
                    `NAT ${natId}\n${nat.public_ip} · ${nat.state}\nsubnet ${shortId(nat.subnet_id)}`, 13);
                    svgEl('line', { x1: nx, y1: ny, x2: cx, y2: cy, stroke: COLORS.nat, 'stroke-width': '1.5', opacity: '0.75' }, linkLayer);
                    if (subPos[nat.subnet_id]) {
                    svgEl('line', { x1: nx, y1: ny, x2: subPos[nat.subnet_id].x, y2: subPos[nat.subnet_id].y,
                    stroke: COLORS.nat, 'stroke-width': '1', 'stroke-dasharray': '3 4', opacity: '0.5' }, linkLayer);
                    }
                    });

                    // EC2 nodes — attach each running instance to first subnet (data lacks subnet-id mapping on
                    // instance)
                    const ec2s = Object.entries(data.ec2_running_detail);
                    ec2s.forEach(([iid, inst], i) => {
                    const sid = subnetIds[0];
                    if (!subPos[sid]) return;
                    const p = subPos[sid];
                    const ex = p.x + 42;
                    const ey = p.y + 36;
                    this.topoNode(nodeLayer, ex, ey, 'ec2', 'server', shortId(iid),
                    `EC2 ${iid}\n${inst.instance_type} · ${inst.private_ip}\n${inst.availability_zone}`, 9);
                    svgEl('line', { x1: p.x, y1: p.y, x2: ex, y2: ey, stroke: COLORS.ec2, 'stroke-width': '1', opacity: '0.55' }, linkLayer);
                    });
                    });

                    // Title
                    svgEl('text', { x: 20, y: 28, fill: '#cbd5e1', 'font-size': '13', 'font-weight': '600',
                    'font-family': 'Outfit' }, svg)
                    .textContent = 'Network Topology — ' + vpcIds.length + ' VPC' + (vpcIds.length > 1 ? 's' : '');

                    wrap.appendChild(svg);
                    },

                    topoNode(layer, x, y, type, faIcon, label, tooltip, r = 13, pulse = false) {
                    const color = COLORS[type] || COLORS.rt;
                    const g = svgEl('g', { transform: `translate(${x} ${y})`, style: 'cursor: pointer' }, layer);
                    if (pulse) g.setAttribute('class', 'pulse-node');

                    // outer glow disc
                    svgEl('circle', { r: r + 6, fill: color, opacity: '0.12' }, g);
                    // main circle
                    svgEl('circle', { r, fill: '#0b1020', stroke: color, 'stroke-width': '1.8', filter:
                    `url(#glow-${type})` }, g);
                    // icon
                    const fo = svgEl('foreignObject', { x: -10, y: -10, width: 20, height: 20 }, g);
                    const span = document.createElement('span');
                    span.style.cssText =
                    'display:flex;align-items:center;justify-content:center;width:20px;height:20px;color:' + color +
                    ';font-size:11px;';
                    span.innerHTML = `<i class="fa-solid ${faIcon}"></i>`;
                    fo.appendChild(span);

                    const t = svgEl('text', { y: r + 14, 'text-anchor': 'middle', fill: '#94a3b8', 'font-size': '9',
                    'font-family': 'JetBrains Mono, monospace' }, g);
                    t.textContent = label;

                    g.addEventListener('mousemove', (e) => showTooltip(e, tooltip.split('\n').map(s => `<div>${s}</div>
                    `).join('')));
                    g.addEventListener('mouseleave', hideTooltip);
                    return g;
                    },

                    // ---------- ROUTE FLOW SVG ----------
                    renderRouteFlow() {
                    const wrap = document.getElementById('route-flow-wrap');
                    if (!wrap) return;
                    wrap.innerHTML = '';

                    const data = this.data;
                    const rtEntries = Object.entries(data.route_table_details);
                    if (rtEntries.length === 0) {
                    wrap.innerHTML = '<p class="text-center text-slate-500 py-12 text-sm">No route tables.</p>';
                    return;
                    }

                    // Columnar left → right flow: Source | Route Table | Target | Exit
                    const cols = ['Source', 'Route Table', 'Target', 'Exit'];
                    const colX = [80, 380, 720, 1000];
                    const rowH = 80;
                    const padTop = 64;
                    const W = 1120;
                    const H = padTop + rtEntries.length * rowH + 24;

                    const svg = svgEl('svg', { width: '100%', viewBox: `0 0 ${W} ${H}`, preserveAspectRatio: 'xMidYMid meet' });
                    svg.style.minWidth = '1000px';

                    const linkLayer = svgEl('g', { fill: 'none' }, svg);
                    const nodeLayer = svgEl('g', {}, svg);

                    // Header row
                    cols.forEach((c, i) => {
                    svgEl('text', { x: colX[i], y: 30, fill: '#64748b', 'font-size': '11', 'font-weight': '600',
                    'letter-spacing': '1.5' }, svg).textContent = c.toUpperCase();
                    });
                    svgEl('line', { x1: 30, y1: 46, x2: W - 30, y2: 46, stroke: '#1e293b', 'stroke-width': '1' }, svg);

                    rtEntries.forEach(([rtId, rt], idx) => {
                    const y = padTop + idx * rowH + rowH / 2;
                    const defRoute = rt.routes.find(r => r.destination === '0.0.0.0/0') || rt.routes[0];
                    const target = defRoute ? defRoute.target : 'local';

                    let targetType, targetColor, targetIcon, targetLabel, exitLabel, exitIcon;
                    if (target.indexOf('igw-') === 0) {
                    targetType = 'igw'; targetColor = COLORS.igw; targetIcon = 'globe'; targetLabel = 'IGW';
                    const igw = Object.values(data.internet_gateways).find(g => g.igw_id === target);
                    exitLabel = igw ? 'Internet' : target; exitIcon = 'cloud';
                    } else if (target.indexOf('nat-') === 0) {
                    targetType = 'nat'; targetColor = COLORS.nat; targetIcon = 'network-wired'; targetLabel = 'NAT';
                    const nat = data.nat_gateways[target];
                    exitLabel = nat ? (nat.public_ip || 'Internet') : target; exitIcon = 'globe';
                    } else {
                    targetType = 'rt'; targetColor = COLORS.rt; targetIcon = 'circle-nodes'; targetLabel = 'Local';
                    exitLabel = 'VPC'; exitIcon = 'circle';
                    }

                    const srcLabel = rt.associations > 0 ? `${rt.associations} subnet${rt.associations === 1 ? '' : 's'}` : 'no assoc.';
                    this.flowNode(nodeLayer, colX[0], y, COLORS.subnet, 'network-wired', srcLabel,
                    `Route table ${rtId}\nAssociated: ${rt.associations} subnet(s)`);
                    this.flowNode(nodeLayer, colX[1], y, COLORS.rt, 'route', shortId(rtId),
                    `${rtId}${rt.is_main ? ' (Main)' : ''}\n${rt.routes.length} route(s)`);
                    this.flowNode(nodeLayer, colX[2], y, targetColor, targetIcon, targetLabel,
                    `Target: ${target}\nType: ${targetType.toUpperCase()}`);
                    this.flowNode(nodeLayer, colX[3], y, targetColor, exitIcon,
                    exitLabel.length > 14 ? shortId(exitLabel) : exitLabel, exitLabel);

                    const linkColor = targetType === 'igw' ? COLORS.igw : (targetType === 'nat' ? COLORS.nat :
                    COLORS.rt);
                    this.flowLink(linkLayer, colX[0] + 40, y, colX[1] - 40, y, '#475569', false, '');
                    this.flowLink(linkLayer, colX[1] + 40, y, colX[2] - 40, y, linkColor, true, defRoute ?
                    defRoute.destination : '');
                    this.flowLink(linkLayer, colX[2] + 40, y, colX[3] - 40, y, linkColor, true, '');
                    });

                    wrap.appendChild(svg);
                    },

                    flowNode(layer, x, y, color, faIcon, label, tooltip, w = 78) {
                    const g = svgEl('g', { transform: `translate(${x} ${y})`, style: 'cursor: pointer' }, layer);
                    const rect = svgEl('rect', { x: -w/2, y: -19, width: w, height: 38, rx: 10, fill: '#0b1020', stroke: color, 'stroke-width': '1.6' }, g);
                    rect.style.filter = `drop-shadow(0 0 6px ${color}88)`;

                    const fo = svgEl('foreignObject', { x: -w/2 + 6, y: -8, width: w - 12, height: 16 }, g);
                    const span = document.createElement('span');
                    span.style.cssText =
                    'display:flex;align-items:center;justify-content:center;width:100%;height:16px;color:' + color +
                    ';font-size:11px;';
                    span.innerHTML = `<i class="fa-solid ${faIcon}"></i>`;
                    fo.appendChild(span);

                    const t = svgEl('text', { y: 30, 'text-anchor': 'middle', fill: '#cbd5e1', 'font-size': '9.5',
                    'font-family': 'JetBrains Mono, monospace' }, g);
                    t.textContent = label.length > 16 ? label.slice(0, 14) + '…' : label;

                    g.addEventListener('mousemove', (e) => showTooltip(e, tooltip.split('\n').map(s => `<div>${s}</div>
                    `).join('')));
                    g.addEventListener('mouseleave', hideTooltip);
                    return g;
                    },

                    flowLink(layer, x1, y1, x2, y2, color, animated, label) {
                    const path = svgEl('path', {
                    d: `M ${x1} ${y1} C ${(x1+x2)/2} ${y1}, ${(x1+x2)/2} ${y2}, ${x2} ${y2}`,
                    stroke: color, 'stroke-width': '1.8', fill: 'none', opacity: '0.9'
                    }, layer);
                    if (animated) {
                    path.setAttribute('class', 'flow-line');
                    path.style.filter = `drop-shadow(0 0 4px ${color}aa)`;
                    }
                    if (label) {
                    const t = svgEl('text', { x: (x1+x2)/2, y: y1 - 8, fill: '#64748b', 'font-size': '9', 'text-anchor':
                    'middle', 'font-family': 'JetBrains Mono, monospace' }, layer);
                    t.textContent = label;
                    }
                    },
                    };
                    }
                    