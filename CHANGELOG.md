# Changelog

All notable changes to AlphaLine are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- On-chain settlement contract (`contracts/AlphaLine.sol`) with full edge-alert lifecycle.
- Foundry test suite covering `createMarket`, `fileSignal`, `settleMarket`, `transferOwnership`.
- Foundry deploy script for Base mainnet and Base Sepolia (Circle native USDC).
- GitHub Actions CI: build, fmt-check, test, coverage.
- `SECURITY.md` — vulnerability disclosure policy.
- `CONTRIBUTING.md` — contributor guidelines.

### Changed
- Contract architecture: farming mechanics replaced with prediction-market edge signal verification.
- Signal types: `Injury · Lineup · Sharp · Weather · Sentiment · Rest · Travel`.
- Edge threshold: minimum 3% (300 bps) to file a signal on-chain.

## [0.2.0] — 2026-05-04

### Added
- `fileSignal` — files an edge alert on-chain with marketProb and alphaProb inputs.
- `settleMarket` — resolves a market as won or lost after Polymarket resolution.
- `edge(marketId)` — view returning the latest signal's edge in basis points.
- `EdgeAlertFired` event emitted on every signal that clears the minimum threshold.
- 7 signal types mapped to the AlphaLine signal taxonomy.

## [0.1.0] — 2026-03-10

### Added
- Initial `AlphaLine.sol` contract with `createMarket`, `fileSignal`, `settleMarket`.
- `Market`, `Signal`, `EdgeAlert` structs.
- Custom errors: `Unauthorized`, `MarketNotFound`, `MarketAlreadySettled`, `EdgeBelowMinimum`.
- Integration with Polymarket CLOB SDK v2 via Rust CLI (`src/`).

[Unreleased]: https://github.com/notyrjo/WheatWorld/compare/v0.2.0...HEAD
[0.2.0]:      https://github.com/notyrjo/WheatWorld/releases/tag/v0.2.0
[0.1.0]:      https://github.com/notyrjo/WheatWorld/releases/tag/v0.1.0
