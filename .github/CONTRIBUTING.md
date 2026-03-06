# Contributing to AnniProxy

Thank you for your interest in contributing to AnniProxy! We welcome contributions from everyone—whether you're a beginner or an experienced developer.

**Table of Contents**
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Ways to Contribute](#ways-to-contribute)
- [Development Workflow](#development-workflow)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Documentation](#documentation)
- [Community](#community)

---

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful, kind, and professional in all interactions.

**We do not tolerate:**
- Harassment, discrimination, or hate speech
- Unwelcoming behavior toward any person or group
- Sharing of private information without consent
- Spam or off-topic discussions

**Violations may result in:**
- Removal from the project
- Ban from future contributions
- Reporting to relevant authorities (if applicable)

If you witness a violation, please report it to koinoyume7@gmail.com.

---

## Getting Started

### 1. Set Up Your Development Environment

**Prerequisites:**
- Git
- Python 3.9+ (for backend)
- PowerShell 7+ (for Windows client)
- An editor (VS Code recommended)

**Clone the repository:**
```bash
git clone https://github.com/KoiNoYume7/annproxy.git
cd annproxy
```

**Create a feature branch:**
```bash
git checkout -b feature/your-feature-name
```

### 2. Install Dependencies

**Backend (Python):**
```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

pip install -r requirements.txt
```

**Frontend (PowerShell):**
No installation needed—PowerShell 7+ is sufficient.

### 3. Run Locally

**Windows:**
```bash
.\run.bat
```

**macOS/Linux (when available):**
```bash
./run.sh --dev
```

### Logs (Windows Client)

When debugging the client, check logs in `client/.log/`:

- `client/.log/session/session-<timestamp>.log` (main session log)
- `client/.log/ssh/ssh-<timestamp>.log/.err` (SSH stdout/stderr)
- `client/.log/brave/brave-<timestamp>.log/.err` (Brave stdout/stderr)

`logLevel` in `client/.config/config.json` controls console verbosity. The session log is always written, and **0-byte log files are automatically deleted** on shutdown.

---

## Ways to Contribute

### Code Contributions

**Good first issues:**
- Look for issues labeled `good first issue`
- These are scoped, well-documented, and beginner-friendly

**Types of code contributions:**
- **Bug fixes** – Find a bug? Fix it and submit a PR
- **New features** – Have an idea? Discuss it in an issue first, then implement
- **Performance improvements** – Speed up slow code
- **Refactoring** – Improve readability and maintainability
- **Tests** – Add unit, integration, or end-to-end tests

### Documentation Contributions

- **README improvements** – Clarify instructions, add examples
- **Troubleshooting guides** – Help others solve common problems
- **API documentation** – Document public interfaces
- **Translations** – Help make AnniProxy accessible globally
- **Blog posts** – Share your experience using AnniProxy

### Design Contributions

- **UI/UX improvements** – Better user experience
- **Graphics** – Icons, logos, screenshots
- **Installer design** – Improve setup wizard

### Community Support

- **Answer questions** – Help others in GitHub Discussions
- **Triage issues** – Label, categorize, and clarify issues
- **Code review** – Review pull requests and provide feedback
- **Testing** – Test new features and report bugs
- **Advocacy** – Share AnniProxy with others

---

## Development Workflow

### 1. Create an Issue (for non-trivial contributions)

Before starting work on a significant change, open an issue to discuss it:

```markdown
**Title:** [Feature/Bug] Brief description

**Description:**
Explain what you want to do and why.

**Expected behavior:**
What should happen?

**Current behavior:**
What currently happens?

**Your environment:**
- OS: (Windows 10, macOS 12, Ubuntu 22.04, etc.)
- Python version: (if relevant)
- PowerShell version: (if relevant)
```

### 2. Fork and Branch

```bash
# Fork the repo on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/annproxy.git
cd annproxy

# Create a feature branch (use descriptive name)
git checkout -b feature/add-cloudflare-oauth
# or
git checkout -b fix/token-refresh-bug
# or
git checkout -b docs/improve-readme
```

### 3. Make Your Changes

**Keep commits atomic:**
- One logical change per commit
- Don't mix unrelated changes
- Keep changes focused and minimal

**Test frequently:**
- Run `./run.bat` or `./run.sh` to test locally
- Run tests: `pytest backend/tests`
- Check for errors before committing

### 4. Commit with Clear Messages

See [Commit Guidelines](#commit-guidelines) below.

### 5. Push and Create Pull Request

```bash
git push origin feature/add-cloudflare-oauth
```

Then create a pull request on GitHub with a clear description.

---

## Commit Guidelines

We use **Conventional Commits** for clear, structured commit messages.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat** – New feature (user-facing change)
- **fix** – Bug fix
- **docs** – Documentation only
- **style** – Code style (formatting, semicolons, etc.)
- **refactor** – Code refactoring (no behavior change)
- **perf** – Performance improvement
- **test** – Adding or updating tests
- **ci** – CI/CD configuration
- **chore** – Maintenance, dependencies, etc.

### Scope (Optional)

- `backend` – Python backend (auth_server, socks5_server, etc.)
- `client` – Windows/macOS/Linux client
- `oauth` – OAuth-related code
- `proxy` – SOCKS5 proxy code
- `docs` – Documentation
- `ci` – CI/CD (GitHub Actions, etc.)

### Subject

- Use imperative mood ("add" not "added" or "adds")
- Don't capitalize first letter
- No period at the end
- Keep it under 50 characters

### Body (Optional)

- Explain **what** and **why**, not just **what**
- Wrap at 72 characters
- Reference related issues: "Fixes #123" or "Closes #456"

### Examples

```
feat(oauth): add cloudflare access provider

Implement OAuth2 integration with Cloudflare for Zero Trust.
Users can now authenticate using Cloudflare Access credentials.

Fixes #42
```

```
fix(proxy): handle connection timeout gracefully

Prevent SOCKS5 server from hanging on slow connections.
Add 30-second timeout and proper error logging.

Closes #15
```

```
docs: improve installation instructions for macOS
```

---

## Pull Request Process

### Before Submitting

1. **Update your branch** with latest main:
   ```bash
   git fetch origin
   git rebase origin/main
   ```

2. **Run tests:**
   ```bash
   pytest backend/tests
   ```

3. **Check code style:**
   - Python: `black backend/` and `flake8 backend/`
   - PowerShell: Run `PSScriptAnalyzer` rules

4. **Test manually:**
   ```bash
   # Windows
   .\run.bat
   
   # macOS/Linux
   ./run.sh --dev
   ```

### Pull Request Description

```markdown
## Description
Brief summary of your changes.

## Type of Change
- [ ] Bug fix (fixes #___)
- [ ] New feature (related to #___)
- [ ] Documentation update
- [ ] Breaking change

## Testing
Describe how you tested this change.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No new warnings or errors
- [ ] Commit messages follow conventions
```

### What Reviewers Look For

- **Correctness** – Does it work? Are edge cases handled?
- **Tests** – Is it tested? Do tests pass?
- **Documentation** – Is it documented? Is it clear?
- **Performance** – Does it introduce any regressions?
- **Security** – Are there any security issues?
- **Style** – Does it follow project conventions?

### Feedback and Revisions

- Be open to feedback—reviewers are helping improve the code
- Make requested changes in new commits (don't force-push)
- Ping reviewers when you've updated your PR
- Be patient—reviewers are volunteers

---

## Code Style

### Python

**Style Guide:** [PEP 8](https://pep8.org/) with some modifications

**Tools:**
```bash
# Format code
black backend/

# Check style
flake8 backend/
```

**Guidelines:**
- Line length: 100 characters (except URLs)
- Use 4 spaces for indentation
- Name functions/variables clearly (no cryptic abbreviations)
- Use type hints for function signatures
- Add docstrings to functions and classes

**Example:**
```python
def validate_oauth_token(token: str, provider: str) -> bool:
    """
    Validate OAuth token with provider.
    
    Args:
        token: OAuth token to validate
        provider: OAuth provider ('google', 'github', etc.)
    
    Returns:
        True if token is valid, False otherwise
    """
    if not token or not provider:
        return False
    
    # Validation logic...
    return True
```

### PowerShell

**Style Guide:** [PowerShell Best Practices](https://pscustomobject.github.io/powershell/functions/PScripting/PowerShell-Best-Practices/)

**Tools:**
```powershell
# Check code quality
Invoke-PSScriptAnalyzer -Path .src/ -Recurse
```

**Guidelines:**
- Use PascalCase for function names
- Use camelCase for parameter names
- Add comment-based help for functions
- Use explicit parameter types
- Error handling: `$ErrorActionPreference = 'Stop'`

**Example:**
```powershell
<#
.SYNOPSIS
    Validates OAuth token stored in Credential Manager.
.PARAMETER Token
    The OAuth token to validate.
.EXAMPLE
    Test-OAuthToken -Token "abc123"
#>
function Test-OAuthToken {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Token
    )
    
    if ([string]::IsNullOrWhiteSpace($Token)) {
        return $false
    }
    
    # Validation logic...
    return $true
}
```

### Markdown

**Style Guide:**
- Use ATX-style headings (`#`, not underlines)
- Use backticks for code, not indentation
- Use `>` for blockquotes
- Use `- ` for unordered lists
- Wrap lines at 100 characters (except code blocks, URLs)
- Use `[link text](url)` format

---

## Testing

### Python Backend

```bash
cd backend

# Run all tests
pytest tests/

# Run specific test file
pytest tests/test_auth_server.py

# Run with coverage
pytest tests/ --cov=. --cov-report=html

# Run specific test
pytest tests/test_auth_server.py::test_oauth_login
```

### Windows Client

```powershell
# Run PowerShell tests (when available)
Invoke-Pester .src/tests/ -Verbose
```

### Test Requirements

- **Unit tests** for individual functions/modules
- **Integration tests** for workflows (e.g., OAuth login → token storage → SOCKS5 connection)
- **Aim for >80% code coverage** (but don't obsess over coverage)
- **Test edge cases** (empty inputs, network errors, timeouts, etc.)

### Writing Tests

**Python example:**
```python
import pytest
from auth_server import validate_oauth_token

def test_validate_oauth_token_success():
    """Test token validation with valid token."""
    token = "valid_token_abc123"
    assert validate_oauth_token(token, "google") == True

def test_validate_oauth_token_invalid():
    """Test token validation with invalid token."""
    assert validate_oauth_token("", "google") == False
    assert validate_oauth_token(None, "google") == False
```

---

## Documentation

### When to Document

- New features → Add to README
- Bug fixes → Update CHANGELOG
- API changes → Update backend API docs
- Installation changes → Update installation guide
- New settings → Add to configuration docs

### Documentation Format

- Use Markdown (`.md` files)
- Clear headings (`#`, `##`, `###`)
- Code examples with language specified
- Screenshots for UI changes
- Step-by-step instructions for complex processes

### Example Documentation

```markdown
## Installing AnniProxy

### Prerequisites
- Windows 10+ or macOS 10.14+ or Ubuntu 20.04+
- Internet connection

### Steps

1. Download the installer from [GitHub Releases](#)
2. Run the installer
3. Click "Login with Google"
4. Done!

### Troubleshooting

**Q: Installer won't start**

A: Check that you have PowerShell 7+ installed.
```bash
pwsh --version
```
```

---

## Community

### Getting Help

- **GitHub Discussions** – Ask questions, discuss ideas
- **GitHub Issues** – Report bugs, suggest features
- **Discord** – Chat with other contributors (koinoyume7)
- **Email** – koinoyume7@gmail.com for security issues

### Code Review

**As a reviewer:**
- Be kind and constructive
- Ask clarifying questions
- Praise good solutions
- Suggest improvements, don't demand them
- Approve when satisfied

**As an author:**
- Welcome feedback
- Don't take criticism personally
- Ask for clarification if feedback is unclear
- Respond to reviewers' comments

### Project Maintenance

- **Issues:** Triaged and labeled weekly
- **Pull Requests:** Reviewed within 5-7 days
- **Releases:** When ready (no fixed schedule), announced on Discord/GitHub

---

## Recognition

Contributors will be recognized in:
- [CONTRIBUTORS.md](#) file (when created)
- GitHub contributors page
- Project announcements

---

## Troubleshooting

### "Permission denied" when pushing

Make sure you've forked the repo and are pushing to your fork:
```bash
git remote -v
# Should show your fork, not the main repo
```

### Merge conflicts

```bash
# Update your branch with latest main
git fetch origin
git rebase origin/main

# Resolve conflicts in your editor, then:
git add .
git rebase --continue
```

### Tests failing locally

```bash
# Make sure you're in the right directory and have dependencies installed
cd backend
python -m pip install -r requirements.txt
pytest tests/
```

### Unsure about something?

**Open an issue or ask on Discord!** We're happy to help.

---

## Final Notes

- **Start small** – Your first contribution might be a typo fix, and that's great!
- **Be patient** – Maintainers are volunteers with limited time
- **Have fun** – Contributing should be enjoyable, not stressful
- **Spread the word** – The best contribution is telling others about AnniProxy

---

## Resources

- [Git Documentation](https://git-scm.com/doc)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [PEP 8 Style Guide](https://pep8.org/)
- [Python Testing Best Practices](https://docs.pytest.org/en/latest/)
- [GitHub Forking Guide](https://docs.github.com/en/get-started/quickstart/fork-a-repo)

---

**Thank you for contributing to AnniProxy! 🎉**