# Security Policy

## Supported Versions

Security fixes are handled for the latest public release of Agent Island.

| Version | Supported |
| --- | --- |
| 1.0.x | Yes |

## Reporting a Vulnerability

If you find a security issue, please report it privately through GitHub Security Advisories when available:

https://github.com/tristan666666/agent-island/security/advisories/new

If that route is not available, open a GitHub issue with a minimal description and avoid posting sensitive logs, access tokens, OAuth data, or local transcript contents. I will ask for private details only if they are needed to reproduce the issue.

## Scope

Useful reports include:

- A way for Agent Island to expose Claude Code or Codex session contents unexpectedly.
- Incorrect handling of local credentials, OAuth refresh state, or usage API responses.
- Auto-resume behavior that can trigger outside the user-configured session or without explicit opt-in.
- Packaging, update, or release integrity issues.

Out of scope:

- Vulnerabilities in Claude Code, Codex, GitHub, Sparkle, macOS, or other upstream services unless Agent Island introduces additional risk.
- Reports that require disabling normal macOS security controls.
- Social engineering, spam, or denial-of-service reports without a concrete Agent Island bug.

## Local Data Boundary

Agent Island is designed as a local-first macOS app. Still, bug reports can accidentally contain sensitive data from terminal sessions, local transcripts, or provider tokens. Please redact secrets and private project content before sharing any reproduction material.
