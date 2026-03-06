# AnniProxy Open-Source: Implementation Roadmap & Decisions

## Executive Summary

You're transforming AnniProxy from a **single-user IT support tool** into a **community-operated proxy service** with these priorities:

1. **Security** (no home network exposure, legal protection)
2. **Simplicity** (B: zero-friction login + A: privacy through transparency)
3. **Extensibility** (C: niche use cases like IT support, D: community operation later)
4. **Portability** (Windows first, then macOS/Linux)

This document outlines the **concrete decisions** and **implementation phases** to get you there.

---

## Decision Matrix: Key Architectural Choices

### Decision 1: Backend Language

| Factor | Python | Go | Rust |
|--------|--------|----|----|
| **Learning curve** | Easy (you probably know it) | Medium | Hard |
| **RPi4 performance** | Good (async) | Excellent | Excellent |
| **Development speed** | Fast | Fast | Slow |
| **Deployment** | venv + pip | Single binary | Single binary |
| **SOCKS5 libraries** | Mature (aiosocks5, pysocks) | Good (golang.org/x/net/socks5) | Good (tokio-socks5) |
| **Dependencies** | Python runtime needed | None | None |

**RECOMMENDATION: Python 3.9+**
- Fastest to prototype
- RPi4 has Python built-in
- Rich ecosystem for SOCKS5, OAuth, async I/O
- Sufficient performance for single-operator service
- Easy to debug and modify

---

### Decision 2: SOCKS5 Implementation

| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| **Custom SOCKS5 server (raw sockets)** | Full control, minimal deps | Complex (RFC 1928), error-prone | 3-4 weeks |
| **Use existing library (aiosocks5)** | Battle-tested, async-friendly | Depends on library quality | 2-3 days to integrate |
| **Wrap OpenSSH server** | Proven, mature | Overkill, extra complexity | 1 week |
| **Use Caddy + plugins** | Lightweight, HTTPS-native | Less direct control | 3-4 days |

**RECOMMENDATION: Python `aiosocks5` library + custom token auth middleware**
- Library handles SOCKS5 RFC compliance
- You add token validation layer on top
- Async-native (integrates with FastAPI event loop)
- ~50 lines of code to add auth

---

### Decision 3: OAuth Providers

| Provider | Setup effort | User base | Support auth code |
|----------|--------------|-----------|-------------------|
| **Google** | Easy (1-2 hours) | Massive | Yes |
| **GitHub** | Easy (1-2 hours) | Tech-savvy users | Yes |
| **Cloudflare** | Medium (2-3 hours) | Smaller but overlaps with your target | Yes |
| **Custom OIDC** | Hard (1 week) | Only if you need it | Yes |

**RECOMMENDATION: Google + GitHub (Phase 1)**
- Both are RFC 6749 (OAuth 2.0) compliant
- Users already have accounts
- Gives non-tech users choice
- Add Cloudflare later if demand exists

**Flow:**
```
User clicks "Login with Google"
  → Redirect to: https://accounts.google.com/o/oauth2/v2/auth?client_id=...
  → Google shows consent screen
  → User clicks "Allow"
  → Google redirects to: https://auth.yourdomain.com/auth/oauth/callback?code=...&state=...
  → Your backend exchanges code for user info (email, picture, etc.)
  → Your backend issues token
  → Browser receives token
  → AnniProxy stores token locally
```

---

### Decision 4: Token Storage (Client-Side)

| Method | Security | Cross-platform | Effort | Downside |
|--------|----------|-----------------|--------|----------|
| **Windows Credential Manager** | Excellent (OS-encrypted) | Windows only | Easy (2 hours) | Not portable |
| **DPAPI encryption to file** | Good (OS encryption) | Windows only | Easy (2 hours) | More manual |
| **Keyring library** | Excellent | Cross-platform | Medium (1 day) | Extra dependency |
| **Plain file** | Poor ❌ | Cross-platform | Easy | Security nightmare |

**RECOMMENDATION: Windows Credential Manager (Phase 1), Keyring (Phase 3 for macOS/Linux)**
- Windows Credential Manager is built-in, zero extra dependencies
- Automatic OS-level encryption
- Standard Windows practice
- When you add macOS/Linux, switch to `keyring` library (cross-platform wrapper)

---

### Decision 5: HTTPS for OAuth Server

| Method | Effort | Cost | Pros | Cons |
|--------|--------|------|------|------|
| **Cloudflare Tunnel (easiest)** | 2 hours | Free | No port forwarding, DDoS protection, simple | Third-party dependency |
| **Let's Encrypt + nginx** | 4 hours | Free | Full control, portable, standard | Manual cert renewal |
| **Self-signed + IP allow-list** | 1 hour | Free | Quick MVP | Won't work for OAuth (browsers reject) |

**RECOMMENDATION: Cloudflare Tunnel (MVP), migrate to nginx later if you want independence**
- You already have Cloudflare (Cloudflare Access for SSH)
- Zero configuration for HTTPS
- Builtin DDoS protection
- Easy to manage from Cloudflare dashboard

**Phase 2 (if leaving Cloudflare):** nginx + Let's Encrypt + auto-renewal with `certbot`

---

### Decision 6: Database

| Option | Data volume | Scaling | Setup | Maintenance |
|--------|------------|---------|-------|-------------|
| **SQLite** | Up to 1M users | None (file-based) | Instant | Minimal (backup file) |
| **PostgreSQL** | Unlimited | Horizontal | 1-2 hours | Regular maintenance |
| **MySQL** | Unlimited | Horizontal | 1-2 hours | Regular maintenance |
| **Redis** | In-memory cache | Moderate | 1 hour | Memory management |

**RECOMMENDATION: SQLite (Phase 1-2), PostgreSQL (Phase 3+ if scaling)**
- You're a single operator, not a VPN company
- SQLite is zero-overhead, zero-administration
- File-based (easy backups: copy one file)
- Sufficient for 10K-100K users
- If you ever scale beyond 100K, migrate to PostgreSQL (minimal code changes, same SQL)

---

## Implementation Phases & Timeline

### Phase 1: MVP (Weeks 1-3)
**Goal:** Minimal working backend + Windows client with OAuth

#### Backend (Python)
- [ ] FastAPI server with OAuth2 (Google + GitHub)
- [ ] SQLite schema (users, tokens, sessions, audit_log)
- [ ] SOCKS5 server + token auth layer
- [ ] Token issuance/refresh/validation
- [ ] Rate limiting (prevent auth spam)
- [ ] Audit logging (legal protection)
- [ ] Basic error handling

**Deliverable:** Python app that starts on RPi4, serves OAuth login, and proxies SOCKS5 traffic

**Estimated effort:** 80-100 hours (including testing)

**Code structure:**
```
backend/
├── main.py                    (entry point)
├── auth_server.py             (FastAPI + OAuth)
├── socks5_server.py           (SOCKS5 + auth)
├── database.py                (SQLite schema + helpers)
├── config.py                  (config loading, .env)
├── requirements.txt           (dependencies)
├── .env.example               (template for secrets)
└── tests/                     (unit + integration tests)
```

#### Windows Client
- [ ] `oauth-login.ps1` module (browser redirect + callback listener)
- [ ] `token-storage.ps1` module (Credential Manager integration)
- [ ] `managed-backend.ps1` module (orchestration)
- [ ] Update `main.ps1` to support both modes (legacy SSH + managed backend)
- [ ] Config.json updated with managed backend settings

**Deliverable:** AnniProxy Windows that can login to backend and launch Brave

**Estimated effort:** 30-40 hours

#### Legal
- [ ] Draft Terms of Service
- [ ] Draft Privacy Policy
- [ ] Draft Acceptable Use Policy

**Deliverable:** Legal templates (you review + customize for your jurisdiction)

**Estimated effort:** 8-10 hours

#### Testing
- [ ] End-to-end: OAuth login → token storage → SOCKS5 connection → Brave launch
- [ ] Error handling: backend down, network error, revoked user
- [ ] Security: token not logged, HTTPS enforced, rate limiting works

**Estimated effort:** 20-30 hours

**PHASE 1 TOTAL: 140-180 hours (~3-4 weeks full-time, or 2-3 months part-time)**

---

### Phase 2: Hardening & Operations (Weeks 4-5)

#### Backend
- [ ] Admin dashboard (HTML, private URL)
  - Active sessions
  - User management (search, revoke)
  - Audit log viewer
  - Usage stats (bandwidth, login attempts)
  - Health metrics (uptime, DB size, errors)
- [ ] Token refresh mechanism (automatic before expiry)
- [ ] Better error messages (distinguish auth failure from network error)
- [ ] Logging (structured logs, rotate, compress)
- [ ] Client log docs: `client/.log/session`, `client/.log/ssh`, `client/.log/brave` (`logLevel` filters console; 0-byte logs pruned on shutdown)
- [ ] Metrics collection (for future monitoring)
- [ ] Graceful shutdown (close active sessions cleanly)

#### Windows Client
- [ ] Token auto-refresh (silent, before expiry)
- [ ] Better error messages (copy-paste friendly)
- [ ] Installer wizard (optional, nicer UX than batch file)
- [ ] Update checker (notify when new version available)
- [ ] Uninstaller (clean token from Credential Manager)

#### Documentation
- [ ] User guide (how to install and use)
- [ ] Troubleshooting guide (common errors + fixes)
- [ ] Architecture diagram (explain the flow)
- [ ] API docs (if you want others to build clients)
- [ ] Operator guide (how to run backend on RPi4)

#### Deployment
- [ ] systemd service file for RPi4
- [ ] Backup strategy for SQLite (daily backup script)
- [ ] Log rotation + archival
- [ ] Monitoring setup (health checks, alerts)

**PHASE 2 TOTAL: 100-120 hours (~2-3 weeks)**

---

### Phase 3: Transparency & Public Launch (Weeks 6-7)

#### Frontend
- [ ] Public website (GitHub Pages or simple HTML)
  - What is AnniProxy?
  - Why use it? (Privacy, simplicity, trust)
  - How to use it (download, install, authenticate)
  - Terms of Service + Privacy Policy
  - Transparency report (monthly stats)
  - Contact form / email for questions

#### Backend
- [ ] Public dashboard (anonymized stats)
  - Active users (count, not names)
  - Data transferred (aggregate, no per-user breakdown)
  - Uptime percentage
  - Latest security incidents (if any)

#### Community
- [ ] GitHub repository (public, open-source code)
  - README with installation + development instructions
  - Contributing guidelines
  - Issue template for bug reports
  - License (MIT or similar)
  - Changelog

#### Legal
- [ ] Publish finalized ToS + Privacy Policy
- [ ] Set up DMCA / abuse reporting process
- [ ] Prepare for data requests (Law Enforcement Guide)

**PHASE 3 TOTAL: 60-80 hours (~1-2 weeks)**

---

### Phase 4: Scale & Multi-Platform (Weeks 8+)

#### macOS Client
- [ ] Port AnniProxy to macOS (Swift or Python + PyQt)
- [ ] Use Keyring library for token storage (portable, secure)
- [ ] DMG installer

#### Linux Client
- [ ] Port to Linux (Python + Qt, or web-based)
- [ ] Snap / AppImage packaging
- [ ] Manual installation instructions

#### Backend Enhancements
- [ ] Add Cloudflare OAuth provider
- [ ] Add email-based auth (alternative to social login)
- [ ] WebRTC leak detection (verify users' real IP stays hidden)
- [ ] Bandwidth limits (per-user, optional)
- [ ] Usage analytics (opt-in, aggregate)

#### Optional: Multi-Operator
- [ ] Federation (multiple RPi4 operators, shared user list)
- [ ] Community-run backend network

**PHASE 4 TIMELINE: 3-6 months**

---

## Decision Questions for You

Answer these to finalize architecture:

### 1. SOCKS5 Encryption
Currently: Plain SOCKS5 (traffic encrypted only if destination uses HTTPS)

Options:
- **A) Keep plain SOCKS5 (MVP)** - Simpler, sufficient for most uses
- **B) Wrap SOCKS5 in TLS** - More secure but more complex
- **C) Use SSH tunnel instead** - Proven, but adds overhead

**Recommendation:** A for MVP, revisit in Phase 2

### 2. User Limit
How many concurrent users do you expect in Year 1?

- < 100? → SQLite is overkill, but fine to start
- 100-1000? → SQLite is perfect
- 1000-10000? → SQLite works, but monitor closely
- > 10000? → Plan for PostgreSQL from start

**My guess:** Start with 10-100, grow to 1000 max. SQLite is fine.

### 3. Backup Strategy
RPi4 failure = service down + user data (audit logs) at risk

Options:
- **A) Manual daily backup** (you copy DB file to external drive)
- **B) Automated backup to cloud** (rsync to S3 / B2 / GitHub)
- **C) Database replication** (secondary RPi4 as backup)

**Recommendation:** B (automated) - takes 2 hours to set up, saves headaches

### 4. Public vs Private
Who can sign up for AnniProxy?

- **Open:** Anyone with Google/GitHub account (potential abuse)
- **Invite-only:** You whitelist email addresses (harder to grow)
- **Hybrid:** Open, but with strong ToS + revocation (best for MVP)

**Recommendation:** Open + strong ToS. Revoke bad actors quickly.

### 5. Monetization (Later)
When Phase 1-3 are stable, do you want:

- **A) Donations only** (tip jar, no obligation)
- **B) Optional subscriptions** ("Premium" features like higher bandwidth)
- **C) Freemium model** (free tier + paid premium)
- **D) None, pure community** (no money, pure passion project)

**My take:** A initially. If load becomes expensive, add B. Don't complicate Phase 1.

---

## Risk Mitigation

### Risk 1: Legal Liability
**Scenario:** Someone uses AnniProxy for illegal activity, law enforcement contacts you.

**Mitigation:**
- Clear ToS + AUP (you're not liable if user violates)
- Audit logs (you can prove who did what, when)
- Revocation capability (show you take abuse seriously)
- Keep logs for 90 days (balance privacy + legal)
- Consult lawyer for jurisdiction (if you want to be extra safe)

**Action:** Draft ToS now (Phase 1), have lawyer review before public launch (Phase 3)

### Risk 2: Resource Exhaustion
**Scenario:** Malicious user connects 10,000 sessions, RPi4 runs out of memory.

**Mitigation:**
- Rate limiting (max 10 logins per IP per hour)
- Session limits (max 5 concurrent sessions per user)
- Connection timeout (auto-disconnect after 1 hour idle)
- Monitor memory (alert if > 80%)

**Action:** Implement in Phase 2

### Risk 3: Token Compromise
**Scenario:** Someone steals a user's stored token, uses it from different IP.

**Mitigation:**
- No IP locking (too restrictive, breaks traveling users)
- Session logging (show users active sessions, let them revoke)
- Optional: GeoIP warnings (alert user if token used from new country)
- User dashboard (let them see who's using their token)

**Action:** Phase 2 (basic session logging), Phase 3 (user dashboard)

### Risk 4: RPi4 Reliability
**Scenario:** RPi4 crashes, all users can't connect.

**Mitigation:**
- Auto-restart service (systemd with Restart=always)
- Health checks (monitor process, restart if dead)
- Backup power (UPS for RPi4)
- Backup backend (secondary RPi4, manual failover)

**Action:** Phase 2 (health checks + auto-restart), Phase 3+ (backup RPi4)

---

## Timeline Summary

```
Week 1-2: Backend MVP
  - FastAPI + OAuth (Google + GitHub)
  - SOCKS5 server + token auth
  - SQLite schema
  - Cloudflare Tunnel setup

Week 3: Windows Client + Testing
  - oauth-login.ps1 + token-storage.ps1
  - Update main.ps1
  - End-to-end testing
  - Fix bugs

Week 4: Draft Legal Docs
  - ToS, Privacy Policy, AUP
  - Review with lawyer (optional but recommended)

Week 5: Hardening
  - Admin dashboard
  - Token refresh
  - Better error handling
  - User guide

Week 6-7: Public Launch
  - Website + documentation
  - Public GitHub repo
  - Publish ToS/Privacy
  - Announcement (Twitter, Reddit, Hacker News if you want)

Week 8+: Iterate + Expand
  - Fix bugs from early users
  - Add macOS/Linux support
  - Community feedback
  - Optional: Add Cloudflare OAuth, email auth, etc.
```

---

## What I'll Do Next (Your Call)

Once you confirm a few decisions above, I can:

### Option A: Full Implementation
Provide **complete, production-ready Python code** for:
- FastAPI OAuth server
- SOCKS5 server with token auth
- SQLite schema + helpers
- Admin dashboard
- Ready to deploy to RPi4

### Option B: Detailed Pseudocode
Detailed pseudocode + architecture docs (what you see here, but with more code)

### Option C: Reference Implementation
Small, minimal working example (100-200 lines) that you can expand

**I recommend Option A:** I can deliver full backend code within 2-3 days. You can start deploying immediately.

---

## Quick Wins (Do These Now)

Even before finalizing all decisions, you can:

1. **Create GitHub repo** (template: `github.com/yourusername/annproxy-public`)
   - Add README (project vision)
   - Add LICENSE (MIT recommended)
   - Add CONTRIBUTING.md

2. **Register domain** (if you don't have one)
   - `yourname-annproxy.com` or `annproxy.io`
   - Set up Cloudflare (for tunnel + DDoS protection)

3. **Draft legal docs** (I provided templates)
   - Customize for your jurisdiction
   - Optional: consult a lawyer

4. **Set up RPi4 basics**
   - SSH access configured
   - Static IP assigned
   - Cloudflare Tunnel installed + running (for other services)

5. **Plan data architecture**
   - Decide on backup strategy
   - Set up monitoring

---

## Questions for Me?

I'm ready to:
- [ ] Provide full Python backend code (FastAPI + SOCKS5 + OAuth)
- [ ] Write detailed setup instructions for RPi4
- [ ] Create installer/packaging scripts
- [ ] Draft additional documentation (troubleshooting, operator guide, etc.)
- [ ] Help with security review (before public launch)
- [ ] Design admin dashboard UI
- [ ] Plan cross-platform support (macOS/Linux roadmap)

What would be most helpful next?