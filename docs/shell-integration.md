# Shell Integration

iterm-tint supports Zsh, Bash, and Fish shells. This document covers how to set up and customize the integration for each shell.

## Supported Shells

| Shell | Hook Mechanism | Config File |
|-------|----------------|-------------|
| Zsh | `chpwd` hook | `~/.zshrc` |
| Bash | `PROMPT_COMMAND` | `~/.bashrc` |
| Fish | `--on-variable PWD` | `~/.config/fish/config.fish` |

---

## Zsh

### Setup

Add to `~/.zshrc`:

```bash
source ~/.iterm-tint/iterm-tint.sh
```

### How It Works

Zsh provides a built-in `chpwd` hook that executes whenever the current directory changes. iterm-tint registers a function with this hook:

```bash
chpwd_functions+=(_itint_update)
```

The hook triggers on:
- `cd` commands
- `pushd` / `popd`
- Any other directory change

### Manual Trigger

To manually update the tab color without changing directories:

```bash
_itint_update
```

---

## Bash

### Setup

Add to `~/.bashrc`:

```bash
source ~/.iterm-tint/iterm-tint.sh
```

### How It Works

Bash doesn't have a native directory-change hook, so iterm-tint uses `PROMPT_COMMAND`. This variable contains commands that execute before each prompt is displayed:

```bash
PROMPT_COMMAND="_itint_update${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
```

This prepends the update function while preserving any existing `PROMPT_COMMAND` content.

### Considerations

Since `PROMPT_COMMAND` runs before every prompt (not just on directory changes), iterm-tint internally tracks the previous directory and only updates when it changes:

```bash
if [[ "$PWD" != "$_ITINT_LAST_DIR" ]]; then
    # Update color
    _ITINT_LAST_DIR="$PWD"
fi
```

### Manual Trigger

```bash
_itint_update
```

---

## Fish

### Setup

Add to `~/.config/fish/config.fish`:

```fish
source ~/.iterm-tint/shells/fish.fish
```

### How It Works

Fish provides event-based hooks. iterm-tint uses the `--on-variable PWD` event to detect directory changes:

```fish
function _itint_update --on-variable PWD
    # Update color
end
```

This triggers whenever the `PWD` variable changes.

### Manual Trigger

```fish
_itint_update
```

---

## Project Structure

The shell integration files are organized as follows:

```
~/.iterm-tint/
├── iterm-tint.sh           # Main entry point (detects shell, sources appropriate file)
└── shells/
    ├── zsh.sh              # Zsh-specific hooks
    ├── bash.sh             # Bash-specific hooks
    └── fish.fish           # Fish-specific hooks
```

The main `iterm-tint.sh` script:
1. Detects the current shell
2. Sources the shell-specific integration file
3. Sources common library functions

---

## Customization

### Disabling Temporarily

To disable iterm-tint for the current session without removing it from your rc file:

```bash
# Zsh/Bash
unset -f _itint_update

# Fish
functions -e _itint_update
```

### Conditional Loading

To only load iterm-tint in iTerm2:

```bash
# Zsh/Bash
if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    source ~/.iterm-tint/iterm-tint.sh
fi
```

```fish
# Fish
if test "$TERM_PROGRAM" = "iTerm.app"
    source ~/.iterm-tint/shells/fish.fish
end
```

### Integration with Other Tools

iterm-tint is designed to coexist with other shell customizations:

- **Oh My Zsh**: Add the source line after Oh My Zsh initialization
- **Starship**: No conflicts, both can run together
- **Other prompt customizers**: iterm-tint only modifies tab color, not the prompt itself

---

## Startup Behavior

On shell startup, iterm-tint:

1. Loads configuration from `~/.itint`
2. Registers the appropriate hook for your shell
3. Immediately updates the tab color for the current directory

This means your tab color is set as soon as a new terminal window or tab opens.

---

## Performance Notes

The hook function is optimized to be as fast as possible:

- Minimal filesystem operations
- No subshell spawning
- No external command execution (pure shell)

Typical execution time is under 5ms, imperceptible to users.
