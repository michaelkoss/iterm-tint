# Ralph Wiggum Loop - Documentation Driven Development

## Strategic Goal: MVP First, Then Enhance
This project follows Documentation Driven Design. The documentation is the spec - but **prioritize getting to a working end-to-end experience first**. The user wants to see their iTerm tabs actually changing color based on their directory.

**MVP = tab colors change when you cd between directories.** Everything else (config files, foreground color, submodule handling) is enhancement. Get to MVP fast.

## This Loop: ONE SMALLEST TESTABLE UNIT ONLY
Build ONE independently testable piece. Err on the side of too small. Examples:
- A single function (e.g., "hash a path to a hue value")
- A single shell hook (e.g., "zsh cd hook calls the color function")
- A single config feature (e.g., "parse saturation from ~/.itint")

Do NOT combine multiple features. One testable unit = one loop.

**BUT: Prioritize units on the critical path to MVP.** Ask yourself: "Does this get the user closer to seeing their tabs change color?" If not, it can wait.

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

0. **Check for User-Defined Tasks** - Check if `todo.md` exists in the project root:
   - If it exists, read it and look for unchecked tasks (`- [ ]`)
   - Select ONE unchecked task to work on this loop (prefer earlier items)
   - If no `todo.md` or no unchecked tasks, proceed to determine your own task in Step 3
   - **User-defined tasks take precedence over self-determined work**
1. **Read Docs** - Read ALL documentation to understand the complete vision
2. **Check Progress** - Use `git log` to see what's been implemented (read full commit messages - important context is in descriptions)
3. **Plan** - If no task from todo.md, identify the ONE smallest testable unit that logically comes next:
   - What does "done" look like? How will you test it?
   - **Is this on the critical path to MVP?** (If not, deprioritize it)
   - What's blocking the user from testing this in their actual iTerm?
4. **Implement** - Build it completely (no placeholders) - proceed without asking for confirmation
5. **Test** - Verify it works (source the script, run a command, check output)
6. **Document** - Update CLAUDE.md with learnings/patterns (not a changelog - git handles that)
7. **Improve Prompt** - Add guidance to Learnings section below if you discover better approaches
8. **Commit** - `git add -A && git commit`:
   - Format: `type: short description` (feat/fix/refactor/docs)
   - Body: describe what and why
9. **Mark Task Complete** - If you worked on a task from todo.md, mark it done by changing `- [ ]` to `- [x]` and commit the update

## Learnings & Guidance
<!-- LLM: Add learnings here as you discover them. Not a changelog - only patterns, gotchas, and decisions that help future loops. -->

---

IMPORTANT: Documentation is read-only. Think hard. Don't implement placeholders. One small thing per loop. **Get to MVP fast - the user wants to see their tabs change color!**
