const app = document.getElementById('app');
const modelSelect = document.getElementById('modelSelect');
const previewBtn = document.getElementById('previewBtn');
const closeBtn = document.getElementById('closeBtn');
const snapBtn = document.getElementById('snapBtn');
const exportBtn = document.getElementById('exportBtn');
const exportOutput = document.getElementById('exportOutput');
const objectList = document.getElementById('objectList');
const mapName = document.getElementById('mapName');
const loadMapBtn = document.getElementById('loadMapBtn');
const posInput = document.getElementById('pos');
const rotInput = document.getElementById('rot');
const applyBtn = document.getElementById('applyBtn');
const dupBtn = document.getElementById('dupBtn');
const freezeBtn = document.getElementById('freezeBtn');
const delBtn = document.getElementById('delBtn');
const importBtn = document.getElementById('importBtn');

let snapEnabled = true;
let selectedId = null;
let frozen = true;

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
const setVisible = (visible) => { app.style.display = visible ? 'block' : 'none'; app.classList.toggle('hidden', !visible); };
const renderList = (objects = []) => {
  objectList.innerHTML = '';
  objects.forEach((obj) => {
    const btn = document.createElement('button');
    btn.textContent = `${obj.id} | ${obj.model}`;
    btn.addEventListener('click', () => { selectedId = obj.id; post('selectObject', { id: obj.id }); });
    objectList.appendChild(btn);
  });
};

setVisible(false);
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('keydown', (event) => { if (event.key === 'Escape') { setVisible(false); post('close'); } });

window.addEventListener('message', (event) => {
  const msg = event.data;
  if (msg.type === 'open') {
    setVisible(true);
    modelSelect.innerHTML = '';
    mapName.value = msg.map || 'default';
    Object.keys(msg.models || {}).forEach((name) => {
      const option = document.createElement('option'); option.value = name; option.textContent = name; modelSelect.appendChild(option);
    });
  }
  if (msg.type === 'close') setVisible(false);
  if (msg.type === 'export') exportOutput.value = msg.payload || '';
  if (msg.type === 'mapState') { mapName.value = msg.map || mapName.value; renderList(msg.objects || []); }
  if (msg.type === 'inspector' && msg.object) {
    selectedId = msg.object.id;
    frozen = msg.object.frozen === true;
    posInput.value = JSON.stringify(msg.object.coords);
    rotInput.value = JSON.stringify(msg.object.rotation);
  }
});

closeBtn.addEventListener('click', () => { setVisible(false); post('close'); });
previewBtn.addEventListener('click', () => { post('setModel', { model: modelSelect.value }); post('toggleEditor', { enabled: true }); });
snapBtn.addEventListener('click', () => { snapEnabled = !snapEnabled; snapBtn.textContent = `Snap: ${snapEnabled ? 'ON' : 'OFF'}`; post('setSnap', { enabled: snapEnabled }); });
exportBtn.addEventListener('click', () => post('exportMap'));
loadMapBtn.addEventListener('click', () => post('loadMap', { map: mapName.value.trim() }));
importBtn.addEventListener('click', () => post('importMap', { payload: exportOutput.value }));

document.querySelectorAll('[data-axis]').forEach((btn) => btn.addEventListener('click', () => post('setAxis', { axis: btn.dataset.axis })));
applyBtn.addEventListener('click', () => {
  if (!selectedId) return;
  try {
    const coords = JSON.parse(posInput.value);
    const rotation = JSON.parse(rotInput.value);
    post('updateTransform', { coords, rotation });
  } catch (_) {}
});
dupBtn.addEventListener('click', () => selectedId && post('duplicateObject'));
freezeBtn.addEventListener('click', () => { frozen = !frozen; post('freezeObject', { frozen }); });
delBtn.addEventListener('click', () => selectedId && post('deleteObject', { id: selectedId }));
