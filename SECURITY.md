# Security Policy

Runtahio is a local-only macOS utility: it makes no network requests and has no server
component. The main security surface is the local filesystem — scanning paths and moving
items to the Trash. We take that seriously and appreciate responsible disclosure.

## Supported versions

Runtahio is pre-1.0 and ships from `main`. Security fixes are applied to the latest
release and to `main`.

| Version | Supported |
| ------- | --------- |
| latest `main` / newest release | ✅ |
| older releases | ❌ |

## Reporting a vulnerability

**Please do not report security issues in public GitHub issues.**

Preferred: open a private report via GitHub Security Advisories —
<https://github.com/cupskeee/runtahio/security/advisories/new>.

Alternatively, email **yusufrc7@gmail.com** with:

- A description of the issue and its impact.
- Steps to reproduce (paths/sizes are fine — please don't include private file contents).
- The Runtahio version/commit and your macOS version.

We aim to acknowledge reports within **7 days** and to provide a remediation timeline
after triage. Please give us a reasonable window to fix the issue before any public
disclosure.

## Scope

Issues of particular interest:

- Any path that could lead to **permanent data loss** (Runtahio is designed to be
  Trash-only and to refuse protected/system paths).
- Bypasses of the **protected-path policy** that let a system/root location be staged
  for removal.
- Any code path that performs **network access** or leaks file metadata off-device
  (there should be none).
- Reading or materializing **file contents** when only metadata is expected.

## Out of scope

- Issues requiring a already-compromised machine or root access.
- The documented limitation that ad-hoc-signed rebuilds require re-granting Full Disk
  Access.
