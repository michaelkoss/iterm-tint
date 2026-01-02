# CLAUDE.md - iterm-tint

Project learnings and patterns for LLM-assisted development.

## Learnings

### Shell Compatibility

- **Avoid `path` as a variable name** - It's a special variable in zsh (contains PATH as array)
- **Substring syntax `${var:offset:length}` is 0-based** in both bash and zsh when using this exact syntax
- **Always test in both bash and zsh** - The default shell on macOS is zsh, but the shebang says bash
- **Use `$ZSH_VERSION` or `$BASH_VERSION`** to detect shell when behavior differs

### Word Splitting (bash vs zsh)

- **Zsh does not word-split by default** on unquoted parameter expansion (`$var`)
- **Use `read` to split strings** into multiple variables instead of relying on `$var` word splitting
- Example: `read a b c <<< "$space_separated"` works in both bash and zsh
- **`set -- $var`** will NOT split in zsh unless `SH_WORD_SPLIT` is enabled

### DJB2 Hash

- Initial value: 5381
- Formula: `hash = ((hash << 5) + hash) + byte`
- Must mask with `0x7FFFFFFF` to prevent overflow in shell arithmetic
- `printf '%d' "'$char"` gives ASCII value of a character

### Fish Shell Specifics

- **Use `test` instead of `[ ]`** - Fish uses `test` command for conditionals
- **Event hooks via `--on-variable`** - Fish function declarations can include `--on-variable PWD` to trigger on directory changes
- **Array indexing is 1-based** - Fish arrays start at index 1, unlike bash (0-based)
- **Use `string` builtin for manipulation** - Fish has `string split`, `string match`, `string replace` instead of bash parameter expansion
- **`set -q VAR`** checks if variable is defined
- **`set -g VAR value`** sets global variable
- **`isatty stdout`** checks if stdout is a TTY (vs `[ -t 1 ]` in bash)
- **No `exit` inside functions** - Use `return` to exit functions early
