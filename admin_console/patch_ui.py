import re

with open('index.html', 'r') as f:
    content = f.read()

# 1. Update Cards CSS
content = re.sub(
    r'\.rounded-xl\.bg-white, \.rounded-2xl\.bg-white \{\n[^\}]+box-shadow: var\(--shadow-card\);\n[^\}]+\}',
    r'''.rounded-xl.bg-white, .rounded-2xl.bg-white {
    background: #1A1A24 !important;
    box-shadow: none;
    border: 1px solid #2A2A3A !important;
    border-radius: 12px;
  }''', content
)

# 2. Update Sidebar CSS
content = re.sub(
    r'\.nav-link \{\n    color: var\(--text-mute\) !important;\n    position: relative;\n    transition: background 0\.18s, color 0\.18s;\n  \}',
    r'''.nav-link {
    color: var(--text-mute) !important;
    position: relative;
    transition: background 0.18s, color 0.18s;
    margin: 4px 16px;
    border-radius: 8px;
  }''', content
)

content = re.sub(
    r'\.nav-link\.active \{\n    background: linear-gradient[^}]+;\n    color: var\(--accent\) !important;\n    border-left: 3px solid var\(--accent\) !important;\n  \}',
    r'''.nav-link.active {
    background: linear-gradient(90deg, #7C3AED 0%, #4C1D95 100%) !important;
    color: #FFFFFF !important;
    border: none !important;
    box-shadow: 0 4px 12px rgba(124,58,237,0.3);
  }''', content
)

content = re.sub(
    r'\.nav-link\.active::before \{\n    content: [^}]+;\n  \}',
    r'''.nav-link.active::before { display: none; }''', content
)

# Update nav-link active override
content = re.sub(
    r'\/\* Nav-link override[^\n]*\n[^\n]+',
    r'/* Nav-link override */\n  .nav-link.active { background: linear-gradient(90deg, #7C3AED 0%, #4C1D95 100%) !important; color: #FFFFFF !important; border: none !important; }', content
)


# 3. Update Sidebar footer
content = re.sub(
    r'<div class="p-4 border-t">\n      <div class="flex items-center gap-3 mb-3">[\s\S]+?<\/div>\n  <\/aside>',
    r'''<div class="p-6 border-t border-[#2A2A3A] mt-auto">
      <div class="flex flex-col gap-1 items-start">
        <div class="flex items-center gap-2">
          <img src="assets/mahacybersafe_shield.png" class="w-6 h-6 object-contain" />
          <img src="assets/virtual_galaxy_logo.png" class="h-4 object-contain" style="filter: drop-shadow(0 2px 4px rgba(124,58,237,0.4)); opacity: 0.9;" />
        </div>
        <div class="text-[10px] text-slate-400 mt-1 pl-8">drop shadow</div>
      </div>
    </div>
  </aside>''', content
)

# 4. Update Header
content = re.sub(
    r'<header class="bg-white border-b border-slate-200 px-8 py-4 flex justify-between items-center flex-shrink-0">[\s\S]+?<\/header>',
    r'''<header class="bg-[#1A1A24] border-b border-[#2A2A3A] px-8 py-5 flex justify-between items-center flex-shrink-0">
      <div>
        <h2 id="pageTitle" class="text-2xl font-semibold text-white" style="line-height: 1.15;">Dashboard Page</h2>
      </div>
      <div class="flex items-center gap-4">
        <div class="w-9 h-9 rounded bg-[#1A1A24] flex items-center justify-center cursor-pointer border border-[#2A2A3A]">
          <svg class="w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
        </div>
        <div class="w-9 h-9 rounded bg-[#1A1A24] flex items-center justify-center cursor-pointer border border-[#2A2A3A]">
          <svg class="w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/></svg>
        </div>
      </div>
    </header>''', content
)

# 5. Dashboard JS Updates
dashboard_code = '''function renderDashboard(c) {
  c.innerHTML = `
    <div class="grid grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-xl p-5 border border-slate-200">
        <div class="text-sm font-medium text-slate-300">Registered Devices</div>
        <div class="text-4xl mt-2 mb-1 text-white font-semibold">8.5M</div>
        <div class="text-xs text-[#06B6D4] font-mono mt-2">JetBrains Mono</div>
      </div>
      <div class="bg-white rounded-xl p-5 border border-slate-200">
        <div class="text-sm font-medium text-slate-300">Threats Reported</div>
        <div class="text-4xl mt-2 mb-1 text-white font-semibold">3,531</div>
        <div class="text-xs text-[#F87171] mt-2">Threats Reported</div>
      </div>
      <div class="bg-white rounded-xl p-5 border border-slate-200">
        <div class="text-sm font-medium text-slate-300">URL/QR Scans (7d)</div>
        <div class="text-4xl mt-2 mb-1 text-white font-semibold">7d</div>
        <div class="text-xs text-[#06B6D4] font-mono mt-2">JetBrains Mono</div>
      </div>
      <div class="bg-white rounded-xl p-5 border border-slate-200">
        <div class="text-sm font-medium text-slate-300">Open SOS Incidents</div>
        <div class="text-4xl mt-2 mb-1 text-white font-semibold">0</div>
        <div class="text-xs text-[#F87171] mt-2">Open SOS Incidents</div>
      </div>
    </div>
    
    <div class="grid grid-cols-3 gap-4 mb-6">
      <div class="col-span-2 bg-white rounded-xl p-5 border border-slate-200 h-64">
        <h3 class="text-sm text-slate-300 mb-4">Scan Trend</h3>
        <canvas id="scanChart"></canvas>
      </div>
      <div class="bg-white rounded-xl p-5 border border-slate-200 h-64 flex flex-col">
        <h3 class="text-sm text-slate-300 mb-4">Severity</h3>
        <div class="flex-1 relative">
           <canvas id="severityChart"></canvas>
        </div>
      </div>
    </div>
    
    <div class="bg-white rounded-xl p-5 border border-slate-200">
      <h3 class="text-sm text-slate-300 mb-4">Recent activity</h3>
      <table class="w-full text-sm">
        <thead class="text-xs text-slate-400">
          <tr>
            <th class="pb-3 text-left font-normal">Mone</th>
            <th class="pb-3 text-left font-normal">Mono</th>
            <th class="pb-3 text-left font-normal">JetBrains</th>
            <th class="pb-3 text-left font-normal">Mono Date</th>
            <th class="pb-3 text-left font-normal">Columns</th>
          </tr>
        </thead>
        <tbody class="text-slate-300">
          <tr class="border-t border-[#2A2A3A]">
            <td class="py-3">Registered Devices</td>
            <td><span class="bg-[#06B6D420] text-[#06B6D4] text-xs px-2 py-1 rounded-full border border-[#06B6D440]">● Ocolain</span></td>
            <td class="font-mono text-xs">88.7S9.844</td>
            <td class="text-xs">Nov 16, 2023</td>
            <td class="text-xs">2 minutes ago</td>
          </tr>
          <tr class="border-t border-[#2A2A3A]">
            <td class="py-3">Threats Reported</td>
            <td><span class="bg-[#F8717120] text-[#F87171] text-xs px-2 py-1 rounded-full border border-[#F8717140]">● Prexsia</span></td>
            <td class="font-mono text-xs">360.7/15.3531</td>
            <td class="text-xs">Nov 16, 2023</td>
            <td class="text-xs">4 minutes ago</td>
          </tr>
          <tr class="border-t border-[#2A2A3A]">
            <td class="py-3">URL/QR Scans (7d)</td>
            <td><span class="bg-[#F8717120] text-[#F87171] text-xs px-2 py-1 rounded-full border border-[#F8717140]">● BasciK</span></td>
            <td class="font-mono text-xs">7d. 7d</td>
            <td class="text-xs">Nov 16, 2024</td>
            <td class="text-xs">4 minutes ago</td>
          </tr>
        </tbody>
      </table>
    </div>
  `;
  
  const scanCtx = document.getElementById('scanChart').getContext('2d');
  const gradient = scanCtx.createLinearGradient(0, 0, 0, 200);
  gradient.addColorStop(0, 'rgba(124, 58, 237, 0.4)');
  gradient.addColorStop(1, 'rgba(124, 58, 237, 0.0)');
  
  new Chart(scanCtx, {
    type: 'line',
    data: {
      labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'],
      datasets: [{
        label: 'Scan Trend',
        data: [10, 35, 30, 45, 90, 60, 45, 90],
        borderColor: '#06B6D4',
        backgroundColor: gradient,
        borderWidth: 2,
        tension: 0.4,
        fill: true,
        pointRadius: 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: '#2A2A3A', drawBorder: false }, ticks: { color: '#7A7393', font: { size: 10 } } },
        y: { min: 0, max: 100, ticks: { stepSize: 20, color: '#7A7393', font: { size: 10 } }, grid: { color: '#2A2A3A', drawBorder: false } }
      }
    }
  });
  
  new Chart(document.getElementById('severityChart'), {
    type: 'doughnut',
    data: {
      labels: ['Dagend (0cart)', 'Severity', 'Doughhut Chart', 'Other'],
      datasets: [{
        data: [45, 30, 15, 10],
        backgroundColor: ['#06B6D4', '#64748B', '#F87171', '#FBBF24'],
        borderWidth: 0,
        cutout: '65%'
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      layout: { padding: 0 },
      plugins: {
        legend: {
          position: 'right',
          labels: {
            color: '#FFFFFF',
            font: { size: 11 },
            usePointStyle: true,
            boxWidth: 8
          }
        }
      }
    }
  });
}'''

content = re.sub(
    r'function renderDashboard\(c\) \{[\s\S]+?\}\n\nfunction renderUsers',
    dashboard_code + '\n\nfunction renderUsers',
    content
)

# 6. Update Footer
content = re.sub(
    r'<footer class="admin-footer flex-shrink-0">[\s\S]+?<\/footer>',
    r'''<footer class="flex-shrink-0" style="position: relative; padding: 12px 32px; display: flex; align-items: center; justify-content: flex-end; font-size: 11px; color: #7A7393;">
      <div style="position: absolute; top: 0; left: 0; right: 0; height: 1px; background: linear-gradient(90deg, transparent, rgba(124,58,237,0.8), transparent);"></div>
      <div>Date 15, 2021</div>
    </footer>''', content
)

with open('index.html', 'w') as f:
    f.write(content)

print("Patch applied")
