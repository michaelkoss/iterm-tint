# CLAUDE.md - iterm-tint

Project learnings and patterns for LLM-assisted development.

## Learnings

### Shell Compatibility

- **Avoid `path` as a variable name** - It's a special variable in zsh (contains PATH as array)
- **Substring syntax `${var:offset:length}` is 0-based** in both bash and zsh when using this exact syntax
- **Always test in both bash and zsh** - The default shell on macOS is zsh, but the shebang says bash
- **Use `$ZSH_VERSION` or `$BASH_VERSION`** to detect shell when behavior differs

### DJB2 Hash

- Initial value: 5381
- Formula: `hash = ((hash << 5) + hash) + byte`
- Must mask with `0x7FFFFFFF` to prevent overflow in shell arithmetic
- `printf '%d' "'$char"` gives ASCII value of a character
