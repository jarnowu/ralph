# Contributing to Ralph

Thank you for your interest in contributing to Ralph.

## How to Contribute

### Reporting Issues

Before opening an issue:
1. Search existing issues to avoid duplicates
2. Include your environment (OS, Claude Code/Amp version)
3. Provide steps to reproduce the problem
4. Include relevant logs or error messages

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test both single-agent and dual-agent modes if applicable
5. Update documentation if behavior changes
6. Submit a pull request with a clear description

### What We're Looking For

**High Priority:**
- Bug fixes with clear reproduction steps
- Documentation improvements
- Cross-platform compatibility fixes
- Performance improvements to prompts

**Welcome:**
- New testing categories for Watcher
- Better quality gate heuristics
- Improved error handling in shell scripts
- Translations of documentation

**Discuss First:**
- Changes to core architecture
- New agent types
- Breaking changes to state file schemas
- New dependencies

### Code Style

- Shell scripts: Use `shellcheck` for linting
- PowerShell: Follow standard cmdlet naming conventions
- Markdown prompts: Keep concise, use consistent formatting
- JSON: Use 2-space indentation

### Testing Your Changes

```bash
# Single-agent mode
./ralph.sh --tool claude 3

# Dual-agent mode (requires Linear setup)
./ralph-dual/watcher.sh --max 3
./ralph-dual/builder.sh --max 3
```

### Commit Messages

Use conventional commits:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `refactor:` Code changes that don't add features or fix bugs

### Questions?

Open a discussion or issue. We're happy to help.
