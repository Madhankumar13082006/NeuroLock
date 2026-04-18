import { Request, Response } from 'express';

/**
 * Simple one-page PIN setup for local dev: open http://<YOUR_LAN_IP>:3000/invite/<token>
 * POSTs to existing POST /trusted/setup/:token
 */
export function getInvitePinPage(req: Request, res: Response) {
  const raw = req.params.token as string;
  const token = JSON.stringify(raw);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>NeuroLock — Set PIN</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 24px; max-width: 440px; margin: 0 auto; }
    h1 { font-size: 1.35rem; margin-bottom: 0.5rem; margin-top: 16px; }
    p.sub { color: #94a3b8; font-size: 0.9rem; line-height: 1.45; margin-bottom: 1.25rem; }
    label { display: block; margin: 14px 0 6px; color: #94a3b8; font-size: 0.85rem; }
    input { width: 100%; padding: 12px 14px; border-radius: 10px; border: 1px solid #334155; background: #1e293b; color: #f8fafc; font-size: 1rem; }
    .pin-wrap { position: relative; }
    .pin-wrap input { padding-right: 44px; }
    .eye-btn { position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; color: #64748b; padding: 4px; font-size: 0; line-height: 0; margin: 0; width: auto; }
    .eye-btn:hover { color: #94a3b8; }
    #go { margin-top: 22px; width: 100%; padding: 14px; border-radius: 12px; background: #7c3aed; color: #fff; border: none; font-weight: 600; font-size: 1rem; cursor: pointer; }
    #go:disabled { opacity: 0.6; cursor: not-allowed; }
    .err { color: #f87171; margin-top: 12px; font-size: 0.9rem; }
    /* ── success card ── */
    #save-card { display: none; margin-top: 20px; background: rgba(74,222,128,0.08); border: 1px solid rgba(74,222,128,0.3); border-radius: 16px; padding: 20px 18px 16px; text-align: center; }
    #save-card .sc-title { font-size: 1rem; font-weight: 700; color: #4ade80; margin-bottom: 6px; }
    #save-card .sc-sub { font-size: 0.8rem; color: #94a3b8; margin-bottom: 16px; line-height: 1.45; }
    .pin-digits { display: flex; justify-content: center; gap: 10px; margin-bottom: 16px; }
    .pin-d { width: 52px; height: 60px; background: #1e293b; border: 2px solid rgba(74,222,128,0.45); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 28px; font-weight: 800; color: #4ade80; }
    .share-row { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; margin-bottom: 10px; }
    .sb { display: flex; align-items: center; gap: 6px; padding: 9px 14px; border-radius: 10px; border: none; cursor: pointer; font-size: 0.82rem; font-weight: 600; }
    .sb-wa { background: #25D366; color: #fff; }
    .sb-tg { background: #229ED9; color: #fff; }
    .sb-cp { background: rgba(255,255,255,0.1); color: #e2e8f0; border: 1px solid rgba(255,255,255,0.18) !important; }
    .hint { font-size: 0.75rem; color: #475569; line-height: 1.5; margin-top: 8px; }
  </style>
</head>
<body>
  <h1>Set unlock PIN</h1>
  <p class="sub">This link works <strong>once</strong>. After a PIN is saved, it cannot be used again. Prefer someone you trust.</p>
  <label for="n">Your name (optional)</label>
  <input id="n" maxlength="60" placeholder="Trusted friend" autocomplete="name" />
  <label for="p">PIN (4 digits)</label>
  <div class="pin-wrap">
    <input id="p" type="password" inputmode="numeric" pattern="[0-9]*" maxlength="4" autocomplete="new-password" placeholder="••••" />
    <button class="eye-btn" type="button" onclick="toggleEye('p','ep')" aria-label="Show PIN">
      <svg id="ep" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
    </button>
  </div>
  <label for="c">Confirm PIN</label>
  <div class="pin-wrap">
    <input id="c" type="password" inputmode="numeric" pattern="[0-9]*" maxlength="4" autocomplete="new-password" placeholder="••••" />
    <button class="eye-btn" type="button" onclick="toggleEye('c','ec')" aria-label="Show confirm PIN">
      <svg id="ec" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
    </button>
  </div>
  <div id="e" class="err" role="alert"></div>
  <button type="button" id="go">Save PIN</button>

  <!-- shown after success -->
  <div id="save-card">
    <div class="sc-title">✓ PIN saved!</div>
    <div class="sc-sub">Save this PIN privately — you'll need it when your friend asks you to unlock.</div>
    <div class="pin-digits" id="pdigits"></div>
    <div class="share-row">
      <button class="sb sb-wa" onclick="shareWA()">
        <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
        WhatsApp
      </button>
      <button class="sb sb-tg" onclick="shareTG()">
        <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
        Telegram
      </button>
      <button class="sb sb-cp" id="cpbtn" onclick="copyPin()">
        <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
        Copy
      </button>
    </div>
    <div class="hint">📸 Screenshot this page to save the PIN safely.<br>Do not share it with the person you are helping.</div>
  </div>

  <script>
    const TOKEN = ${token};
    let _pin = '';

    function toggleEye(inputId, svgId) {
      const inp = document.getElementById(inputId);
      const svg = document.getElementById(svgId);
      const show = inp.type === 'password';
      inp.type = show ? 'text' : 'password';
      svg.innerHTML = show
        ? '<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/>'
        : '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>';
    }

    document.getElementById('go').addEventListener('click', async function () {
      const btn = this;
      const e = document.getElementById('e');
      e.textContent = '';
      const trustedName = (document.getElementById('n').value || '').trim() || 'Trusted contact';
      const pin = document.getElementById('p').value;
      const c = document.getElementById('c').value;
      if (!/^\\d{4}$/.test(pin)) { e.textContent = 'PIN must be exactly 4 digits.'; return; }
      if (pin !== c) { e.textContent = 'PINs do not match.'; return; }
      btn.disabled = true;
      try {
        const r = await fetch('/trusted/setup/' + encodeURIComponent(TOKEN), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ trustedName, pin })
        });
        const j = await r.json().catch(function () { return {}; });
        if (!r.ok) {
          e.textContent = j.error || ('Request failed (' + r.status + ')');
          btn.disabled = false;
          return;
        }
        _pin = pin;
        btn.remove();
        document.getElementById('n').closest('label') && null;
        // Hide form inputs
        ['n','p','c'].forEach(function(id) {
          const el = document.getElementById(id);
          if (el) el.closest('.pin-wrap') ? el.closest('.pin-wrap').style.display = 'none' : el.style.display = 'none';
        });
        // Show save card
        const digits = document.getElementById('pdigits');
        digits.innerHTML = '';
        for (const ch of pin) {
          const d = document.createElement('div');
          d.className = 'pin-d';
          d.textContent = ch;
          digits.appendChild(d);
        }
        document.getElementById('save-card').style.display = '';
      } catch (x) {
        e.textContent = 'Network error — check your connection and try again.';
        btn.disabled = false;
      }
    });

    function _shareText() {
      return 'Your NeuroLock unlock PIN is: ' + _pin + '\\n\\nKeep this safe — only share it when asked to unlock.';
    }
    function shareWA() { window.open('https://wa.me/?text=' + encodeURIComponent(_shareText()), '_blank'); }
    function shareTG() { window.open('https://t.me/share/url?url=&text=' + encodeURIComponent(_shareText()), '_blank'); }
    function copyPin() {
      navigator.clipboard.writeText(_pin).then(function() {
        const b = document.getElementById('cpbtn');
        const orig = b.textContent;
        b.textContent = 'Copied!';
        setTimeout(function() { b.textContent = orig; }, 1800);
      });
    }
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
}
