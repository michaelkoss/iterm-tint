# Requirements Document: `iterm-tint`

---

## 1. Core Purpose

**`iterm-tint`** is a shell-integrated utility for macOS iTerm2 that dynamically changes tab colors based on the current working directory. It utilizes **HSL** color logic to provide a consistent visual identity for projects while ensuring high text readability and terminal performance.

---

## 2. User Behavior & Expectations

* **Git-Awareness:** The tool performs a **Recursive Upward Search** for a `.git` folder, stopping at the user's home directory (`~`) or system root (`/`). All sub-folders within a repository share the same color.
* **Non-Git Folders:** Paths outside of Git repositories are colored based on a hash of the **Full Absolute Path**.
* **Active Focus:** In iTerm2 split-pane views, the tab color reflects the **currently active pane** (configurable). Clicking between panes updates the tab color instantly.
* **Visual Hierarchy:** **Inactive tabs** are automatically dimmed (reduced Lightness and Saturation) to distinguish them from the active tab. *(Implementation deferred to future version)*
* **Responsiveness:** Updates are **Synchronous** but optimized for speed. The implementation should be fast enough that async processing is unnecessary.
* **Non-iTerm2 Terminals:** The tool **silently does nothing** when sourced in unsupported terminals (Terminal.app, VS Code, SSH sessions, etc.).

---

## 3. Technical Logic

### 3.1 Color Generation (HSL)

The background color is determined by the HSL (Hue, Saturation, Lightness) model to maintain consistent "brightness" regardless of the specific color.

* **Hue (H):** A value between 0 and 360 generated via a **DJB2 hash** of the directory path, using an initial value of `5381` and the update formula `hash = ((hash << 5) + hash) + byte` applied to each byte of the UTF-8–encoded path, then taking `hash mod 360`.
* **Saturation (S) & Lightness (L):** Static constants pulled from the configuration file to maintain a specific visual "vibe."
  * **Default Saturation:** 50%
  * **Default Lightness:** 50%

### 3.2 Hash Modes

The `ITINT_HASH_MODE` setting controls what string is hashed:

* **`absolute_path`** (default): Hash the full absolute path to the git root (or current directory for non-git paths).
* **`folder_name_only`**: Hash only the git root folder name. This means the same project has the same color regardless of where it's cloned on the filesystem.

### 3.3 Contrast Awareness

The tool automatically determines the optimal grayscale color for the tab text (Foreground) to ensure maximum contrast.

* If the background lightness **L ≥ 55%**, the text color is set to **Black**.
* If the background lightness **L < 55%**, the text color is set to **White**.

### 3.4 Git Submodule Handling

The tool detects whether `.git` is a **file** (submodule) or **directory** (regular repo):

* **`.git` directory:** Regular repository, use this path for color hashing.
* **`.git` file:** Submodule, behavior controlled by `ITINT_SUBMODULE_MODE`:
  * **`parent`** (default): Continue searching upward to find parent repo (submodule shares parent's color).
  * **`unique`**: Treat submodule as its own repo (gets unique color based on its path).

### 3.5 Symlink Handling

Symlinked directories use the **symlink path as-is** without resolving to the real path.

### 3.6 Integration

* **Trigger:** Utilizes shell hooks to execute logic upon directory changes:
  * **Zsh:** `chpwd` hook
  * **Bash:** `PROMPT_COMMAND` or `cd` wrapper
  * **Fish:** `--on-variable PWD` function
* **iTerm2 Control:** Communication is handled via iTerm2's proprietary RGB escape codes. For each color, you must emit three separate sequences (red, green, blue components, 0–255):
  * **Background (RGB example):**
    * `\033]6;1;bg;red;brightness;{R}\a`
    * `\033]6;1;bg;green;brightness;{G}\a`
    * `\033]6;1;bg;blue;brightness;{B}\a`
  * **Foreground (RGB example):**
    * `\033]6;1;fg;red;brightness;{R}\a`
    * `\033]6;1;fg;green;brightness;{G}\a`
    * `\033]6;1;fg;blue;brightness;{B}\a`

  Here `{R}`, `{G}`, and `{B}` are decimal values in the range `0`–`255` derived from the computed HSL color; `brightness` and the channel names (`red`, `green`, `blue`) are literal parts of the iTerm2 escape-code protocol.
---

## 4. Configuration (`~/.itint`)

The configuration file is located at `~/.itint`. It uses a **shell-sourceable format** with an `ITINT_` prefix for all variables, plus a special `[overrides]` section.

### 4.1 Configuration Settings

| Setting | Description | Default |
| --- | --- | --- |
| **`ITINT_DEFAULT_SATURATION`** | Global saturation percentage from 0 to 100 (no `%` sign) for active tabs. | `50` |
| **`ITINT_DEFAULT_LIGHTNESS`** | Global lightness percentage from 0 to 100 (no `%` sign) for active tabs. | `50` |
| **`ITINT_DIM_MULTIPLIER`** | Factor by which S and L are reduced for inactive tabs. *(Future)* | `0.5` |
| **`ITINT_HASH_MODE`** | Choose between `absolute_path` or `folder_name_only`. | `absolute_path` |
| **`ITINT_FOCUS_MODE`** | Toggle between `active_focus` or `primary_pane`. | `active_focus` |
| **`ITINT_SUBMODULE_MODE`** | How to handle git submodules: `parent` or `unique`. | `parent` |

### 4.2 Focus Modes

* **`active_focus`**: The currently focused pane determines the tab color.
* **`primary_pane`**: The original pane (before any splits were created) determines the tab color.

### 4.3 Example Configuration File

```bash
# iterm-tint configuration
# See: https://github.com/michaelkoss/iterm-tint/docs/CONFIGURATION.md

# Color settings (0-100)
ITINT_DEFAULT_SATURATION=50
ITINT_DEFAULT_LIGHTNESS=50

# Inactive tab dimming multiplier (future feature)
# ITINT_DIM_MULTIPLIER=0.5

# Hash mode: absolute_path | folder_name_only
ITINT_HASH_MODE=absolute_path

# Focus mode: active_focus | primary_pane
ITINT_FOCUS_MODE=active_focus

# Submodule handling: parent | unique
ITINT_SUBMODULE_MODE=parent

# ─────────────────────────────────────────────
# Theme alternatives (uncomment to try):
# ─────────────────────────────────────────────
# Vibrant theme
# ITINT_DEFAULT_SATURATION=70
# ITINT_DEFAULT_LIGHTNESS=50

# Muted theme
# ITINT_DEFAULT_SATURATION=30
# ITINT_DEFAULT_LIGHTNESS=45

# Dark theme
# ITINT_DEFAULT_SATURATION=50
# ITINT_DEFAULT_LIGHTNESS=30

# Pastel theme
# ITINT_DEFAULT_SATURATION=40
# ITINT_DEFAULT_LIGHTNESS=65

[overrides]
# Path-specific color overrides
# Format: <path> <hue> [saturation lightness]
# - Tilde (~) expansion is supported
# - Hue-only: uses default S and L values
# - Full HSL: specify all three values
# - Most specific path wins (longest prefix match)
#
# Examples:
# ~/work 180
# ~/work/client-project 180 60 45
# ~/personal 90
# /tmp 0 30 30
```

### 4.4 Override Rules

1. **Tilde expansion:** Paths starting with `~` are expanded to the user's home directory.
2. **Prefix matching:** An override applies to the specified path and **all subdirectories**.
3. **Most specific wins:** If multiple overrides match, the **longest matching prefix** takes priority.
4. **Value formats:**
   * **Hue only:** `~/path 180` — uses default saturation and lightness.
   * **Full HSL:** `~/path 180 60 45` — specifies all three values.
   * *(Partial values like hue + saturation without lightness are NOT supported)*
5. **Priority:** Manual overrides take precedence over both git-root logic and standard path hashing.

### 4.5 Configuration Errors

If the config file contains syntax errors or invalid values:
* A **one-time warning** is printed per shell session.
* **Default values** are used for any invalid/missing settings.

---

## 5. Installation

### 5.1 Recommended: Curl Installer

```bash
curl -fsSL https://raw.githubusercontent.com/michaelkoss/iterm-tint/main/install.sh | sh
```

The installer will:
1. Clone the repository to `~/.iterm-tint`
2. Add the appropriate source line to your shell's rc file (`.zshrc`, `.bashrc`, or `config.fish`)
3. Create `~/.itint` with commented default configuration
4. Display a message directing users to review the config file

### 5.2 Manual Installation

```bash
git clone https://github.com/michaelkoss/iterm-tint.git ~/.iterm-tint
echo 'source ~/.iterm-tint/iterm-tint.sh' >> ~/.zshrc  # Zsh example; adapt for .bashrc or config.fish
```

### 5.3 Updating

```bash
cd ~/.iterm-tint && git pull
```

### 5.4 First-Time Setup

On first install, `~/.itint` is automatically created with:
* All settings commented out (using defaults)
* Helpful comments explaining each option
* Links to documentation
* Example theme alternatives

---

## 6. Project Structure

```
~/.iterm-tint/
├── install.sh              # Curl-based installer script
├── iterm-tint.sh           # Main entry point (sources shell-specific files)
├── LICENSE                 # MIT License
├── README.md               # Quick start guide
├── lib/
│   ├── hash.sh             # DJB2 hashing implementation
│   ├── color.sh            # HSL to RGB conversion, contrast calculation
│   ├── git.sh              # Git root detection, submodule handling
│   └── config.sh           # Configuration parsing
├── shells/
│   ├── zsh.sh              # Zsh-specific hooks and integration
│   ├── bash.sh             # Bash-specific hooks and integration
│   └── fish.fish           # Fish-specific hooks and integration
├── docs/
│   └── CONFIGURATION.md    # Detailed configuration reference
└── tests/
    └── test.sh             # Basic unit tests for core functions
```

---

## 7. Shell Support

| Shell | Hook Mechanism | Config File |
| --- | --- | --- |
| **Zsh** | `chpwd` hook | `~/.zshrc` |
| **Bash** | `PROMPT_COMMAND` | `~/.bashrc` |
| **Fish** | `--on-variable PWD` | `~/.config/fish/config.fish` |

---

## 8. Edge Cases

* **Slow File Systems:** For network drives or massive monorepos, the synchronous implementation should still be fast enough due to the simple upward directory traversal.
* **Deep Nesting:** Recursive searches stop at the User Home (`~`) or System Root (`/`) to optimize performance.
* **Conflict Resolution:** If a folder is both a Git-root and has a manual override in `.itint`, the **Manual Override** takes priority.
* **Non-iTerm2 Terminals:** Silently disabled (no errors, no output).
* **Config Errors:** One-time warning per session, then use defaults.

---

## 9. Future Features

The following features are planned for future versions:

### 9.1 CLI Tool

A full command-line interface for managing iterm-tint:

```bash
itint update      # Update to latest version (git pull)
itint uninstall   # Remove iterm-tint and clean up rc files
itint doctor      # Diagnose issues and check configuration
itint reload      # Reload configuration
itint status      # Show current color and configuration
itint set <key> <value>  # Set a configuration value
```

### 9.2 Inactive Tab Dimming

Automatic dimming of inactive tabs using the `ITINT_DIM_MULTIPLIER` setting.

---

## 10. Testing

A basic test script (`tests/test.sh`) provides unit tests for core functions:
* DJB2 hash implementation
* HSL to RGB conversion
* Contrast threshold calculation
* Git root detection
* Configuration parsing

---

## 11. License

MIT License — see LICENSE file for details.
