# Monitro V3 — Setup Guide

## What's built

| Feature | Details |
|---|---|
| **Auth** | Email/password via Supabase Auth |
| **Sign Up — Create Org** | Manager picks "Create Org", gives name → org created + 6-char code |
| **Sign Up — Join Org** | Member picks "Join Org", enters code → joins instantly |
| **Roles** | `manager` / `co_manager` / `member` |
| **Screen sharing** | Browser getDisplayMedia API — start/stop with one click |
| **Who sees whom** | Manager/Co-manager see ALL screens · Members see ONLY managers' screens |
| **Role management** | Manager can promote to co_manager, demote to member, kick anyone · Co-manager can kick members only |
| **Auto attendance** | Marked present the moment a member starts sharing their screen |
| **Attendance leaderboard** | Live ranked table, resets monthly, shows leader crown |
| **Rewards** | Manager gives monthly reward to winner with custom note |
| **Leave org** | Settings page → leave and join/create a new one |
| **Realtime** | Supabase Realtime — online status, sharing status update live |

---

## Step 1 — Supabase project

1. Go to https://supabase.com → New project
2. Wait ~2 min for it to spin up
3. Go to **SQL Editor** → paste the entire contents of `supabase_schema.sql` → click **Run**

---

## Step 2 — Add your keys

Open `app.html`, find these two lines near the bottom `<script>` tag:

```js
const SUPABASE_URL      = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE';
```

Replace with your values from **Supabase → Settings → API**:
- **Project URL** → paste as SUPABASE_URL
- **anon public** key → paste as SUPABASE_ANON_KEY

---

## Step 3 — Disable email confirmation (optional, for fast testing)

Supabase → Authentication → Settings → toggle off **"Enable email confirmations"**

---

## Step 4 — Open the app

Just double-click `app.html` in your browser. No server needed.

Or serve locally:
```bash
npx serve .
# Open http://localhost:3000/app.html
```

---

## How roles work

```
Manager
  ├── Sees ALL member screens in viewer
  ├── Can promote member → co_manager
  ├── Can demote co_manager → member
  ├── Can kick anyone
  ├── Gives monthly rewards
  └── Cannot be kicked

Co-Manager
  ├── Sees ALL member screens in viewer
  ├── Can kick members (not other co-managers or manager)
  └── Cannot promote/demote

Member
  ├── Can share their own screen
  ├── Can ONLY see manager & co-manager screens
  └── Cannot kick or manage anyone
```

---

## Attendance logic

- When a member clicks **Start Sharing**, Supabase `attendance` table gets an upsert for today's date
- If they share multiple times in one day → still counts as 1 day (UNIQUE constraint on user+date)
- At month end, manager goes to **Rewards** → gives reward to the winner
- Next month the count starts fresh (date-based filtering)

---

## Screen sharing notes

- Uses browser's `getDisplayMedia` API
- Works on Chrome, Edge, Firefox
- **Requires HTTPS** in production (localhost is exempt)
- The video is shown in your own preview but NOT yet streamed to others via WebRTC (that requires a signaling server — see below)

### To enable real multi-user screen viewing

You need to add WebRTC peer connections with a signaling server. Options:
1. Use **Daily.co** or **Agora** for plug-and-play
2. Add a simple WebSocket signaling server (Node.js)
3. Use Supabase Realtime as the signaling channel (advanced)

The `peerConnections` and `signalingChannel` variables are already stubbed in the code for this.

---

## Deploy online

**Netlify** (easiest):
1. netlify.com → drag & drop the folder
2. You get a URL instantly

**Vercel**:
```bash
npm i -g vercel && vercel
```

**GitHub Pages**:
Settings → Pages → Source: main branch → access at `yourusername.github.io/repo/app.html`

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Invalid API key" | Check SUPABASE_URL and SUPABASE_ANON_KEY |
| Can't join with code | Check you ran the full SQL schema |
| Screen share not working | Use Chrome/Edge, needs HTTPS in prod |
| Members not showing as online | They need to be on the app (realtime updates) |
| Email confirmation loop | Disable email confirmation in Supabase auth settings |
