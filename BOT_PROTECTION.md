# Bot / scraper protection (the "403" item)

This is the one item on the punch list that can't be done by editing
`index.html` — real bot-blocking happens at the hosting/CDN layer, in
front of your site, not inside the page itself. `robots.txt` (included)
is a courtesy that well-behaved crawlers respect, but it stops nothing
determined.

## What to do, depending on where your site is hosted
Tell me which of these you're using and I'll give you exact steps:

- **Cloudflare (free tier is enough)** — point your domain's DNS through
  Cloudflare, then turn on "Bot Fight Mode" and a basic WAF rate-limit
  rule on your ticket-purchase requests. This is the same mechanism that
  blocked both of us from reading ryscompetitions.com earlier.
- **Netlify / Vercel** — both have built-in bot/DDoS protection on by
  default, and you can add stricter rate-limiting rules in their
  dashboard without needing Cloudflare at all.
- **Plain web hosting (e.g. cPanel/Apache)** — usually needs Cloudflare
  (or a similar CDN) put in front of it, since the raw host itself
  typically doesn't fingerprint bot traffic.

## What's already added at the code level (partial, not a substitute)
- `robots.txt` — asks crawlers not to index/scrape.
- The app already validates on the server (Supabase Row Level Security)
  rather than trusting anything the browser sends, which is the most
  important defence against someone scripting unfair ticket purchases -
  this was true before today's changes and hasn't been altered.

Once you tell me your host, I'll write the exact Cloudflare/Netlify/Vercel
configuration for you.
