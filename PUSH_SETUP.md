# Push notifications — one-time setup

Everything in `index.html` and `sw.js` for push is already built and wired
up (the "🔔 Enable Alerts On This Device" button in Admin). This is the one
remaining piece that has to be deployed **inside your Supabase project**,
because sending a push message has to happen from a server, not a browser.

## 1. Run the database migration
In your Supabase project → SQL Editor → paste the contents of
`schema_additions.sql` → Run. (Safe to run once — only adds new tables.)

## 2. Your VAPID keys (already generated for you)
These are the "sender ID" keys that prove push messages really come from
your app. The public one is already in `index.html`. Keep the private one
secret — treat it like a password.

```
VAPID_PUBLIC_KEY  = BG2Fxrw3q-M-JGs7Q34CGa7PD8nyWdgE-amZ3yTCAL6okZWkBqMjgQZNhZF4Ie2Y7X3Mru9YCDXl6UWN5p2_tfg
VAPID_PRIVATE_KEY = XK8t0bDwWF_oRr2kF5bT0jCpSkK1VvlzcuLOf_orU2Y
```

## 3. Deploy the Edge Function
You'll need the Supabase CLI (`npm install -g supabase`) and to be logged
in (`supabase login`) and linked to your project (`supabase link`).

Create `supabase/functions/send-win-push/index.ts` with:

```ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import webpush from 'https://esm.sh/web-push@3.6.7'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const vapidPublic = Deno.env.get('VAPID_PUBLIC_KEY')!
const vapidPrivate = Deno.env.get('VAPID_PRIVATE_KEY')!

webpush.setVapidDetails('mailto:you@example.com', vapidPublic, vapidPrivate)

Deno.serve(async (req) => {
  const payload = await req.json()
  // payload.record is the new row (from the database webhook below)
  const record = payload.record
  const isWin = payload.table === 'bingo_wins'
  const title = isWin ? `🏆 Winner! ${record.player_name}` : '🔔 Game finished'
  const body = isWin
    ? `${record.player_name} won ${record.tier} — £${record.payout}`
    : `A game in your bingo has finished.`

  const supabase = createClient(supabaseUrl, serviceKey)
  const { data: subs } = await supabase.from('push_subscriptions').select('*')

  await Promise.all((subs || []).map(async (sub) => {
    try {
      await webpush.sendNotification(
        { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
        JSON.stringify({ title, body, url: '/' })
      )
    } catch (err) {
      console.error('push failed for', sub.endpoint, err)
    }
  }))

  return new Response('ok')
})
```

Set the secrets and deploy:

```bash
supabase secrets set VAPID_PUBLIC_KEY=BG2Fxrw3q-M-JGs7Q34CGa7PD8nyWdgE-amZ3yTCAL6okZWkBqMjgQZNhZF4Ie2Y7X3Mru9YCDXl6UWN5p2_tfg
supabase secrets set VAPID_PRIVATE_KEY=XK8t0bDwWF_oRr2kF5bT0jCpSkK1VvlzcuLOf_orU2Y
supabase functions deploy send-win-push
```

## 4. Trigger it automatically
In the Supabase Dashboard → Database → Webhooks → Create a new webhook:
- **Table**: `bingo_wins`, **Event**: Insert → calls `send-win-push`
- **Table**: `bingo_games`, **Event**: Update, condition `status = 'finished'` → calls `send-win-push`

That's it — from then on, every win and every finished game pushes an
alert straight to any device that's tapped "Enable Alerts."

## If you'd rather skip this for now
The app works completely normally without it — the button just won't
successfully enable push until this is deployed. Nothing else depends on it.
