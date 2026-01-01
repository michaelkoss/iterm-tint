# Troubleshooting

Common issues and solutions for iterm-tint.

## Tab Color Not Changing

### Check Terminal

iterm-tint only works in iTerm2. Verify you're using iTerm2:

```bash
echo $TERM_PROGRAM
# Should output: iTerm.app
```

If you see something else (like `Apple_Terminal` or `vscode`), you're not in iTerm2.

### Check Installation

Verify iterm-tint is sourced in your shell config:

```bash
# Zsh
grep -n "iterm-tint" ~/.zshrc

# Bash
grep -n "iterm-tint" ~/.bashrc

# Fish
grep -n "iterm-tint" ~/.config/fish/config.fish
```

### Check Function Exists

Verify the update function is defined:

```bash
# Zsh/Bash
type _itint_update

# Fish
functions _itint_update
```

### Reload Shell

After installation, reload your shell:

```bash
# Zsh
source ~/.zshrc

# Bash
source ~/.bashrc

# Fish
source ~/.config/fish/config.fish
```

Or simply open a new terminal tab.

---

## Wrong Color Displayed

### Check Overrides

If a specific path has an unexpected color, check for overrides in `~/.itint`:

```bash
grep -A 20 "\[overrides\]" ~/.itint
```

Remember: the most specific (longest matching prefix) override wins.

### Check Hash Mode

If the same project has different colors on different machines, check `ITINT_HASH_MODE`:

- `absolute_path` (default): Color is based on full path, varies by location
- `folder_name_only`: Color is based on folder name only, consistent across machines

### Check Submodule Mode

If a submodule has an unexpected color:

- `ITINT_SUBMODULE_MODE=parent`: Submodule shares parent repo's color
- `ITINT_SUBMODULE_MODE=unique`: Submodule gets its own color

---

## Configuration Not Applied

### Check File Location

Configuration must be at `~/.itint` (not `~/.itintrc` or other variations):

```bash
ls -la ~/.itint
```

### Check Syntax

The config file must be valid shell syntax. Common issues:

```bash
# Wrong - spaces around equals
ITINT_DEFAULT_SATURATION = 50

# Correct - no spaces
ITINT_DEFAULT_SATURATION=50
```

```bash
# Wrong - using % sign
ITINT_DEFAULT_SATURATION=50%

# Correct - number only
ITINT_DEFAULT_SATURATION=50
```

### Check Value Ranges

| Setting | Valid Range |
|---------|-------------|
| `ITINT_DEFAULT_SATURATION` | 0-100 |
| `ITINT_DEFAULT_LIGHTNESS` | 0-100 |
| `ITINT_HASH_MODE` | `absolute_path`, `folder_name_only` |
| `ITINT_FOCUS_MODE` | `active_focus`, `primary_pane` |
| `ITINT_SUBMODULE_MODE` | `parent`, `unique` |

### Reload Configuration

After editing `~/.itint`, trigger a reload by changing directories:

```bash
cd .
```

---

## Performance Issues

### Slow on Network Drives

The recursive git root search may be slow on network filesystems. The search automatically stops at `~` and `/`, but deep directory structures can still cause delays.

**Workaround:** Use path overrides to set colors for network mount points directly, bypassing git detection:

```bash
[overrides]
/mnt/network-drive 180
```

### Slow in Large Monorepos

iterm-tint only searches upward (parent directories), not downward. The git root is found quickly regardless of repository size. If you experience slowness, the issue is likely elsewhere.

---

## Split Pane Issues

### Color Not Updating When Switching Panes

Check `ITINT_FOCUS_MODE` in `~/.itint`:

- `active_focus`: Color should update when switching panes
- `primary_pane`: Color stays constant (based on original pane)

If using `active_focus` and colors aren't updating, the shell in each pane needs iterm-tint sourced.

---

## SSH Sessions

iterm-tint runs locally in your terminal, not on remote servers. When you SSH to a remote machine:

- The tab color reflects your **local** shell's last directory before SSH
- The remote server's directories don't affect tab color
- This is expected behavior

To get directory-based colors on remote servers, you would need to install iterm-tint there as well.

---

## Uninstalling

### Remove Source Line

Remove the source line from your shell config:

```bash
# Zsh
# Remove: source ~/.iterm-tint/iterm-tint.sh from ~/.zshrc

# Bash
# Remove: source ~/.iterm-tint/iterm-tint.sh from ~/.bashrc

# Fish
# Remove: source ~/.iterm-tint/shells/fish.fish from ~/.config/fish/config.fish
```

### Remove Files

```bash
rm -rf ~/.iterm-tint
rm ~/.itint
```

### Reset Tab Color

To reset iTerm2 tab color to default:

```bash
printf "\033]6;1;bg;*;default\a"
```

---

## FAQ

### Why HSL instead of RGB?

HSL provides consistent perceived brightness across colors. A green and a blue with the same saturation and lightness values appear equally "bright" to human eyes, making tabs visually consistent.

### Can I use hex color codes?

Not directly. iterm-tint uses HSL internally. However, you can convert hex to HSL and use those values in overrides.

### Does this work with tmux?

tmux has its own tab/window system that doesn't use iTerm2's tab coloring. iterm-tint affects the iTerm2 tab, not tmux windows.

### Why does my SSH session keep the old color?

iterm-tint hooks into directory changes in your local shell. SSH is a program running in that shell, not a directory change. The color reflects where your local shell was when you started SSH.

### Can I set a color for a specific git branch?

Not currently. iterm-tint colors are based on directory paths, not git branches. This is a potential future feature.
