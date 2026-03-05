# Security Policy

## This is a Lab / Learning Repository

This repository is a **public learning lab** — a homelab platform for educational purposes.

## ⚠️ Important Notes

- **Do NOT use any credentials, tokens, or passwords from this repository in production**
- All passwords shown (e.g., `DevOpsLab2026!`) are **lab defaults** for learning purposes only
- All API tokens and PATs are **masked** (e.g., `ghp_****...`)
- Sealed Secrets in this repo are encrypted with a **lab-only cluster key** and are not reusable

## What to Do If You Find a Real Secret

If you accidentally find a real (unmasked) secret, token, or private key in this repository:

1. **Do not use it**
2. Open a GitHub Issue titled `[SECURITY] Found exposed credential`
3. Do NOT include the actual credential in the issue

## Replacing Credentials Before Use

Before using any configurations from this lab:

1. Replace all `DevOpsLab2026!` passwords with your own secure passwords
2. Generate your own Sealed Secrets using your cluster's public key
3. Create your own GitHub PAT with minimum required scopes
4. Regenerate all Strapi/N8N encryption keys

## Contact

- GitHub: [@shevchenkod](https://github.com/shevchenkod)
- LinkedIn: [Dmytro Shevchenko](https://www.linkedin.com/in/shevchenkod/)
