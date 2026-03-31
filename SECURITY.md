# Security Policy

## Supported Versions

| Version          | Supported |
| :--------------- | :-------: |
| `master` (latest)|     ✓     |
| Mainnet deploys  |     ✓     |
| Pre-audit tags   |     ✗     |

## Reporting a Vulnerability

If you've found a vulnerability in AlphaLine, **do not open a public issue**. We'd rather hear about it first.

- Email: `security@alphaline.gg`
- Response: within **48 hours**, triage within **5 business days**.

Please include:

1. A clear description of the issue and its impact.
2. A minimal reproduction — Foundry test, transaction trace, or step-by-step.
3. Your name or handle if you'd like credit in the disclosure.

## Scope

In-scope:

- `contracts/AlphaLine.sol` and any contracts deployed at addresses listed in `deployments/`.
- The deployment script `script/Deploy.s.sol`.
- The Rust CLI (`src/`) — specifically auth handling and key storage.

Out of scope:

- Polymarket infrastructure issues — report those to Polymarket directly.
- Issues requiring privileged access used as intended.
- Theoretical issues without a viable on-chain attack path.

## Disclosure Policy

We follow coordinated disclosure:

1. Reproduce and confirm.
2. Develop and test a patch.
3. Notify affected users and partners.
4. Deploy the patch.
5. Publish a post-mortem within 30 days.

Responsible reporters are eligible for bounties. Amount scales with severity and quality of the report.

Thank you for keeping AlphaLine safe.
