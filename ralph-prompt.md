# Ralph Wiggum Loop - Documentation Driven Development

## Strategic Goal: Build From Documentation
This project follows Documentation Driven Design. The documentation is the spec - implement what it describes. Read all docs first, then build incrementally.

## This Loop: ONE SMALLEST TESTABLE UNIT ONLY
Build ONE independently testable piece. Err on the side of too small. Examples:
- A single function (e.g., "hash a path to a hue value")
- A single shell hook (e.g., "zsh cd hook calls the color function")
- A single config feature (e.g., "parse saturation from ~/.itint")

Do NOT combine multiple features. One testable unit = one loop.

## Context
- **Documentation** (read-only, cannot modify):
  - [README.md](./README.md) - Overview and installation
  - [docs/configuration.md](docs/configuration.md) - Config format and options
  - [docs/how-it-works.md](docs/how-it-works.md) - Technical internals
  - [docs/shell-integration.md](docs/shell-integration.md) - Shell hook mechanisms
  - [docs/troubleshooting.md](docs/troubleshooting.md) - Common issues
- **Git history** - Check commits to understand what's been built
- **CLAUDE.md** - Project learnings and guidelines (if exists)
- **Web search** - You may search the web for shell scripting patterns, iTerm2 escape sequences, or other technical references as needed

## Workflow
1. **Read Docs** - Read ALL documentation to understand the complete vision
2. **Check Progress** - Use `git log` to see what's been implemented (read full commit messages - important context is in descriptions)
3. **Plan** - Identify the ONE smallest testable unit that logically comes next:
   - What does "done" look like? How will you test it?
   - Why is this the right next step?
4. **Implement** - Build it completely (no placeholders) - proceed without asking for confirmation
5. **Test** - Verify it works (source the script, run a command, check output)
6. **Document** - Update CLAUDE.md with learnings/patterns (not a changelog - git handles that)
7. **Improve Prompt** - Add guidance to Learnings section below if you discover better approaches
8. **Commit** - `git add -A && git commit`:
   - Format: `type: short description` (feat/fix/refactor/docs)
   - Body: describe what and why

## Learnings & Guidance
<!-- LLM: Add learnings here as you discover them. Not a changelog - only patterns, gotchas, and decisions that help future loops. -->

---

IMPORTANT: Documentation is read-only. Think hard. Don't implement placeholders. One small thing per loop.
