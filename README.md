<p align="center">
  <img src="https://cdn.prod.website-files.com/69082c5061a39922df8ed3b6/6a18cb17e0c9073d8ecd1e47_this-logo-features-letter-combined-600nw-2603500055.png" alt="AlphaLine" width="220" />
</p>

<p align="center">
  <strong>Find the edge.</strong>
</p>

<p align="center">
  <b>$AlphaLine</b> &nbsp;|&nbsp; CA: <code>CLym3zdHsJu2VVkVJC2Wa6XCB5A6mDjciAfkx4fYpump</code>
</p>

<p align="center">
  <em>Real-time fair-value pricing for sports prediction markets — built for Polymarket.</em>
</p>

<p align="center">
  <a href="https://alphaline.gg"><img alt="Site" src="https://img.shields.io/badge/site-alphaline.gg-6366f1?style=for-the-badge"></a>
  <a href="https://polymarket.com/@mynameisdev"><img alt="Polymarket" src="https://img.shields.io/badge/Polymarket-live-1652f0?style=for-the-badge"></a>
  <a href="https://x.com/tryalphaline"><img alt="Twitter" src="https://img.shields.io/badge/follow-%40tryalphaline-000000?logo=x&style=for-the-badge"></a>
  <a href="https://github.com/tryalphaline"><img alt="GitHub" src="https://img.shields.io/badge/source-tryalphaline-181717?logo=github&style=for-the-badge"></a>
</p>

<p align="center">
  <img alt="YC" src="https://img.shields.io/badge/Y%20Combinator-backed-F26522?logo=ycombinator&logoColor=white">
  <img alt="Sports" src="https://img.shields.io/badge/sports-NBA%20%7C%20NHL%20%7C%20MLB%20%7C%20NFL-white">
  <img alt="Latency" src="https://img.shields.io/badge/latency-sub%20200ms-22d3a4">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow">
  <img alt="Status" src="https://img.shields.io/badge/status-live-success">
</p>

---

## What is AlphaLine

AlphaLine is a real-time fair-value pricing engine for sports prediction markets. It ingests live signals — injury wires, confirmed lineups, sharp money movement, weather, and market microstructure — and computes the true probability of every outcome in milliseconds, before the book catches up.

The gap between AlphaLine's fair price and Polymarket's implied price is the edge. AlphaLine exists to surface it, explain it, and get it to you first.

> **The result:** a research terminal that tells you where Polymarket is wrong, and exactly why.

---

## How It Works

```
Signal fires (injury / lineup / sharp move / weather)
         │
         ▼  ~0ms
AlphaLine fair-value model recomputes
         │
         ▼  ~142ms median
Edge alert delivered (terminal · Discord · webhook · API)
         │
         ▼  ~38s average
Polymarket begins to price the signal in
```

AlphaLine monitors every meaningful source across NBA, NHL, MLB, and NFL — official injury feeds, lineup confirmations, public sentiment, aggregated market microstructure — and runs a fair-value model trained on eight seasons of granular game data. When the model diverges from Polymarket's implied price by a meaningful margin, an alert fires.

The model's confidence, the signal type, and the edge size are all returned with every alert so you can weight them appropriately.

---

## Features

### Live Edge Terminal
A full dashboard of every live Polymarket market sorted by absolute edge. Each entry shows the market's implied probability, AlphaLine's fair-value probability, the edge, and the signal that caused the divergence — with one-click links straight into the Polymarket book.

### Real-Time Signals
Every alert includes the signal that triggered it:

| Signal | Description |
|---|---|
| **Injury** | Official injury wire updates, DNP confirmations, and mid-game exits |
| **Lineup** | Confirmed starters, scratch announcements, and unexpected rotations |
| **Sharp money** | Reverse line movement and unusual handle concentration |
| **Weather** | Wind, temperature, and precipitation at time of kickoff |
| **Sentiment** | Aggregated public ticket count vs sharp-side divergence |
| **Rest / travel** | Days of rest differential and back-to-back scheduling |

### Edge Alerts — Four Surfaces
One signal, four delivery channels — routed in under 200ms:

- **Browser push** — Chromium-style web notification, fires even when AlphaLine is closed
- **iOS & Android** — Native push via the AlphaLine companion app
- **Discord webhook** — Branded embeds with edge math and a direct Polymarket link
- **In-app terminal** — Live toast with one-click jump to the market

### Track Record
Every edge call is logged with its signal, probability, and outcome. The public track record is visible on the dashboard — settled markets show whether AlphaLine's read was right.

### REST + WebSocket API
Full programmatic access for developers and trading desks:

```bash
# List every Polymarket market where AlphaLine finds ≥5% edge
curl https://api.alphaline.gg/v1/polymarket/markets \
  -H "Authorization: Bearer al_live_..." \
  -G -d min_edge=5 -d sport=NBA
```

```js
// Stream edge crossings in real time
const ws = new WebSocket("wss://stream.alphaline.gg/v1", {
  headers: { Authorization: `Bearer ${API_KEY}` },
});

ws.on("open", () => {
  ws.send(JSON.stringify({
    type: "subscribe",
    channels: ["polymarket.edges.>=5"],
  }));
});

ws.on("message", (raw) => {
  const ev = JSON.parse(raw.toString());
  console.log(ev.market.game, ev.edge);
});
```

```python
# Python SDK
from alphaline import AlphaLine

client = AlphaLine(api_key=os.environ["ALPHALINE_API_KEY"])
markets = client.polymarket.markets.list(min_edge=5, sport="NBA")

for m in markets.data:
    print(m.game, m.pick, m.edge)
```

Supported channels: `polymarket.edges.>=N` · `signals.injury` · `signals.lineup` · `markets.{sport}`

---

## API Reference

**Base URL:** `https://api.alphaline.gg/v1`

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/markets` | List all markets with optional edge filter |
| `GET` | `/markets/:id` | Single market with full signal vector |
| `GET` | `/markets/:id/history` | Historical edge series for a market |
| `GET` | `/signals` | Recent signals across all leagues |
| `POST` | `/alerts` | Register a webhook for edge crossings |
| `WS` | `wss://stream.alphaline.gg/v1` | Real-time firehose |

Every market object includes:

```json
{
  "id": "mkt_nyk_okc_finals_g5",
  "sport": "NBA",
  "game": "Knicks @ Thunder — Finals Game 5",
  "pick": "Will Thunder win the championship tonight?",
  "market_prob": 0.76,
  "alpha_prob": 0.85,
  "edge": +0.09,
  "confidence": 0.93,
  "signal": {
    "type": "rest",
    "label": "OKC home closeout; Brunson ankle in doubt"
  },
  "polymarket_url": "https://polymarket.com/event/will-the-thunder-win-the-nba-championship",
  "updated_at": "2026-05-29T18:44:08.482Z"
}
```

---

## Coverage

| League | Markets |
|---|---|
| 🏀 **NBA** | Moneylines · spreads · totals · player props |
| 🏒 **NHL** | Moneylines · puck lines · totals · goalie-confirmed |
| ⚾ **MLB** | Moneylines · first-5 · totals · pitcher matchup models |
| 🏈 **NFL** | Moneylines · spreads · totals · weather-adjusted |

---

## Pricing

| Tier | Price | What you get |
|---|---|---|
| **Starter** | Free | Live markets, up to 25 alerts/day, 30-second latency, browser push |
| **Pro** | $19 USDC / mo | Sub-second latency, unlimited alerts + webhooks, player props, historical backtester, API (10k req/day) |
| **Desk** | Custom | Dedicated infrastructure, WebSocket firehose, custom signal feeds, SLA + on-call |

Payments settle in USDC on Solana. Pro includes a 14-day free trial — no card required.

---

## Stack

AlphaLine is built on Next.js 16, deployed on Vercel. The signal engine runs on a separate low-latency pipeline. The fair-value model is trained on eight seasons of game-level data and updated against live signal feeds. The Polymarket live-markets section fetches directly from the Polymarket Gamma API with no API key required.

---

## Links

| | |
|---|---|
| 🌐 **Site** | [alphaline.gg](https://alphaline.gg) |
| 📊 **Live markets** | [alphaline.gg/dashboard](https://alphaline.gg/dashboard) |
| ⚡ **API docs** | [alphaline.gg/developers](https://alphaline.gg/developers) |
| 💜 **Polymarket** | [polymarket.com/@mynameisdev](https://polymarket.com/@mynameisdev) |
| 🐦 **Twitter / X** | [@tryalphaline](https://x.com/tryalphaline) |
| 💻 **GitHub** | [github.com/tryalphaline](https://github.com/tryalphaline) |
| 📩 **Press** | press@alphaline.gg |
| 💼 **Sales** | hello@alphaline.gg |

---

<p align="center">
  <sub>AlphaLine is a research tool. Probabilities are illustrative; not financial or wagering advice. © 2026 AlphaLine.</sub>
</p>
