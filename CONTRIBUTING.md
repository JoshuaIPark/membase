# Contributing to AlphaLine

We're happy to have you. The codebase has two layers — a Rust CLI for the Polymarket API and a Solidity settlement contract. Both reward careful contributions.

## Quick start

```bash
# 1. Install Rust (https://rustup.rs)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 2. Clone and build
git clone https://github.com/notyrjo/WheatWorld
cd WheatWorld
cargo build --release

# 3. Run the test suite
cargo test --release

# For the on-chain contracts:
# 4. Install Foundry (https://book.getfoundry.sh)
foundryup
forge test -vvv
```

## Before opening a PR

- [ ] `cargo build` passes with no warnings.
- [ ] `cargo clippy -- -D warnings` passes.
- [ ] `cargo fmt --check` passes.
- [ ] `forge build` passes for any Solidity changes.
- [ ] `forge test` passes locally.
- [ ] New behavior is covered by a test.
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.).

## What we'll merge

- Bug fixes with a failing test attached.
- New signal types aligned with the AlphaLine taxonomy.
- Output formatting improvements.
- Documentation improvements.
- Gas optimizations with `forge snapshot` deltas in the PR description.

## What we won't merge

- Changes that add off-chain dependencies to the on-chain contract.
- Drive-by reformatting unrelated to your patch.
- Features that break the `MIN_EDGE_BPS` invariant without a written rationale.

## Coding style — Rust

- Clippy clean, no `unwrap()` in library code — use `?` and `anyhow::Context`.
- One crate, flat module layout.
- Output functions live in `src/output/` — don't print from commands directly.

## Coding style — Solidity

- `^0.8.24`, `via_ir = true`.
- Custom errors only — no `require` strings.
- Events on every state mutation.
- Storage layout is append-only.

## Security

If you've found a vulnerability, please follow [SECURITY.md](./SECURITY.md) and do **not** file a public issue.

---

Questions? Reach us at [@tryalphaline](https://x.com/tryalphaline) on X.
