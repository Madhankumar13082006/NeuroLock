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
  <title>NOKKON — Set PIN</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 24px; max-width: 440px; margin: 0 auto; }
    h1 { font-size: 1.35rem; margin-bottom: 0.5rem; }
    p.sub { color: #94a3b8; font-size: 0.9rem; line-height: 1.45; margin-bottom: 1.25rem; }
    label { display: block; margin: 14px 0 6px; color: #94a3b8; font-size: 0.85rem; }
    input { width: 100%; box-sizing: border-box; padding: 12px 14px; border-radius: 10px; border: 1px solid #334155; background: #1e293b; color: #f8fafc; font-size: 1rem; }
    button { margin-top: 22px; width: 100%; padding: 14px; border-radius: 12px; background: #7c3aed; color: #fff; border: none; font-weight: 600; font-size: 1rem; cursor: pointer; }
    button:disabled { opacity: 0.6; cursor: not-allowed; }
    .err { color: #f87171; margin-top: 12px; font-size: 0.9rem; }
    .ok { color: #4ade80; margin-top: 16px; font-size: 1rem; }
  </style>
</head>
<body>
  <h1>Set unlock PIN</h1>
  <p class="sub">This link works <strong>once</strong>. After a PIN is saved, it cannot be used again. Prefer someone you trust.</p>
  <label for="n">Your name (optional)</label>
  <input id="n" maxlength="60" placeholder="Trusted friend" autocomplete="name" />
  <label for="p">PIN (4 digits)</label>
  <input id="p" type="password" inputmode="numeric" pattern="[0-9]*" maxlength="4" autocomplete="new-password" />
  <label for="c">Confirm PIN</label>
  <input id="c" type="password" inputmode="numeric" pattern="[0-9]*" maxlength="4" autocomplete="new-password" />
  <div id="e" class="err" role="alert"></div>
  <button type="button" id="go">Save PIN</button>
  <script>
    const TOKEN = ${token};
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
        document.querySelector('button').remove();
        e.className = 'ok';
        e.textContent = 'PIN saved. You can close this page.';
      } catch (x) {
        e.textContent = 'Network error. Use the same Wi-Fi as the NOKKON user PC, or check the server is running.';
        btn.disabled = false;
      }
    });
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
}
