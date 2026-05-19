# Contributing to AlphaLine

We're happy to have you. The protocol is small enough to read in an afternoon and rewards careful contributions.

## Quick start

```bash
# 1. Install Foundry (https://book.getfoundry.sh)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Clone + install dependencies
git clone https://github.com/neilhtennek/wheat-world
cd wheat-world
forge install

# 3. Run the test suite
forge test -vvv
```

## Before opening a PR

- [ ] `forge build` passes with no warnings.
- [ ] `forge fmt --check` passes.
- [ ] `forge test` passes locally.
- [ ] New behavior is covered by a test under `test/`.
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.).

## What we'll merge

- Bug fixes with a failing test attached.
- Gas optimizations with `forge snapshot` deltas in the PR description.
- Documentation improvements.
- New features that fit the protocol scope — talk to us in an issue first if the change is non-trivial (>50 LoC or touches token flow).

## What we won't merge

- Changes that introduce off-chain dependencies in `contracts/`.
- Drive-by reformatting unrelated to your patch.
- Features that require a non-Base chain (the protocol is opinionated about its home).
- Anything that breaks the `MAX_PLOTS_PER_WALLET` invariant or the abandon-burn split without a written rationale.

## Coding style

- Solidity `^0.8.24`, `via_ir = true`.
- Storage layout is sacred — append, don't rearrange.
- Custom errors only, no `require` strings.
- Events on every state mutation that a UI would care about.
- Tier / multiplier values live as `constant`, never as storage.

## Security

If you've found a vulnerability, please follow [SECURITY.md](./SECURITY.md) and do **not** file a public issue.

---

Questions? Reach us at [@TheAlphaLine](https://x.com/TheAlphaLine) on X.
