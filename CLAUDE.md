# Claude Code Guidelines for this Project

This file contains instructions for Claude Code when working on this repository.

## Development Practices

### 1. Testing Requirements

**Always run tests before committing:**
```bash
./tests/run-tests.sh
```

**When adding new scripts:**
- Create corresponding unit tests in `tests/test-<scriptname>.sh`
- Add the test file to `tests/run-tests.sh`
- Ensure all tests pass before committing

**Test structure:**
- Unit tests: Test individual functions and error handling
- Integration tests: Test full workflows and file creation

### 2. Notification Best Practices

**Send notifications for:**
- PR submissions: Use `./scripts/pr-notify <pr-url>`
- Task completion: Hook handles this automatically via `stop/done` event
- Questions/approvals: Hook handles this automatically

**After creating a PR, always run:**
```bash
./scripts/pr-notify
```

### 3. Commit Guidelines

**Commit message format:**
```
<Short description of change>

<Detailed explanation if needed>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

**Before committing:**
1. Run `./tests/run-tests.sh` - all tests must pass
2. Update README.md if adding new scripts or features
3. Update the Files section in README if file structure changes

### 4. Script Development

**New scripts should:**
- Be placed in `scripts/` directory
- Be made executable (`chmod +x`)
- Include a header comment explaining usage
- Source config from `~/.config/claude-mobile/config`
- Handle missing config gracefully with helpful error messages

**Script template:**
```bash
#!/usr/bin/env bash
#
# script-name - Brief description
#
# Usage: script-name [args]
#

set -euo pipefail

CONFIG_FILE="${HOME}/.config/claude-mobile/config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Script logic here
```

### 5. Hook Development

**Hooks should:**
- Be placed in `hooks/` directory
- Handle all expected event types
- Fail gracefully if config is missing
- Use appropriate notification priorities:
  - `urgent`: Errors
  - `high`: Questions, approvals needed
  - `default`: Informational (task done, notifications)

### 6. Documentation

**Update README.md when:**
- Adding new scripts (update Files section)
- Adding new features (add usage examples)
- Changing configuration options

**Keep documentation concise:**
- One-liner descriptions in Files section
- Short code examples for usage
- Link to detailed docs in `docs/` if needed

## Workflow Summary

```
1. Make changes
2. Run tests: ./tests/run-tests.sh
3. Commit with descriptive message
4. Push and create PR
5. Notify: ./scripts/pr-notify
```

## Environment Setup

Required config file: `~/.config/claude-mobile/config`

```bash
NTFY_TOPIC="your-unique-topic"
NTFY_SERVER="https://ntfy.sh"  # optional, defaults to ntfy.sh
```

## Testing Checklist

Before submitting changes:
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] README updated if needed
- [ ] Scripts are executable
- [ ] PR notification sent
