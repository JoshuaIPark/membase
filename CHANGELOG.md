# Changelog

All notable changes to the AlphaLine protocol contracts are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Foundry test suite with 14 cases covering claim/abandon/upgrade/exchange/tribes/yield math.
- Foundry deploy script for Base mainnet and Base Sepolia (Circle native USDC).
- GitHub Actions CI: build, fmt-check, test, coverage.
- `SECURITY.md` — vulnerability disclosure policy.
- `CONTRIBUTING.md` — contributor guidelines.

### Changed
- Brand: AlphaLine → AlphaLine across the README and contracts.
- Chain: Solana / Anchor program rewritten as Base / Solidity (`contracts/AlphaLine.sol`).

## [0.1.0] — 2026-05-04

### Added
- Initial protocol contract with `Plot`, `PlotOffer`, `Order`, `Tribe`, `Alliance` accounts.
- `claimPlot`, `abandonPlot`, `upgradePlot` — staking lifecycle with USDC vault.
- `listPlot`, `acceptPlotOffer`, `cancelPlotOffer` — P2P plot exchange with optimistic concurrency.
- `placeOrder`, `_matchBook` — continuous order book for crops, 2.5% protocol fee, self-match guard.
- `createTribe`, `joinTribe`, `createAlliance`, `joinAlliance` — social systems with member caps.
- `harvest` and `computeYield` — multiplicative yield engine (tier × upgrade × tribe × alliance × Golden Hour).
- `isGoldenHour` — deterministic 6-hour cycle, 1-hour window, no oracle.
- 5-plot-per-wallet cap, enforced at contract level.
- Abandon mechanics: 50% burn, 50% to protocol treasury.

[Unreleased]: https://github.com/alexinbinary/AlphaLine/compare/v0.1.0...HEAD
[0.1.0]:      https://github.com/alexinbinary/AlphaLine/releases/tag/v0.1.0
