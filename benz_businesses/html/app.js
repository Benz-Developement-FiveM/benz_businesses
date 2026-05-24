function getTabletEl() {
    return document.getElementById('tablet');
}

function getAdminPanelEl() {
    return document.getElementById('adminPanel');
}

let current = null;
let adminData = null;
let selectedAdminBusiness = null;
let deliveryTimerInterval = null;
let currentTabletTab = 'dashboard';
let pendingAdminSelectionId = null;
let currentAdminSection = 'settings';

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function money(v) {
    return '$' + Number(v || 0).toLocaleString('en-US');
}

function formatTimer(seconds) {
    seconds = Math.max(0, Number(seconds || 0));
    if (seconds <= 0) return 'Ready';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${String(secs).padStart(2, '0')}`;
}

function qs(id) {
    return document.getElementById(id);
}


function getOpenUiCount() {
    let count = 0;
    const tabletEl = getTabletEl ? getTabletEl() : document.getElementById('tablet');
    const adminEl = getAdminPanelEl ? getAdminPanelEl() : document.getElementById('adminPanel');

    if (tabletEl && !tabletEl.classList.contains('hidden')) count++;
    if (adminEl && !adminEl.classList.contains('hidden')) count++;

    return count;
}

function showTabletOnly() {
    const el = getTabletEl ? getTabletEl() : document.getElementById('tablet');
    if (el) {
        el.classList.remove('hidden');
        el.style.display = 'grid';
    }
}

function hideTabletOnly() {
    const el = getTabletEl ? getTabletEl() : document.getElementById('tablet');
    if (el) {
        el.classList.add('hidden');
        el.style.display = '';
    }
}

function showAdminOnly() {
    const el = getAdminPanelEl ? getAdminPanelEl() : document.getElementById('adminPanel');
    if (el) {
        el.classList.remove('hidden');
        el.style.display = 'grid';
    }
}

function hideAdminOnly() {
    const el = getAdminPanelEl ? getAdminPanelEl() : document.getElementById('adminPanel');
    if (el) {
        el.classList.add('hidden');
        el.style.display = '';
    }
}


function closeTablet() {
    hideTabletOnly();
    post('tabletClose');
}

function closeAdminPanel() {
    hideAdminOnly();
    post('adminClose');
}

function refresh() {
    return post('tabletRefresh');
}

function refreshAdmin() {
    if (selectedAdminBusiness) {
        pendingAdminSelectionId = selectedAdminBusiness.id || selectedAdminBusiness;
    }
    return post('adminRefresh');
}

function startDeliveryTimerRefresh() {
    if (deliveryTimerInterval) clearInterval(deliveryTimerInterval);
    deliveryTimerInterval = setInterval(() => {
        if (getTabletEl() && !getTabletEl().classList.contains('hidden')) refresh();
    }, 15000);
}

/* BUSINESS TABLET */

function render(data) {
    if (!data || !data.business) return;
    current = data;

    const ui = data.business.ui || {};
    document.documentElement.style.setProperty('--primary', ui.primaryColor || '#38bdf8');

    if (qs('businessName')) qs('businessName').textContent = ui.title || `${data.business.label} Tablet`;
    if (qs('businessType')) qs('businessType').textContent = `${data.business.type || 'business'} • ${data.business.job}`;

    renderDashboard(data);
    renderAccounts(data);
    renderEmployees(data);
    renderSupplies(data);
    renderMenu(data);
    renderDj(data);
    renderStations(data);
    renderDeleteStations(data);

    if (currentTabletTab) {
        document.querySelectorAll('#tablet .tab[data-tab]').forEach(b => b.classList.toggle('active', b.dataset.tab === currentTabletTab));
        document.querySelectorAll('#tablet .page').forEach(p => p.classList.remove('active'));
        qs('page-' + currentTabletTab)?.classList.add('active');
    }
}

function renderDashboard(data) {
    if (qs('dashBalance')) qs('dashBalance').textContent = money(data.account?.balance);
    if (qs('dashCash')) qs('dashCash').textContent = money(data.account?.cash);
    if (qs('dashEmployees')) qs('dashEmployees').textContent = (data.employees || []).length;
    if (qs('dashDeliveries')) qs('dashDeliveries').textContent = (data.supply?.orders || []).filter(o => o.status === 'in_transit').length;
}

function renderAccounts(data) {
    const el = qs('transactions');
    if (!el) return;
    el.innerHTML = '';

    for (const tx of data.account?.transactions || []) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${tx.action || ''}</span></div>
            <div><strong>${tx.player_name || 'Unknown'}</strong><div class="note">${tx.note || ''}</div></div>
            <div>${money(tx.amount)}</div>
            <div class="note">${tx.created_at || ''}</div>
        `;
        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No transactions yet.</p>';
}

function fillGrades(select, currentGrade) {
    if (!select) return;
    select.innerHTML = '';

    for (const grade of current?.grades || []) {
        const opt = document.createElement('option');
        opt.value = grade.grade;
        opt.textContent = `${grade.grade} - ${grade.label}`;
        if (Number(currentGrade) === Number(grade.grade)) opt.selected = true;
        select.appendChild(opt);
    }
}

function renderEmployees(data) {
    fillGrades(qs('hireGrade'), 0);

    const el = qs('employees');
    if (!el) return;
    el.innerHTML = '';

    for (const emp of data.employees || []) {
        const row = document.createElement('div');
        row.className = 'row';

        const select = document.createElement('select');
        fillGrades(select, emp.grade);

        const rank = document.createElement('button');
        rank.textContent = 'Set Rank';
        rank.onclick = () => post('setEmployeeRank', { targetId: emp.source, grade: Number(select.value) }).then(refresh);

        const fire = document.createElement('button');
        fire.textContent = 'Fire';
        fire.className = 'danger';
        fire.onclick = () => post('fireEmployee', { targetId: emp.source }).then(refresh);

        row.innerHTML = `
            <div><span class="badge">ID ${emp.source}</span></div>
            <div><strong>${emp.name || 'Unknown'}</strong><div class="note">${emp.gradeLabel || 'Employee'}</div></div>
        `;

        row.appendChild(select);

        const controls = document.createElement('div');
        controls.style.display = 'grid';
        controls.style.gridTemplateColumns = '1fr 1fr';
        controls.style.gap = '6px';
        controls.appendChild(rank);
        controls.appendChild(fire);
        row.appendChild(controls);

        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No online employees found.</p>';
}

function renderSupplies(data) {
    const supplier = qs('supplierItems');
    const orders = qs('orders');
    if (!supplier || !orders) return;

    supplier.innerHTML = '';
    orders.innerHTML = '';

    for (const item of data.supply?.supplierItems || []) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${item.item}</span></div>
            <div><strong>${item.label}</strong><div class="note">Pack gives ${item.amount}</div></div>
            <div>${money(item.price)}</div>
            <input type="number" min="0" value="0" data-supply="${item.item}">
        `;
        supplier.appendChild(row);
    }

    if (!supplier.innerHTML) supplier.innerHTML = '<p class="note">No supply items configured.</p>';

    for (const order of data.supply?.orders || []) {
        const items = (order.items || []).map(i => `${i.amount}x ${i.label || i.item}`).join(', ');
        const ready = order.ready && order.status === 'in_transit';
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">#${order.id}</span></div>
            <div><strong>${items || 'Supplies'}</strong><div class="note">By ${order.ordered_name || 'Unknown'} • ${formatTimer(order.remainingSeconds)}</div></div>
            <div>${money(order.total)}</div>
            <button ${ready ? '' : 'disabled'}>${ready ? 'Claim' : (order.status === 'claimed' ? 'Claimed' : formatTimer(order.remainingSeconds))}</button>
        `;
        row.querySelector('button').onclick = () => post('claimSupplyOrder', { orderId: order.id }).then(refresh);
        orders.appendChild(row);
    }

    if (!orders.innerHTML) orders.innerHTML = '<p class="note">No deliveries yet.</p>';
}

function renderMenu(data) {
    const el = qs('menuStations');
    if (!el) return;
    el.innerHTML = '';

    const stations = (data.menuStations || []).filter(station => !['stash', 'fridge', 'storage'].includes(station.type));

    for (const station of stations) {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<h3>${station.label}</h3>`;

        const add = document.createElement('div');
        add.className = 'menu-add';
        add.innerHTML = `
            <input placeholder="Label" data-label>
            <input placeholder="Item name" data-item>
            <input type="number" min="1" value="1" data-amount>
            <input type="number" min="0" value="0" data-price>
            <input type="number" min="0" value="2500" data-time>
            <input placeholder="Ingredients bread:1,meat:1" data-ingredients>
            <button>Add Item</button>
        `;

        add.querySelector('button').onclick = () => post('addMenuItem', {
            stationId: station.id,
            item: {
                label: add.querySelector('[data-label]').value,
                item: add.querySelector('[data-item]').value,
                amount: Number(add.querySelector('[data-amount]').value || 1),
                price: Number(add.querySelector('[data-price]').value || 0),
                time: Number(add.querySelector('[data-time]').value || 2500),
                ingredients: add.querySelector('[data-ingredients]').value
            }
        }).then(refresh);

        card.appendChild(add);

        (station.items || []).forEach((item, index) => {
            const row = document.createElement('div');
            row.className = 'row';
            row.innerHTML = `
                <div><span class="badge">${item.item}</span></div>
                <div><strong>${item.label}</strong><div class="note">${item.amount || 1}x | ${money(item.price)}</div></div>
                <div></div>
                <button class="danger">Remove</button>
            `;
            row.querySelector('button').onclick = () => post('removeMenuItem', { stationId: station.id, index: index + 1 }).then(refresh);
            card.appendChild(row);
        });

        el.appendChild(card);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No menu stations configured.</p>';
}

function renderDj(data) {
    const el = qs('djStations');
    if (!el) return;

    const placeCard = qs('placeDjCard');
    if (placeCard) placeCard.style.display = data.canPlaceDJ ? 'block' : 'none';

    el.innerHTML = '';

    for (const dj of data.djStations || []) {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `
            <h3>${dj.label}</h3>
            <p class="note">Use radius: ${dj.useRadius} | Hear radius: ${dj.hearRadius}</p>
            <input placeholder="YouTube or Spotify URL" data-url>
            <input type="number" min="1" max="100" value="25" data-volume>
            <div class="split">
                <button data-play>Play</button>
                <button class="danger" data-stop>Stop</button>
            </div>
        `;

        card.querySelector('[data-play]').onclick = () => post('djPlay', {
            stationId: dj.id,
            url: card.querySelector('[data-url]').value,
            volume: Number(card.querySelector('[data-volume]').value || 25)
        });

        card.querySelector('[data-stop]').onclick = () => post('djStop', { stationId: dj.id });
        el.appendChild(card);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No DJ booths configured.</p>';
}

function renderStations(data) {
    const el = qs('stashStations');
    if (!el) return;

    const placeStationCard = qs('placeStationCard');
    if (placeStationCard) placeStationCard.style.display = data.canPlaceStations ? 'block' : 'none';

    el.innerHTML = '';

    for (const station of data.stashStations || []) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${station.type}</span></div>
            <div><strong>${station.label}</strong></div>
            <div></div>
            <button>Open</button>
        `;
        row.querySelector('button').onclick = () => post('openStash', { stationId: station.id });
        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No stash/fridge stations configured.</p>';
}

function renderDeleteStations(data) {
    const el = qs('deleteStations');
    if (!el) return;
    el.innerHTML = '';

    const stations = (data.allStations || []).filter(st => st.dynamic);

    for (const station of stations) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${station.type}</span></div>
            <div><strong>${station.label}</strong><div class="note">${station.id}</div></div>
            <div>${station.job || ''}</div>
            <button class="danger" ${station.canDelete ? '' : 'disabled'}>Delete</button>
        `;
        row.querySelector('button').onclick = () => post('deleteStation', { stationId: station.id }).then(refresh);
        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No placed stations found.</p>';
}


/* ADMIN PANEL */
const ADMIN_SECTIONS = ['businesses', 'settings', 'place', 'business-supplies', 'global-supplies', 'stations'];

function normalizeAdminData(data) {
    return data || { businesses: [], supplyItems: [] };
}

function adminPanelVisible() {
    const panel = getAdminPanelEl();
    return !!(panel && !panel.classList.contains('hidden'));
}

function showAdminPanel() {
    const panel = getAdminPanelEl();
    if (!panel) return;
    panel.classList.remove('hidden');
    panel.style.display = 'grid';
    panel.style.position = 'fixed';
    panel.style.inset = '0';
    panel.style.zIndex = '999999';
}

function hideAdminPanel() {
    const panel = getAdminPanelEl();
    if (!panel) return;
    panel.classList.add('hidden');
    panel.style.display = '';
}

function showAdminSection(section) {
    if (!ADMIN_SECTIONS.includes(section)) section = 'settings';
    currentAdminSection = section;

    document.querySelectorAll('#adminSectionTabs .admin-section-tab').forEach(btn => {
        const active = btn.dataset.adminSection === section;
        btn.classList.toggle('active', active);
        btn.setAttribute('aria-selected', active ? 'true' : 'false');
    });

    document.querySelectorAll('#adminEditor [data-admin-section-panel]').forEach(panel => {
        const active = panel.dataset.adminSectionPanel === section;
        panel.classList.toggle('hidden', !active);
        panel.style.display = active ? 'block' : 'none';
    });
}

function showAdminEditor() {
    const editor = qs('adminEditor');
    if (editor) {
        editor.classList.remove('hidden');
        editor.style.display = 'block';
    }
    const tabs = qs('adminSectionTabs');
    if (tabs) {
        tabs.classList.remove('hidden');
        tabs.style.display = 'flex';
    }
    showAdminSection(currentAdminSection || 'settings');
}

function getAdminBusiness(id) {
    return (adminData?.businesses || []).find(b => String(b.id) === String(id));
}

function renderAdminPanel(data) {
    data = normalizeAdminData(data);
    adminData = data;
    showAdminPanel();

    const list = qs('adminBusinessList');
    if (list) {
        list.innerHTML = '';
        (data.businesses || []).forEach(business => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'tab';
            btn.dataset.businessId = business.id;
            btn.textContent = business.label || business.id || 'Business';
            btn.onclick = () => selectAdminBusiness(business.id);
            list.appendChild(btn);
        });
    }

    renderAdminSupplyItems(data);

    const businesses = data.businesses || [];
    let restoreId = pendingAdminSelectionId || (selectedAdminBusiness && selectedAdminBusiness.id);
    let business = restoreId ? getAdminBusiness(restoreId) : null;
    if (!business && businesses.length > 0) business = businesses[0];

    if (business) {
        selectAdminBusiness(business.id, true);
    } else {
        selectedAdminBusiness = null;
        if (qs('adminTitle')) qs('adminTitle').textContent = 'No Businesses Found';
        renderAdminBusinessSupplyItems(null);
        renderAdminStations({ stations: [] });
        showAdminEditor();
    }

    showAdminSection(currentAdminSection || 'settings');
}

function selectAdminBusiness(id, skipRefresh = false) {
    const business = getAdminBusiness(id);
    if (!business) return;

    selectedAdminBusiness = business;
    pendingAdminSelectionId = business.id;

    document.querySelectorAll('#adminBusinessList .tab').forEach(btn => {
        btn.classList.toggle('active', String(btn.dataset.businessId) === String(business.id));
    });

    if (qs('adminTitle')) qs('adminTitle').textContent = (business.label || business.id) + ' Admin';
    if (qs('adminBusinessLabel')) qs('adminBusinessLabel').value = business.label || '';
    if (qs('adminBusinessJob')) qs('adminBusinessJob').value = business.job || '';
    if (qs('adminBusinessType')) qs('adminBusinessType').value = business.type || '';
    if (qs('adminBusinessUiTitle')) qs('adminBusinessUiTitle').value = business.ui?.title || '';
    if (qs('adminBusinessColor')) qs('adminBusinessColor').value = business.ui?.primaryColor || '#38bdf8';

    const blip = business.blip || {};
    if (qs('adminBusinessBlipEnabled')) qs('adminBusinessBlipEnabled').checked = blip.enabled !== false;
    if (qs('adminBusinessBlipHere')) qs('adminBusinessBlipHere').checked = false;
    if (qs('adminBusinessBlipLabel')) qs('adminBusinessBlipLabel').value = blip.label || business.label || '';
    if (qs('adminBusinessBlipSprite')) qs('adminBusinessBlipSprite').value = blip.sprite ?? 439;
    if (qs('adminBusinessBlipColor')) qs('adminBusinessBlipColor').value = blip.color ?? 2;
    if (qs('adminBusinessBlipScale')) qs('adminBusinessBlipScale').value = blip.scale ?? 0.75;
    if (qs('adminBusinessBlipX')) qs('adminBusinessBlipX').value = blip.coords?.x ?? '';
    if (qs('adminBusinessBlipY')) qs('adminBusinessBlipY').value = blip.coords?.y ?? '';
    if (qs('adminBusinessBlipZ')) qs('adminBusinessBlipZ').value = blip.coords?.z ?? '';

    renderAdminBusinessSupplyItems(business);
    renderAdminStations(business);
    showAdminEditor();

    if (!skipRefresh) post('adminBusinessSelected', { businessId: business.id });
}

function renderAdminStations(business) {
    const el = qs('adminStations');
    if (!el) return;
    el.innerHTML = '';

    for (const station of business?.stations || []) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${station.type || 'station'}</span></div>
            <div><strong>${station.label || station.id}</strong><div class="note">${station.id || ''} ${station.dynamic ? '• placed' : '• config'}</div></div>
            <button type="button" data-teleport>TP</button>
            <button type="button" class="danger" data-delete ${station.dynamic ? '' : 'disabled'}>Delete</button>
        `;
        row.querySelector('[data-teleport]').onclick = () => post('adminTeleportToStation', { businessId: business.id, stationId: station.id });
        row.querySelector('[data-delete]').onclick = () => post('adminDeleteStation', { businessId: business.id, stationId: station.id }).then(refreshAdmin);
        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No stations found.</p>';
}

function renderAdminSupplyItems(data) {
    const el = qs('adminSupplyItems');
    if (!el) return;
    el.innerHTML = '';

    for (const item of data?.supplyItems || []) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${item.item}</span></div>
            <div><strong>${item.label}</strong><div class="note">Amount: ${item.amount} | ${item.enabled ? 'Enabled' : 'Disabled'}</div></div>
            <div>${money(item.price)}</div>
            <button type="button" class="danger">Delete</button>
        `;
        row.querySelector('button').onclick = (event) => {
            event.stopPropagation();
            post('adminDeleteSupplyItem', { item: item.item }).then(refreshAdmin);
        };
        row.onclick = () => {
            if (qs('adminSupplyItem')) qs('adminSupplyItem').value = item.item || '';
            if (qs('adminSupplyLabel')) qs('adminSupplyLabel').value = item.label || '';
            if (qs('adminSupplyPrice')) qs('adminSupplyPrice').value = item.price || 0;
            if (qs('adminSupplyAmount')) qs('adminSupplyAmount').value = item.amount || 1;
            if (qs('adminSupplyEnabled')) qs('adminSupplyEnabled').value = item.enabled ? 'true' : 'false';
        };
        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No supply items configured.</p>';
}

function renderAdminBusinessSupplyItems(business) {
    const el = qs('adminBusinessSupplyItems');
    if (!el) return;
    el.innerHTML = '';

    if (!business) {
        el.innerHTML = '<p class="note">Select a business to edit business-specific supplies.</p>';
        return;
    }

    for (const item of business.supplyItems || []) {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div><span class="badge">${item.item}</span></div>
            <div><strong>${item.label}</strong><div class="note">Amount: ${item.amount} | ${item.enabled ? 'Enabled' : 'Disabled'}</div></div>
            <div>${money(item.price)}</div>
            <button type="button" class="danger">Remove</button>
        `;
        row.querySelector('button').onclick = (event) => {
            event.stopPropagation();
            post('adminDeleteBusinessSupplyItem', { businessId: business.id, item: item.item }).then(refreshAdmin);
        };
        row.onclick = () => {
            if (qs('adminBusinessSupplyItem')) qs('adminBusinessSupplyItem').value = item.item || '';
            if (qs('adminBusinessSupplyLabel')) qs('adminBusinessSupplyLabel').value = item.label || '';
            if (qs('adminBusinessSupplyPrice')) qs('adminBusinessSupplyPrice').value = item.price || 0;
            if (qs('adminBusinessSupplyAmount')) qs('adminBusinessSupplyAmount').value = item.amount || 1;
            if (qs('adminBusinessSupplyEnabled')) qs('adminBusinessSupplyEnabled').value = item.enabled ? 'true' : 'false';
        };
        el.appendChild(row);
    }

    if (!el.innerHTML) el.innerHTML = '<p class="note">No business-specific supply items found.</p>';
}

/* UI EVENTS */
window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'openTablet') {
        showTabletOnly();
        render(msg.data);
        startDeliveryTimerRefresh();
        post('tabletRefresh');
        return;
    }

    if (msg.action === 'refreshTablet') {
        render(msg.data);
        startDeliveryTimerRefresh();
        return;
    }

    if (msg.action === 'closeTablet') {
        hideTabletOnly();
        return;
    }

    if (msg.action === 'openAdminPanel') {
        currentAdminSection = currentAdminSection || 'settings';
        renderAdminPanel(msg.data || { businesses: [], supplyItems: [] });
        post('adminUiReady');
        return;
    }

    if (msg.action === 'refreshAdminPanel') {
        if (adminPanelVisible()) renderAdminPanel(msg.data || { businesses: [], supplyItems: [] });
        return;
    }

    if (msg.action === 'closeAdminPanel') {
        hideAdminPanel();
        return;
    }
});

document.addEventListener('click', (event) => {
    const button = event.target?.closest?.('button');
    const target = event.target;
    if (!button && !target) return;

    if (button?.classList.contains('admin-section-tab') && button.dataset.adminSection) {
        event.preventDefault();
        showAdminSection(button.dataset.adminSection);
        return;
    }

    if (button?.closest('#adminBusinessList')) return;

    if (button?.classList.contains('tab') && button.dataset.tab) {
        currentTabletTab = button.dataset.tab;
        document.querySelectorAll('#tablet .tab[data-tab]').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('#tablet .page').forEach(p => p.classList.remove('active'));
        button.classList.add('active');
        qs('page-' + button.dataset.tab)?.classList.add('active');
        post('tabletTabSelected', { tab: currentTabletTab });
        return;
    }

    const id = button?.id || target?.id;

    if (id === 'closeBtn') { event.preventDefault(); closeTablet(); return; }
    if (id === 'adminCloseBtn') { event.preventDefault(); closeAdminPanel(); return; }

    if (id === 'depositBtn') {
        event.preventDefault();
        post('accountDeposit', { amount: Number(qs('depositAmount')?.value || 0), note: qs('depositNote')?.value || 'Tablet deposit' }).then(refresh); return;
    }
    if (id === 'withdrawBtn') {
        event.preventDefault();
        post('accountWithdraw', { amount: Number(qs('withdrawAmount')?.value || 0), note: qs('withdrawNote')?.value || 'Tablet withdrawal' }).then(refresh); return;
    }
    if (id === 'hireBtn') {
        event.preventDefault();
        post('hireEmployee', { targetId: Number(qs('hireId')?.value || 0), grade: Number(qs('hireGrade')?.value || 0) }).then(refresh); return;
    }
    if (id === 'orderBtn') {
        event.preventDefault();
        const items = [];
        document.querySelectorAll('[data-supply]').forEach(input => { const quantity = Number(input.value || 0); if (quantity > 0) items.push({ item: input.dataset.supply, quantity }); });
        post('createSupplyOrder', { items }).then(refresh); return;
    }
    if (id === 'placeDjBtn') {
        event.preventDefault();
        post('placeStation', { label: qs('newDjLabel')?.value || 'DJ Booth', type: 'dj', sizeX: 1.4, sizeY: 1.4, sizeZ: 1.0, hearRadius: Number(qs('newDjHearRadius')?.value || 45), useRadius: Number(qs('newDjUseRadius')?.value || 2) }).then(refresh); return;
    }
    if (id === 'placeStationBtn') {
        event.preventDefault();
        post('placeStation', { label: qs('stationLabel')?.value || 'Station', type: qs('stationType')?.value, sizeX: Number(qs('stationSizeX')?.value || 1.4), sizeY: Number(qs('stationSizeY')?.value || 1.4), sizeZ: Number(qs('stationSizeZ')?.value || 1.0), slots: Number(qs('stationSlots')?.value || 60), weight: Number(qs('stationWeight')?.value || 150000), useRadius: Number(qs('stationUseRadius')?.value || 2), hearRadius: Number(qs('stationHearRadius')?.value || 45) }).then(refresh); return;
    }

    if (id === 'adminCreateBusinessBtn') {
        event.preventDefault();
        post('adminCreateBusiness', {
            id: qs('adminNewBusinessId')?.value,
            label: qs('adminNewBusinessLabel')?.value,
            job: qs('adminNewBusinessJob')?.value,
            type: qs('adminNewBusinessType')?.value,
            uiTitle: qs('adminNewBusinessUiTitle')?.value,
            primaryColor: qs('adminNewBusinessColor')?.value,
            blipEnabled: qs('adminNewBusinessBlipEnabled')?.checked !== false,
            blipUseCurrentLocation: qs('adminNewBusinessBlipHere')?.checked === true,
            blipLabel: qs('adminNewBusinessBlipLabel')?.value || qs('adminNewBusinessLabel')?.value,
            blipSprite: Number(qs('adminNewBusinessBlipSprite')?.value || 439),
            blipColor: Number(qs('adminNewBusinessBlipColor')?.value || 2),
            blipScale: Number(qs('adminNewBusinessBlipScale')?.value || 0.75)
        }).then(refreshAdmin); return;
    }
    if (!selectedAdminBusiness && ['adminDeleteBusinessBtn','adminSaveBusinessBtn','adminPlaceStationBtn','adminSaveBusinessSupplyBtn'].includes(id)) {
        const first = adminData?.businesses?.[0];
        if (first) selectAdminBusiness(first.id, true);
        event.preventDefault();
        return;
    }
    if (id === 'adminDeleteBusinessBtn') {
        event.preventDefault();
        post('adminDeleteBusiness', { businessId: selectedAdminBusiness.id }).then(() => { selectedAdminBusiness = null; pendingAdminSelectionId = null; refreshAdmin(); }); return;
    }
    if (id === 'adminSaveBusinessBtn') {
        event.preventDefault();
        post('adminUpdateBusiness', {
            businessId: selectedAdminBusiness.id,
            label: qs('adminBusinessLabel')?.value,
            job: qs('adminBusinessJob')?.value,
            type: qs('adminBusinessType')?.value,
            uiTitle: qs('adminBusinessUiTitle')?.value,
            primaryColor: qs('adminBusinessColor')?.value,
            blipEnabled: qs('adminBusinessBlipEnabled')?.checked === true,
            blipUseCurrentLocation: qs('adminBusinessBlipHere')?.checked === true,
            blipLabel: qs('adminBusinessBlipLabel')?.value || qs('adminBusinessLabel')?.value,
            blipSprite: Number(qs('adminBusinessBlipSprite')?.value || 439),
            blipColor: Number(qs('adminBusinessBlipColor')?.value || 2),
            blipScale: Number(qs('adminBusinessBlipScale')?.value || 0.75),
            blipX: qs('adminBusinessBlipX')?.value,
            blipY: qs('adminBusinessBlipY')?.value,
            blipZ: qs('adminBusinessBlipZ')?.value
        }).then(refreshAdmin); return;
    }
    if (id === 'adminPlaceStationBtn') {
        event.preventDefault();
        post('adminPlaceStation', { businessId: selectedAdminBusiness.id, label: qs('adminStationLabel')?.value || 'Station', type: qs('adminStationType')?.value, sizeX: Number(qs('adminSizeX')?.value || 1.4), sizeY: Number(qs('adminSizeY')?.value || 1.4), sizeZ: Number(qs('adminSizeZ')?.value || 1.0), slots: Number(qs('adminSlots')?.value || 60), weight: Number(qs('adminWeight')?.value || 150000), useRadius: Number(qs('adminUseRadius')?.value || 2), hearRadius: Number(qs('adminHearRadius')?.value || 45) }).then(refreshAdmin); return;
    }
    if (id === 'adminSaveSupplyBtn') {
        event.preventDefault();
        post('adminSaveSupplyItem', { item: qs('adminSupplyItem')?.value, label: qs('adminSupplyLabel')?.value, price: Number(qs('adminSupplyPrice')?.value || 0), amount: Number(qs('adminSupplyAmount')?.value || 1), enabled: qs('adminSupplyEnabled')?.value === 'true' }).then(refreshAdmin); return;
    }
    if (id === 'adminSaveBusinessSupplyBtn') {
        event.preventDefault();
        post('adminSaveBusinessSupplyItem', { businessId: selectedAdminBusiness.id, item: qs('adminBusinessSupplyItem')?.value, label: qs('adminBusinessSupplyLabel')?.value, price: Number(qs('adminBusinessSupplyPrice')?.value || 0), amount: Number(qs('adminBusinessSupplyAmount')?.value || 1), enabled: qs('adminBusinessSupplyEnabled')?.value === 'true' }).then(refreshAdmin); return;
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape') return;
    if (adminPanelVisible()) { closeAdminPanel(); return; }
    if (getTabletEl() && !getTabletEl().classList.contains('hidden')) closeTablet();
});
