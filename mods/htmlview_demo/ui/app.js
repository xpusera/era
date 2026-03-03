let wasmAdd = null;

async function loadWasm(){
  const resp = await fetch('add.wasm');
  if (WebAssembly.instantiateStreaming) {
    const { instance } = await WebAssembly.instantiateStreaming(resp);
    wasmAdd = instance.exports.add;
    return;
  }
  const bytes = await resp.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes);
  wasmAdd = instance.exports.add;
}

function $(id){ return document.getElementById(id); }

function setBgPulse(on){
  document.body.style.transition = 'background 250ms ease';
  if (!on) {
    document.body.style.background = '';
    return;
  }
  const t = Date.now() % 1000;
  const a = 0.10 + 0.10 * Math.sin(t / 1000 * Math.PI * 2);
  document.body.style.background = `radial-gradient(900px 600px at 30% 20%, rgba(110,168,255,${a}), transparent 60%), #0b0e14`;
}

(async () => {
  try {
    await loadWasm();
    $('out').textContent = 'ready';
  } catch(e) {
    $('out').textContent = 'wasm failed';
  }

  $('run').addEventListener('click', () => {
    if (!wasmAdd) {
      $('out').textContent = 'not ready';
      return;
    }
    const a = parseInt($('a').value || '0', 10) | 0;
    const b = parseInt($('b').value || '0', 10) | 0;
    $('out').textContent = String(wasmAdd(a, b) | 0);
  });

  $('send').addEventListener('click', () => {
    try {
      luanti.send(String($('msg').value || ''));
    } catch(e) {}
  });

  $('ping').addEventListener('click', () => {
    try { luanti.send('ping'); } catch(e) {}
  });

  $('reqCapture').addEventListener('click', () => {
    try { luanti.send('capture'); } catch(e) {}
  });

  let pulsing = false;
  $('pulse').addEventListener('click', () => {
    pulsing = !pulsing;
    if (!pulsing) {
      setBgPulse(false);
      return;
    }
    const tick = () => {
      if (!pulsing) return;
      setBgPulse(true);
      requestAnimationFrame(tick);
    };
    tick();
  });

  $('dark').addEventListener('click', () => {
    document.body.style.background = '#05070c';
  });

  if (window.luanti && luanti.on_message) {
    luanti.on_message((msg) => {
      $('fromLua').textContent = String(msg);
      if (msg === 'flash') {
        document.body.style.background = 'rgba(255,60,60,.12)';
        setTimeout(() => { document.body.style.background = ''; }, 180);
      }
    });
  }
})();
