# iterm-tint

A shell-integrated utility for macOS iTerm2 that dynamically changes tab colors based on your current working directory.

## Features

- **Git-Aware** - All directories within a git repository share the same color
- **Consistent Colors** - Uses HSL color model for visually balanced, readable tabs
- **Multi-Shell Support** - Works with Zsh, Bash, and Fish
- **Configurable** - Customize saturation, lightness, and set per-path color overrides
- **Fast** - Synchronous updates optimized for speed
- **Non-Intrusive** - Silently disabled in non-iTerm2 terminals

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/michaelkoss/iterm-tint/main/install.sh | sh
```

## Installation

### Option 1: Curl Installer (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/michaelkoss/iterm-tint/main/install.sh | sh
```

The installer will:
1. Clone the repository to `~/.iterm-tint`
2. Add the source line to your shell's rc file
3. Create `~/.itint` with default configuration

### Option 2: Manual Installation

```bash
git clone https://github.com/michaelkoss/iterm-tint.git ~/.iterm-tint
```

Then add to your shell configuration:

**Zsh** (`~/.zshrc`):
```bash
source ~/.iterm-tint/iterm-tint.sh
```

**Bash** (`~/.bashrc`):
```bash
source ~/.iterm-tint/iterm-tint.sh
```

**Fish** (`~/.config/fish/config.fish`):
```fish
source ~/.iterm-tint/shells/fish.fish
```

### Updating

```bash
cd ~/.iterm-tint && git pull
```

## Configuration

Configuration is stored in `~/.itint`. See [docs/configuration.md](docs/configuration.md) for full details.

Example:
```bash
ITINT_DEFAULT_SATURATION=50
ITINT_DEFAULT_LIGHTNESS=50
ITINT_HASH_MODE=absolute_path

[overrides]
~/work 180
~/personal 90
```

## Documentation

| Document | Description |
|----------|-------------|
| [Configuration](docs/configuration.md) | Complete configuration reference and override rules |
| [How It Works](docs/how-it-works.md) | Technical internals: hashing, HSL colors, git detection |
| [Shell Integration](docs/shell-integration.md) | Shell-specific setup and hook mechanisms |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and FAQ |

## License

MIT License - see [LICENSE](LICENSE) for details.
