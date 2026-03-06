# AnniProxy Development Roadmap

**Last Updated:** March 4, 2026

This document outlines the development roadmap for AnniProxy. It serves as a guide for contributors, users, and the community about where the project is heading.

---

## Overview

AnniProxy is transitioning from a **single-user IT support tool** to a **community-operated proxy service**. The roadmap is organized into 5 phases over 6-9 months.

**Current Status:** Phase 1 (MVP Development)

---

## Phase 1: Windows MVP (March - April 2026)

**Goal:** Launch a minimum viable product with Windows support and OAuth authentication.

**Timeline:** 3-4 weeks (starting March 4, 2026)

### Backend (Python/FastAPI)

- [ ] **OAuth2 Server**
  - [ ] Google OAuth integration
  - [ ] GitHub OAuth integration
  - [ ] Token issuance and validation
  - [ ] Rate limiting (prevent auth spam)
  - [ ] Error handling and logging

- [ ] **SOCKS5 Proxy Server**
  - [ ] Token-based authentication (username/password via SOCKS5)
  - [ ] Connection logging (IP, timestamp, bytes)
  - [ ] Session management
  - [ ] Graceful shutdown

- [ ] **Database (SQLite)**
  - [ ] User schema (email, OAuth identity, created_at, revoked)
  - [ ] Token schema (user_id, token, expires_at, last_used_at)
  - [ ] Session schema (token_id, client_ip, connected_at, bytes_sent/received)
  - [ ] Audit log schema (user_id, action, timestamp, details)

- [ ] **Configuration**
  - [ ] `.env` file for secrets (OAuth credentials, JWT secret, admin password)
  - [ ] `config.json` for non-secret settings (ports, TTL, rate limits)
  - [ ] Configuration validation

- [ ] **Deployment**
  - [ ] Systemd service file for RPi4
  - [ ] Setup instructions (Python venv, pip install, first-run setup)
  - [ ] Cloudflare Tunnel integration (for HTTPS)
  - [ ] Documentation

### Windows Client (PowerShell)

- [ ] **OAuth Login Module** (`oauth-login.ps1`)
  - [ ] Browser redirect to OAuth server
  - [ ] Local HTTP callback listener
  - [ ] Token extraction and validation
  - [ ] Timeout handling (30 second timeout)
  - [ ] Error messaging

- [ ] **Token Storage Module** (`token-storage.ps1`)
  - [ ] Windows Credential Manager integration
  - [ ] Token encryption (OS-level)
  - [ ] Token retrieval on next run
  - [ ] Token deletion/cleanup

- [ ] **Managed Backend Module** (`managed-backend.ps1`)
  - [ ] First-run OAuth flow orchestration
  - [ ] SOCKS5 connection validation
  - [ ] Backend server health check

- [ ] **SOCKS5 Client Module** (`socks5-client.ps1`)
  - [ ] Connect to remote SOCKS5 server
  - [ ] Token-based authentication
  - [ ] Process lifecycle management

- [ ] **Main Configuration Updates** (`main.ps1`)
  - [ ] Support dual-mode (local SSH vs managed backend)
  - [ ] Config.json schema updates
  - [ ] Backward compatibility (existing SSH users unaffected)

### Legal & Documentation

- [ ] **Terms of Service**
  - [ ] Acceptable Use Policy (no illegal activity)
  - [ ] Service warranty disclaimer
  - [ ] Revocation rights

- [ ] **Privacy Policy**
  - [ ] What data we collect
  - [ ] How we use it
  - [ ] Data retention periods
  - [ ] User rights (access, delete, export)

- [ ] **README.md** (Public-facing)
  - [ ] Project overview
  - [ ] Quick start guide
  - [ ] Architecture diagram
  - [ ] Use cases
  - [ ] FAQ

### Testing

- [ ] **End-to-End Testing**
  - [ ] OAuth login flow (Google + GitHub)
  - [ ] Token storage and retrieval
  - [ ] SOCKS5 connection with token auth
  - [ ] Brave browser launch with proxy

- [ ] **Error Handling Tests**
  - [ ] Backend server down
  - [ ] Network timeout
  - [ ] Invalid token
  - [ ] Revoked user
  - [ ] Port already in use

- [ ] **Security Tests**
  - [ ] Token not logged in plaintext
  - [ ] HTTPS enforced for OAuth
  - [ ] Rate limiting works
  - [ ] Revocation is instant

**Deliverable:** Functional Windows application with OAuth login and working proxy.

**Success Criteria:**
- User can install AnniProxy
- User can authenticate with Google or GitHub
- User's token is stored securely
- Brave launches with SOCKS5 proxy enabled
- Traffic routes through backend successfully
- Revoked users cannot connect

---

## Phase 2: Hardening & Operations (April - May 2026)

**Goal:** Production-harden the MVP and add operational capabilities.

**Timeline:** 2-3 weeks (after Phase 1)

### Backend Enhancements

- [ ] **Admin Dashboard**
  - [ ] Private admin URL (`/admin/dashboard`)
  - [ ] Password-protected access
  - [ ] Active sessions display (count, IPs, duration)
  - [ ] User management (search, view, revoke)
  - [ ] Audit log viewer (searchable, filterable)
  - [ ] Usage statistics (bandwidth, login attempts, errors)
  - [ ] Health metrics (uptime, DB size, error rates)

- [ ] **Token Refresh**
  - [ ] Automatic refresh before expiry
  - [ ] `POST /auth/refresh_token` endpoint
  - [ ] Token rotation (issue new token, invalidate old)
  - [ ] Smooth experience (no re-login needed)

- [ ] **Better Error Handling**
  - [ ] Distinguish network errors from auth failures
  - [ ] Helpful error messages (not just "401 Unauthorized")
  - [ ] Error logging with context
  - [ ] User-facing error explanations

- [ ] **Logging & Monitoring**
  - [ ] Structured logging (JSON format)
  - [ ] Log rotation (daily, compress old logs)
  - [ ] Metrics collection (for future monitoring)
  - [ ] Health check endpoint

- [ ] **Database Maintenance**
  - [ ] Backup automation (hourly snapshots)
  - [ ] Retention policy implementation (90-day audit log cleanup)
  - [ ] Database integrity checks

### Windows Client Enhancements

- [ ] **Token Auto-Refresh**
  - [ ] Check token expiry on startup
  - [ ] Refresh if < 7 days to expiry
  - [ ] Silent refresh (no user interaction)
  - [ ] Error handling if refresh fails

- [ ] **Better Error Messages**
  - [ ] Clear, non-technical language
  - [ ] Actionable suggestions
  - [ ] Links to troubleshooting guide
  - [ ] Copy-paste friendly format

- [ ] **Update Checker** (Optional)
  - [ ] Notify user of new versions
  - [ ] Automatic update mechanism
  - [ ] Rollback support if update fails

- [ ] **Uninstaller**
  - [ ] Remove token from Credential Manager
  - [ ] Clean up local files
  - [ ] Deregister with backend

### Documentation

- [ ] **User Guide**
  - [ ] Installation instructions (step-by-step)
  - [ ] First-run setup
  - [ ] Managing tokens/sessions
  - [ ] Uninstall process

- [ ] **Troubleshooting Guide**
  - [ ] Common errors and solutions
  - [ ] Log file locations and interpretation (`client/.log/session`, `client/.log/ssh`, `client/.log/brave`)
  - [ ] Explain `logLevel` (console filtering) vs session logs (always written)
  - [ ] Note: 0-byte log files are pruned on shutdown
  - [ ] Network connectivity issues
  - [ ] OAuth provider issues

- [ ] **Architecture Documentation**
  - [ ] System design overview
  - [ ] OAuth flow diagram
  - [ ] Token lifecycle
  - [ ] SOCKS5 proxy flow

- [ ] **Operator Guide** (for RPi4 backend)
  - [ ] System requirements
  - [ ] Installation and configuration
  - [ ] Monitoring and alerting
  - [ ] Backup and disaster recovery
  - [ ] Performance tuning

- [ ] **API Documentation** (if opening API to third parties)
  - [ ] OAuth endpoints
  - [ ] Token validation endpoint
  - [ ] Admin API endpoints

### Deployment

- [ ] **RPi4 Setup Automation**
  - [ ] Install script (downloads Python, venv, dependencies)
  - [ ] Systemd service setup
  - [ ] Cloudflare Tunnel automatic configuration
  - [ ] Health check automation

- [ ] **Backup Strategy**
  - [ ] Automated daily database backup
  - [ ] Backup retention policy (30-day rolling window)
  - [ ] Restore procedure documentation

- [ ] **Monitoring Setup**
  - [ ] Health check endpoint (`GET /health`)
  - [ ] Uptime monitoring (e.g., using uptime robot)
  - [ ] Error alerting (e.g., if error rate > 5%)

**Deliverable:** Production-ready backend with admin dashboard and robust error handling.

**Success Criteria:**
- Admin dashboard fully functional
- Token refresh works transparently
- Automated backups working
- Error messages are helpful
- Complete operator documentation

---

## Phase 3: Transparency & Public Launch (May - June 2026)

**Goal:** Public launch with transparency and community building.

**Timeline:** 2-3 weeks (after Phase 2)

### Frontend & Marketing

- [ ] **Public Website**
  - [ ] Landing page (what is AnniProxy, why use it)
  - [ ] Getting started guide
  - [ ] FAQ section
  - [ ] Blog/news section (for updates)
  - [ ] Community links (Discord, GitHub)

- [ ] **Transparency Report** (optional but recommended)
  - [ ] Monthly active users
  - [ ] Data transferred (aggregate)
  - [ ] Service uptime percentage
  - [ ] Security incidents (if any)
  - [ ] Law enforcement requests (if applicable)

- [ ] **Public Dashboard** (anonymized stats)
  - [ ] Real-time user count (no PII)
  - [ ] Bandwidth usage (aggregate)
  - [ ] Uptime status
  - [ ] Latest version

### Community & Open Source

- [ ] **GitHub Repository (Public)**
  - [ ] Source code release (Apache 2.0 license)
  - [ ] Contributing guidelines (`CONTRIBUTING.md`)
  - [ ] Code of conduct
  - [ ] Issue templates (bug report, feature request)
  - [ ] PR templates
  - [ ] Release notes / Changelog

- [ ] **Community Engagement**
  - [ ] Discord server setup
  - [ ] GitHub Discussions enabled
  - [ ] Regular updates (weekly/monthly)
  - [ ] Community calls (optional, monthly)

### Legal & Compliance

- [ ] **Finalized Legal Documents**
  - [ ] Terms of Service (lawyer-reviewed, if budget allows)
  - [ ] Privacy Policy (finalized)
  - [ ] Acceptable Use Policy (finalized)

- [ ] **Abuse & DMCA Process**
  - [ ] Abuse reporting form/email
  - [ ] DMCA takedown process
  - [ ] Data request guidelines (for law enforcement)

- [ ] **Incident Response Plan**
  - [ ] Security incident procedure
  - [ ] Data breach notification process
  - [ ] User communication plan

### Release & Announcement

- [ ] **Windows Installer Package**
  - [ ] Code signing (optional but recommended for trust)
  - [ ] Auto-update mechanism
  - [ ] SHA256 checksum verification

- [ ] **Public Announcement**
  - [ ] Blog post (on yumehana.dev when ready)
  - [ ] Discord announcement
  - [ ] GitHub release announcement
  - [ ] Reddit/Hacker News (optional)

**Deliverable:** Public-facing project with documentation, website, and community infrastructure.

**Success Criteria:**
- Source code published on GitHub
- Website live
- Privacy policy and ToS published
- First 50-100 public users onboarded
- No critical bugs reported
- Community engaged (Discord active, GitHub issues being triaged)

---

## Phase 4: Multi-Platform Support (June - August 2026)

**Goal:** Expand to macOS and Linux.

**Timeline:** 6-8 weeks (concurrent with Phase 3/4)

### macOS Client

- [ ] **Native macOS Application**
  - [ ] Rewrite or wrap Windows client for macOS (Swift or Python + PyQt)
  - [ ] Use Keychain for token storage (cross-platform secure storage)
  - [ ] DMG installer
  - [ ] Code signing and notarization (Apple requirements)

- [ ] **Testing**
  - [ ] Intel and Apple Silicon (M1/M2) support
  - [ ] OS compatibility (10.14+)
  - [ ] Proxy integration (system-wide or app-level)

### Linux Client

- [ ] **Linux Application**
  - [ ] Command-line interface (CLI) or GTK+ GUI
  - [ ] Snap packaging (Ubuntu)
  - [ ] AppImage (universal Linux)
  - [ ] Debian/RPM packages

- [ ] **Token Storage**
  - [ ] Use `keyring` library (cross-platform)
  - [ ] KDE Wallet integration
  - [ ] GNOME Keyring integration

- [ ] **Testing**
  - [ ] Ubuntu 20.04+, Fedora, etc.
  - [ ] Different desktop environments (GNOME, KDE, etc.)

### Backend Enhancements

- [ ] **Additional OAuth Providers**
  - [ ] Cloudflare Access (for IT professionals)
  - [ ] Email/password auth (optional, simpler for closed groups)

- [ ] **Mobile Support** (optional)
  - [ ] API for mobile clients
  - [ ] Mobile app (iOS/Android) if demand exists

### Documentation

- [ ] **macOS Installation & Troubleshooting**
- [ ] **Linux Installation & Troubleshooting**
- [ ] **Cross-Platform Architecture**

**Deliverable:** Native clients for macOS and Linux.

**Success Criteria:**
- macOS app works on Intel and M1/M2
- Linux app works on major distributions
- Both use keyring for secure token storage
- No regression in Windows client
- User base grows to 500-1000+ users

---

## Phase 5: Community & Scaling (August 2026+)

**Goal:** Build community governance and support multiple backend operators.

**Timeline:** Ongoing (September 2026+)

### Community Governance

- [ ] **Code of Conduct**
  - [ ] Community guidelines
  - [ ] Enforcement process

- [ ] **Maintainer Council**
  - [ ] Core contributors become maintainers
  - [ ] Decision-making process
  - [ ] Rotating leadership (optional)

- [ ] **Feature Planning**
  - [ ] Community voting on features
  - [ ] RFC (Request for Comments) process for major changes

### Federation (Multiple Operators)

- [ ] **Backend Federation Protocol**
  - [ ] Shared user directory (optional centralized auth)
  - [ ] Operator list (users can choose backend)
  - [ ] Load balancing between operators

- [ ] **Operator Toolkit**
  - [ ] Easy deployment (Docker container, automated setup)
  - [ ] Operator guidelines (ToS compliance, privacy standards)
  - [ ] Revenue sharing (if monetization model exists)

### Advanced Features

- [ ] **Bandwidth Limits** (optional)
  - [ ] Per-user bandwidth caps
  - [ ] Fair usage policy

- [ ] **Enhanced Analytics** (opt-in)
  - [ ] User-visible usage stats (how much data transferred, etc.)
  - [ ] Privacy-preserving insights

- [ ] **WebRTC Leak Detection**
  - [ ] Verify users' real IP doesn't leak
  - [ ] Dashboard warning if leak detected

- [ ] **Geographic Features**
  - [ ] Operator location info
  - [ ] User location-based operator selection

### Monetization (Optional, if needed)

- [ ] **Donation Link** (Phase 3)
  - [ ] GitHub Sponsors, Ko-fi, or similar
  - [ ] Optional tips (no paywall)

- [ ] **Subscription Model** (if scaling requires revenue)
  - [ ] Free tier (base service)
  - [ ] Premium tier (higher bandwidth, priority support)
  - [ ] Enterprise tier (for organizations)

### Sustainability

- [ ] **Documentation for Future Maintainers**
  - [ ] Architecture deep dive
  - [ ] Deployment procedures
  - [ ] Troubleshooting playbook

- [ ] **Succession Planning**
  - [ ] Transfer of domain/infrastructure to community if needed
  - [ ] Contributor onboarding

**Success Criteria:**
- 5000+ active users
- 3+ community maintainers
- Multiple operator backends running
- Sustainable funding (if needed)
- Strong community engagement

---

## Ongoing Tasks (All Phases)

### Quality Assurance

- [ ] **Bug Fixes**
  - [ ] User-reported bugs fixed within 1 week
  - [ ] Security bugs fixed within 24-48 hours

- [ ] **Testing**
  - [ ] Unit test coverage >80%
  - [ ] Integration tests for critical flows
  - [ ] Regular manual testing on multiple platforms

- [ ] **Code Review**
  - [ ] All PRs reviewed before merge
  - [ ] Two approvals for major changes

### Security

- [ ] **Dependency Updates**
  - [ ] Regular security patches
  - [ ] Automated dependency scanning

- [ ] **Security Audits**
  - [ ] Quarterly review of security practices
  - [ ] Third-party audit before major release (optional)

- [ ] **Vulnerability Disclosure**
  - [ ] Security@yumehana.dev email for reports
  - [ ] 90-day responsible disclosure window

### Community

- [ ] **Support**
  - [ ] Monitor GitHub Issues (respond within 24 hours)
  - [ ] Discord support channel active
  - [ ] FAQ and troubleshooting updated regularly

- [ ] **Communication**
  - [ ] Monthly status updates (Discord/GitHub Discussions)
  - [ ] Transparency about delays or issues
  - [ ] Changelog maintained

---

## Non-Goals

These are features that are **not** planned (but may be revisited):

- **Shared VPN-like features** – AnniProxy is not a shared VPN; it's a community proxy operated by a single person
- **Mobile app** – Focus on desktop first; mobile support considered post-scale
- **Commercial deployment** – Not positioning as a paid VPN service
- **Guaranteed anonymity** – Transparency is the goal, not anonymity (Tor is better for that)
- **File sharing** – Not a file transfer tool
- **Encryption of SOCKS5 tunnel** – Phase 2+ enhancement (not MVP requirement)

---

## How to Help

**Want to contribute?** See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

**What we need most:**
- **Phase 1:** Testers (Windows users)
- **Phase 2:** Documentation writers
- **Phase 3:** macOS/Linux developers
- **Phase 4+:** Community moderators

**How to stay updated:**
- Star ⭐ the GitHub repo
- Join Discord (koinoyume7)
- Watch GitHub for releases
- Check the [GitHub Discussions](https://github.com/KoiNoYume7/annproxy/discussions)

---

## Timeline Summary

```
March 2026:   Phase 1 MVP (Windows + OAuth)
April 2026:   Phase 2 Hardening (Admin dashboard, operator tooling)
May 2026:     Phase 3 Public Launch (Open source, community)
June 2026:    Phase 4 macOS/Linux (Multi-platform support)
August 2026+: Phase 5 Community & Scaling (Federation, governance)
```

---

## Contact & Questions

- **Project Lead:** KoiNoYume7
- **Email:** koinoyume7@gmail.com
- **Discord:** koinoyume7
- **Website:** yumehana.dev (coming soon)
- **GitHub:** https://github.com/KoiNoYume7/annproxy

---

**Last Updated:** March 4, 2026  
**Next Review:** April 15, 2026