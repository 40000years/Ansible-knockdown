import re

with open("dashboard_template.html", "r", encoding="utf-8") as f:
    text = f.read()

replacement = """                    <!-- IGW -->
                    <div class="glass p-5 rounded-2xl relative overflow-hidden group">
                        <div class="flex items-center space-x-3 mb-4">
                            <div class="p-2 bg-violet-500/10 text-violet-300 rounded-lg border border-violet-500/20">
                                <i class="fa-solid fa-globe"></i>
                            </div>
                            <h4 class="text-sm font-semibold text-white">Internet Gateways</h4>
                        </div>
                        <ul class="space-y-2">
                            <template x-for="(igw, id) in data.internet_gateways" :key="id">
                                <li class="flex items-center justify-between text-[12px] bg-slate-900/40 p-2.5 rounded-lg border border-slate-700/50">
                                    <span class="text-slate-300 font-mono" x-text="igw.igw_id"></span>
                                    <span class="text-emerald-400 font-medium bg-emerald-400/10 px-2 py-0.5 rounded text-[10px]" x-text="igw.state"></span>
                                </li>
                            </template>
                            <template x-if="Object.keys(data.internet_gateways).length === 0">
                                <li class="text-xs text-slate-500 text-center py-2">No Internet Gateways</li>
                            </template>
                        </ul>
                    </div>

                    <!-- NAT -->
                    <div class="glass p-5 rounded-2xl relative overflow-hidden group">
                        <div class="flex items-center space-x-3 mb-4">
                            <div class="p-2 bg-amber-500/10 text-amber-300 rounded-lg border border-amber-500/20">
                                <i class="fa-solid fa-network-wired"></i>
                            </div>
                            <h4 class="text-sm font-semibold text-white">NAT Gateways</h4>
                        </div>
                        <ul class="space-y-2">
                            <template x-for="(nat, id) in data.nat_gateways" :key="id">
                                <li class="flex flex-col gap-1 text-[12px] bg-slate-900/40 p-2.5 rounded-lg border border-slate-700/50">
                                    <div class="flex items-center justify-between">
                                        <span class="text-slate-300 font-mono" x-text="id"></span>
                                        <span class="text-emerald-400 font-medium bg-emerald-400/10 px-2 py-0.5 rounded text-[10px]" x-text="nat.state"></span>
                                    </div>
                                    <div class="flex items-center text-slate-400 text-[11px] gap-3 mt-1">
                                        <span><i class="fa-solid fa-globe text-slate-500 mr-1"></i><span x-text="nat.public_ip"></span></span>
                                        <span><i class="fa-solid fa-diagram-project text-slate-500 mr-1"></i><span x-text="shortId(nat.subnet_id)"></span></span>
                                    </div>
                                </li>
                            </template>
                            <template x-if="Object.keys(data.nat_gateways).length === 0">
                                <li class="text-xs text-slate-500 text-center py-2">No NAT Gateways</li>
                            </template>
                        </ul>
                    </div>
                </div>
            </section>

            <!-- =================== SECURITY GROUPS =================== -->
            <section x-show="activeTab === 'security'" x-cloak class="fade-up">
                <div class="glass-strong rounded-2xl overflow-hidden">
                    <div class="px-6 py-5 border-b border-slate-800/70 flex items-center justify-between">
                        <div>
                            <h3 class="text-base font-bold text-white flex items-center gap-2">
                                <i class="fa-solid fa-shield-halved text-fuchsia-300"></i> Security Groups
                            </h3>
                            <p class="text-xs text-slate-400 mt-1">Network firewalls attached to VPCs and instances.</p>
                        </div>
                        <span class="text-2xl opacity-10 text-fuchsia-300"><i class="fa-solid fa-shield-halved"></i></span>
                    </div>
                    <div class="overflow-x-auto scroll-area">
                        <table class="min-w-full divide-y divide-slate-800/70">
                            <thead class="bg-slate-900/40">
                                <tr>
                                    <th class="px-6 py-3 text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Group Name & ID</th>
                                    <th class="px-6 py-3 text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider">VPC ID</th>
                                    <th class="px-6 py-3 text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Description</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-800/70 bg-slate-950/20">
                                <template x-for="(sg, id) in data.security_groups" :key="id">
                                    <tr class="hover:bg-fuchsia-500/5 transition-colors">
                                        <td class="px-6 py-3 whitespace-nowrap">
                                            <div class="flex flex-col">
                                                <span class="text-sm font-semibold text-white" x-text="sg.name"></span>
                                                <span class="text-[11px] text-slate-500 font-mono mt-0.5" x-text="id"></span>
                                            </div>
                                        </td>
                                        <td class="px-6 py-3 whitespace-nowrap">
                                            <span class="inline-flex items-center px-2 py-0.5 rounded bg-indigo-500/10 text-indigo-300 text-[11px] font-medium border border-indigo-500/20 font-mono" x-text="sg.vpc_id"></span>
                                        </td>
                                        <td class="px-6 py-3">
                                            <span class="text-[12px] text-slate-300" x-text="sg.description"></span>
                                        </td>
                                    </tr>
                                </template>
                            </tbody>
                        </table>
                    </div>
                </div>
            </section>

        </main>
        
        <!-- Footer -->
        <footer class="border-t border-slate-800/70 py-6 text-center mt-auto relative z-10 glass">
            <p class="text-[11px] text-slate-500">
                Generated by Terraform &bull; AWS Infrastructure Topology
            </p>
        </footer>
    </div>

    <!-- THREE.JS BACKGROUND -->
    <script>
        const canvas = document.getElementById('bg-canvas');
        const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 1000);
        camera.position.z = 15;

        // Particles
        const geom = new THREE.BufferGeometry();
        const count = 300;
        const pos = new Float32Array(count * 3);
        const colors = new Float32Array(count * 3);
        
        const palette = [
            new THREE.Color('#4f46e5'),
            new THREE.Color('#06b6d4'),
            new THREE.Color('#8b5cf6')
        ];

        for(let i=0; i<count*3; i+=3) {
            pos[i] = (Math.random() - 0.5) * 40;
            pos[i+1] = (Math.random() - 0.5) * 40;
            pos[i+2] = (Math.random() - 0.5) * 20;

            const c = palette[Math.floor(Math.random() * palette.length)];
            colors[i] = c.r;
            colors[i+1] = c.g;
            colors[i+2] = c.b;
        }
        geom.setAttribute('position', new THREE.BufferAttribute(pos, 3));
        geom.setAttribute('color', new THREE.BufferAttribute(colors, 3));

        const mat = new THREE.PointsMaterial({
            size: 0.15,
            vertexColors: true,
            transparent: true,
            opacity: 0.6,
            blending: THREE.AdditiveBlending
        });

        const particles = new THREE.Points(geom, mat);
        scene.add(particles);

        let mouseX = 0;
        let mouseY = 0;
        document.addEventListener('mousemove', (e) => {
            mouseX = (e.clientX / window.innerWidth) - 0.5;
            mouseY = (e.clientY / window.innerHeight) - 0.5;
        });

        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });

        const clock = new THREE.Clock();
        function animate() {
            requestAnimationFrame(animate);
            const time = clock.getElapsedTime();
            
            particles.rotation.y = time * 0.05 + (mouseX * 0.2);
            particles.rotation.x = (mouseY * 0.2);
            
            const positions = particles.geometry.attributes.position.array;
            for(let i=1; i<count*3; i+=3) {
                positions[i] += Math.sin(time * 0.5 + positions[i-1]) * 0.005;
            }
            particles.geometry.attributes.position.needsUpdate = true;

            renderer.render(scene, camera);
        }
        animate();
    </script>

    <script>"""

# Using regex to replace the truncated text and any extra lines around it up to // Helpers
pattern = re.compile(r"Diff preview truncated: 246 lines omitted to keep UI responsive\.\s+// ============================================================\s+// Helpers", re.MULTILINE)
if pattern.search(text):
    new_text = pattern.sub(replacement + "\n                    // ============================================================\n                    // Helpers", text)
    with open("dashboard_template.html", "w", encoding="utf-8") as f:
        f.write(new_text)
    print("Patch applied successfully.")
else:
    print("Could not find the truncation pattern.")
