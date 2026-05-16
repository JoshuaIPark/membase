# Security Policy

## Supported Versions

| Version          | Supported |
| :--------------- | :-------: |
| `master` (latest)|     ✓     |
| Mainnet deploys  |     ✓     |
| Pre-audit tags   |     ✗     |

## Reporting a Vulnerability

If you've found a vulnerability in the AlphaLine protocol, **do not open a public issue**. We'd rather hear about it first.

- Email: `security@alphaline.gg`
- PGP key: published in this repository under `security/pgp.asc` (coming with the audit release).

Please include:

1. A clear description of the issue and its impact.
2. A minimal reproduction — Foundry test, transaction trace, or step-by-step.
3. Your name or handle if you'd like credit in the disclosure.

We will acknowledge receipt within **48 hours** and respond with a triage plan within **5 business days**.

## Scope

In-scope:

- `contracts/AlphaLine.sol` and any contracts deployed at addresses listed in `deployments/`.
- The deployment script `script/Deploy.s.sol`.

Out of scope:

- Front-end / off-chain indexer issues — please report those on the corresponding repositories.
- Issues that require privileged access (e.g. owner-only entry points used as intended).
- Theoretical issues without a viable on-chain attack path.

## Disclosure Policy

We follow coordinated disclosure. Once a vulnerability is reported, we will:

1. Reproduce and confirm the issue.
2. Develop and test a patch.
3. Notify affected users and partners.
4. Deploy the patch.
5. Publish a post-mortem within 30 days of resolution.

Responsible reporters are eligible for bounties from the AlphaLine treasury under our forthcoming bug bounty program. The amount scales with severity and quality of the report.

Thank you for keeping the protocol — and its players — safe.
