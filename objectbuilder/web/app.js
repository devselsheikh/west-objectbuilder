const app = document.getElementById('app');
const modelSelect = document.getElementById('modelSelect');
const previewBtn = document.getElementById('previewBtn');
const closeBtn = document.getElementById('closeBtn');
const snapBtn = document.getElementById('snapBtn');
const exportBtn = document.getElementById('exportBtn');
const exportOutput = document.getElementById('exportOutput');

let snapEnabled = true;

const post = (name, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });

window.addEventListener('message', (event) => {
  const msg = event.data;
  if (msg.type === 'open') {
    app.classList.remove('hidden');
    modelSelect.innerHTML = '';
    Object.keys(msg.models || {}).forEach((name) => {
      const option = document.createElement('option');
      option.value = name;
      option.textContent = name;
      modelSelect.appendChild(option);
    });
  }

  if (msg.type === 'export') {
    exportOutput.value = msg.payload || '';
  }

  if (msg.type === 'close') {
    app.classList.add('hidden');
  }
});

previewBtn.addEventListener('click', () => {
  post('setModel', { model: modelSelect.value });
  post('toggleEditor', { enabled: true });
});

closeBtn.addEventListener('click', () => {
  app.classList.add('hidden');
  post('close');
});

snapBtn.addEventListener('click', () => {
  snapEnabled = !snapEnabled;
  snapBtn.textContent = `Snap: ${snapEnabled ? 'ON' : 'OFF'}`;
  post('setSnap', { enabled: snapEnabled });
});

document.querySelectorAll('[data-axis]').forEach((btn) => {
  btn.addEventListener('click', () => post('setAxis', { axis: btn.dataset.axis }));
});

exportBtn.addEventListener('click', () => post('exportMap'));
