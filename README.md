# AnniProxy

> **A community-operated proxy service built for simplicity, privacy, and trust.**

---

## What is AnniProxy?

AnniProxy is a **portable, zero-friction proxy application** that combines:

1. **A lightweight portable browser** (Brave, no installation required)
2. **Authentication** (OAuth via Google, GitHub, or your own provider)
3. **A community-operated SOCKS5 proxy** (run by a single trusted operator)

When you run AnniProxy, you get a browser that automatically routes all traffic through a managed proxy. No configuration, no technical knowledge required.

### Why AnniProxy?

| Feature | Traditional VPN | AnniProxy |
|---------|-----------------|-----------|
| **Privacy** | ❓ Corporate policy | ✅ Transparent, single operator |
| **Simplicity** | 5-10 clicks to install | ✅ Click "Login" → Done |
| **Trust** | Trust a corporation | ✅ Trust an individual, see the code |
| **Cost** | $5-15/month | ✅ Free (community-operated) |
| **Source code** | Proprietary | ✅ Open-source |
| **Data logging** | Unknown | ✅ Documented (see privacy policy) |

### What We Log

✅ **For audit + abuse prevention:**
- Your email/identity (from OAuth login)
- IP address of your AnniProxy installation
- Timestamps of connections
- Aggregate bytes transferred

❌ **We don't log:**
- Content of your traffic (we can't decrypt it)
- Websites you visit
- Passwords, cookies, or authentication tokens
- Personally identifiable information

See our [Privacy Policy](#privacy-policy) for details.

---

## Quick Start

### Prerequisites

- **Windows 10+**, macOS 10.14+, or Linux (Ubuntu 20.04+)
- Internet connection
- A Google or GitHub account

### Installation

#### Windows (Easiest)

1. **Download** the latest installer: [AnniProxy_Setup_v1.0.exe](#)
2. **Run** it and follow the wizard
3. **Login** with Google or GitHub
4. **Done** – Brave launches automatically with proxy enabled

#### macOS

```bash
# Coming soon
```

#### Linux

```bash
# Coming soon
```

#### Manual / Development Build

```bash
git clone https://github.com/yourusername/annproxy.git
cd annproxy
./run.bat          # Windows
./run.sh           # macOS/Linux (coming soon)
```

---

## How It Works

### Architecture

```
┌────────────────────────────────────────┐
│  Your Machine (Windows, macOS, Linux)  │
├────────────────────────────────────────┤
│                                        │
│  1. AnniProxy Installer                │
│     ↓                                   │
│  2. Browser (Brave)                    │
│     └─ Proxied via SOCKS5             │
│                                        │
└────────────────────────────────────────┘
                    ↓ (SOCKS5 connection)
┌────────────────────────────────────────┐
│  Community Backend (Single Operator)   │
│  e.g., Raspberry Pi 4 at home          │
├────────────────────────────────────────┤
│                                        │
│  OAuth Server (Google/GitHub login)    │
│  SOCKS5 Proxy (token-authenticated)    │
│  Audit Logging (legal protection)      │
│  Admin Dashboard (operator controls)   │
│                                        │
└────────────────────────────────────────┘
                    ↓ (proxied traffic)
         [Rest of the Internet]
```

### User Experience

```
1. User downloads AnniProxy installer
2. Runs installer → Browser opens for login
3. User clicks "Login with Google"
4. Google shows consent screen
5. User approves → Returns to installer
6. Token stored securely in OS credential manager
7. Brave launches with proxy enabled
8. Done ✓ – User browses the internet

Next time user runs AnniProxy:
1. Token retrieved from credential manager
2. Brave launches immediately (no re-login)
3. Done ✓
```

---

## Use Cases

### 1. **IT Support Professionals**
Deploy a clean browser on client machines without cluttering the system or requiring technical knowledge from the client. Easily switch between clients—each AnniProxy install is isolated.

### 2. **Privacy-Conscious Users**
Use a proxy operated by a single transparent operator (not a corporation) with published source code and clear logging policy. Know exactly what data is being collected.

### 3. **Portable Browsing**
Take a portable, pre-configured browser on a USB stick that works on any Windows machine (or macOS/Linux).

### 4. **No-Install Browser**
Bypass corporate restrictions that prevent software installation—AnniProxy is portable and leaves no footprint.

### 5. **Educational / Kiosk Scenarios**
Set up a controlled browsing environment for classrooms or public computers with managed access and audit logging.

---

## Technical Details

### For Users

**Q: Will AnniProxy work offline?**
No, you need internet to authenticate and proxy your traffic. However, once authenticated, token refresh is automatic.

**Q: Is my traffic encrypted?**
- ✅ If the destination uses HTTPS (most sites do), your traffic is encrypted end-to-end.
- ⚠️ The SOCKS5 tunnel itself is not encrypted (Phase 2 enhancement planned).
- For maximum security, all traffic should use HTTPS.

**Q: Can I use AnniProxy for [specific use case]?**
Please check our [Acceptable Use Policy](#acceptable-use-policy). If you're unsure, open an issue or contact us.

**Q: What happens if the backend goes down?**
You cannot authenticate or use AnniProxy. We aim for 99.5% uptime. See [Reliability](#reliability) for details.

### For Operators (Backend)

Running your own AnniProxy backend requires:

- Raspberry Pi 4 (or any Linux machine with Python 3.9+)
- Static public IP or Cloudflare Tunnel
- ~100 MB disk space per 10,000 users
- 1-2 hours setup time

See [Backend Setup Guide](./BACKEND_SETUP.md) for detailed instructions.

---

## Installation Modes

### Simple Mode (Recommended for Most Users)

```
Just run the installer.
No configuration needed.
Token stored automatically.
```

### Advanced Mode (For Power Users)

Edit `.config/config.json` before running:

```json
{
  "mode": "managed_backend",
  "managedBackend": {
    "authServerUrl": "https://auth.yourdomain.com",
    "socksServerHost": "your-rpi-ip",
    "socksServerPort": 1080,
    "defaultOAuthProvider": "google"
  }
}
```

### Legacy Mode (Local SSH Tunnel)

If you have an existing SSH setup, you can continue using it:

```json
{
  "mode": "local_ssh",
  "localSSH": {
    "sshConfigPath": ".config/ssh.json"
  }
}
```

---

## Security

### Design Principles

1. **Zero trust infrastructure** – All connections require authentication
2. **Transparent logging** – Every action is logged; you can request your logs
3. **Minimal data collection** – We collect only what's necessary for operation
4. **User control** – You can revoke your token anytime, export your data, or delete your account

### Authentication

- Credentials validated via OAuth (Google, GitHub)
- Token issued and stored securely in OS credential manager
- Token validated on every connection to SOCKS5 server
- Token automatically refreshed before expiry

### Token Storage

- **Windows:** Windows Credential Manager (encrypted by OS)
- **macOS:** Keychain (encrypted by OS)
- **Linux:** KDE Wallet or GNOME Keyring (encrypted by OS)

### Revocation

If a token is compromised, you can:
1. Visit your account dashboard
2. Click "Revoke all sessions"
3. Token is immediately invalid
4. Log back in to get a new token

---

## Acceptable Use Policy

By using AnniProxy, you agree **not** to:

- ❌ Access or attempt to access unauthorized computer systems
- ❌ Harass, abuse, or threaten others
- ❌ Violate copyright laws (download copyrighted content without permission)
- ❌ Distribute malware or ransomware
- ❌ Conduct DDoS attacks or other network abuse
- ❌ Use AnniProxy for illegal activities in your jurisdiction

**Violations may result in:**
- Immediate account suspension
- IP address ban
- Reporting to law enforcement (if applicable)

---

## Privacy Policy

### What We Collect

When you use AnniProxy, we collect:

- **OAuth identity:** Email, name, profile picture (from your OAuth provider)
- **Connection metadata:** IP address, timestamp, bytes sent/received (aggregate)
- **Audit logs:** Login timestamps, token refreshes, revocations, errors

### How We Use It

- **Abuse prevention:** Detect and block suspicious activity
- **Service improvement:** Understand usage patterns, fix bugs
- **Legal compliance:** Maintain records in case of law enforcement requests
- **Security:** Monitor for attacks, unauthorized access

### How Long We Keep It

- **Account data:** Retained until you delete your account
- **Connection logs:** Deleted after 30 days
- **Audit logs:** Retained for 90 days

### Your Rights

- **Access:** Request a copy of data we hold about you
- **Delete:** Request account deletion (all data purged within 30 days)
- **Transparency:** See what data we've collected

To exercise your rights, email `[your-email@yourdomain.com]`.

### Third Parties

We do not sell or share your data. Third parties who receive your data:

- **OAuth providers** (Google, GitHub) – See their privacy policies
- **Law enforcement** – Only with valid legal process (warrant, subpoena)

---

## Roadmap

### Phase 1 (Now): Windows MVP ✅
- [x] OAuth login (Google, GitHub)
- [x] SOCKS5 proxy with token auth
- [x] Windows installer
- [ ] Beta testing with early users

### Phase 2 (Next Month): Hardening 🚀
- [ ] Admin dashboard (for operators)
- [ ] Token auto-refresh
- [ ] Better error messages
- [ ] User documentation

### Phase 3 (2-3 Months): Public Launch
- [ ] Public website + marketing
- [ ] Publish finalized Privacy Policy
- [ ] Community outreach
- [ ] First production users

### Phase 4 (3-6 Months): Multi-Platform
- [ ] macOS client
- [ ] Linux client
- [ ] Mobile app (optional)

### Phase 5 (6+ Months): Community
- [ ] Federated backend (multiple operators)
- [ ] Community governance
- [ ] Fundraising (if needed)

---

## Development

### For Contributors

We welcome contributions! See [CONTRIBUTING.md](./.github/CONTRIBUTING.md) for guidelines.

### Local Development Setup

```bash
# Clone repo
git clone https://github.com/KoiNoYume7/annproxy.git
cd annproxy

# Windows
.\run.bat

# macOS/Linux
./run.sh --dev
```

### Project Structure

```
annproxy/
├── client/
│   ├── .src/                      # PowerShell client
│   │   ├── main.ps1               # Entrypoint
│   │   └── [other modules]
│   ├── .config/                   # Client configuration
│   │   ├── config.json            # Client config (commit-safe)
│   │   ├── ssh.example.json       # Example SSH config (placeholders)
│   │   ├── ssh.json               # SSH config (optional)
│   │   └── ssh.local.json         # Local overrides (generated, gitignored)
│   └── .log/                      # Client logs
│       ├── session/               # Session logs
│       ├── ssh/                   # SSH stdout/stderr
│       └── brave/                 # Brave stdout/stderr
│
├── backend/                       # Python backend (RPi4)
│   ├── main.py                    # Server entrypoint
│   ├── auth_server.py             # OAuth + FastAPI
│   ├── socks5_server.py           # SOCKS5 proxy
│   ├── database.py                # SQLite schema
│   ├── config.py                  # Configuration
│   └── requirements.txt           # Python dependencies
│
├── client/.dev/                   # Developer docs
│   ├── TODO.md
│   └── ROADMAP.md
│
├── README.md                      # This file
├── .github/CONTRIBUTING.md        # Contribution guidelines
├── LICENSE.txt                    # Apache 2.0 license
└── run.bat                        # Windows entrypoint
```

### Logs

Client logs are written to `client/.log/`.

- `client/.log/session/session-<timestamp>.log` is the main session log.
- `client/.log/ssh/ssh-<timestamp>.log/.err` contain SSH stdout/stderr.
- `client/.log/brave/brave-<timestamp>.log/.err` contain Brave stdout/stderr.

`logLevel` in `client/.config/config.json` controls what is shown in the console. The session log is always written, and **0-byte log files are automatically deleted** on shutdown.

### Testing

```bash
# Windows
pytest backend/tests

# macOS/Linux
pytest backend/tests
```

### Code Style

- **PowerShell:** Follow [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) rules
- **Python:** Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/)
- **Commits:** Use [conventional commits](https://www.conventionalcommits.org/)

---

## Reliability

### Uptime

We target **99.5% uptime** (max 3.6 hours downtime/month).

### Backup

Operator maintains automated backups of:
- Database (hourly snapshots)
- Configuration (version-controlled)
- Audit logs (archived)

### Disaster Recovery

In case of backend failure:
- Temporary downtime while operator restarts service
- No data loss (backed up)
- Notification sent to all users (if infrastructure allows)

### Scaling

As user base grows:
- **1-1000 users:** Single RPi4 sufficient
- **1000-10K users:** Upgrade to better hardware or add load balancer
- **10K+ users:** Transition to PostgreSQL + distributed backend

---

## Comparison with Alternatives

| Aspect | AnniProxy | VPN Corp | SSH Tunnel | Tor |
|--------|-----------|----------|-----------|-----|
| **Setup** | 1 click | 5+ clicks | Technical | Medium |
| **Speed** | Fast | Fast | Slow | Very slow |
| **Privacy** | Good (transparent) | Unknown | Good (self-hosted) | Excellent (anonymous) |
| **Trust** | Individual operator | Large company | You control | Community |
| **Cost** | Free | $5-15/month | Free (self-hosted) | Free |
| **Source code** | Open | Proprietary | Available | Open |
| **Use case** | General purpose | General purpose | Advanced | Maximum privacy |

---

## FAQ

### Q: Is AnniProxy a VPN?

Not exactly. AnniProxy is a SOCKS5 proxy with OAuth authentication. It works similarly to a VPN (routes traffic through a proxy), but:

- SOCKS5 is application-layer (works with any protocol)
- VPN is system-layer (encrypts all traffic)
- AnniProxy doesn't encrypt the tunnel itself (but destination usually does with HTTPS)

### Q: Can I run my own backend?

Yes! See [Backend Setup Guide](./BACKEND_SETUP.md). You can run AnniProxy on your own hardware and only give access to trusted people.

### Q: What happens to my data if I stop using AnniProxy?

After account deletion, all personal data is purged within 30 days. You can request an archive of your data first (audit logs, connection timestamps, etc.).

### Q: Can I use AnniProxy for work?

Yes! IT professionals use AnniProxy to support clients. See [Use Cases](#use-cases).

### Q: Is AnniProxy available for [my country]?

AnniProxy is open to all users globally. However:
- Check local laws regarding proxy usage
- Some countries restrict internet tools
- We comply with valid legal requests (warrants, subpoenas)

### Q: How do I report a security vulnerability?

Please email koinoyume7@gmail.com with details. Do not open a public GitHub issue. We'll acknowledge within 48 hours and work on a fix.

### Q: Can I donate or support this project?

We're currently focused on building a great product. Once stable, we'll open a donation link. For now, contributions (code, documentation, translations) are the best support!

---

## Support

### Getting Help

- **General questions:** Open a GitHub issue
- **Bug reports:** See [CONTRIBUTING.md](./.github/CONTRIBUTING.md)
- **Security issues:** Email security@yourdomain.com (don't use public issues)
- **Feature requests:** Discuss in GitHub discussions or issues
- **Documentation:** See [docs/](./docs/) folder

### Community

- **GitHub Discussions:** Ask questions, share ideas
- **Discord:** Join us at koinoyume7
- **Email:** koinoyume7@gmail.com for general inquiries

---

## License

AnniProxy is released under the **Apache License 2.0**. See [LICENSE.txt](./LICENSE.txt) for full details.

In short: You're free to use, modify, and distribute AnniProxy for any purpose (including commercial) as long as you:
- Include a copy of the license and copyright notice
- State significant changes to the code
- Don't hold us liable for damages

---

## Contributing

We welcome contributions! Before you start, please read [CONTRIBUTING.md](./.github/CONTRIBUTING.md).

### Ways to Contribute

- **Code:** Bug fixes, new features, performance improvements
- **Documentation:** READMEs, guides, translations
- **Testing:** Find bugs, test edge cases
- **Design:** UI/UX improvements, graphics
- **Community:** Help other users, answer questions

### Getting Started

```bash
# 1. Fork the repo
# 2. Create a feature branch
git checkout -b feature/amazing-feature

# 3. Make your changes
# 4. Test locally (./run.bat or ./run.sh)
# 5. Commit with conventional commit message
git commit -m "feat: add amazing feature"

# 6. Push and create a pull request
git push origin feature/amazing-feature
```

---

## Acknowledgments

- **Brave Browser** – Portable, privacy-respecting browser
- **OpenSSH** – SSH client (legacy mode)
- **Cloudflare** – HTTPS, OAuth, and zero-trust infrastructure
- **Our contributors** – Code, ideas, and feedback

---

## Contact

**Project maintainer:** KoiNoYume7  
**Email:** koinoyume7@gmail.com  
**Discord:** koinoyume7  
**Website:** [yumehana.dev](#) (coming soon)

---

## Status

AnniProxy is in **public alpha**. We're actively developing and welcome feedback.

| Component | Status |
|-----------|--------|
| Windows client | ✅ Alpha |
| Authentication | ✅ Alpha |
| Backend (RPi4) | 🚀 In development |
| macOS client | 📅 Planned (Q2 2026) |
| Linux client | 📅 Planned (Q2 2026) |
| Admin dashboard | 📅 Planned |
| Mobile app | 📅 Planned (Future) |

---

**Made with ❤️ by yours truly. Help us build the internet we want.**