# Configuration

iterm-tint is configured via `~/.itint`, a shell-sourceable file with an `ITINT_` prefix for all variables.

## Table of Contents

- [File Location](#file-location)
- [Settings](#settings)
  - [ITINT_DEFAULT_SATURATION](#itint_default_saturation)
  - [ITINT_DEFAULT_LIGHTNESS](#itint_default_lightness)
  - [ITINT_HASH_MODE](#itint_hash_mode)
  - [ITINT_FOCUS_MODE](#itint_focus_mode)
  - [ITINT_SUBMODULE_MODE](#itint_submodule_mode)
  - [ITINT_DIM_MULTIPLIER](#itint_dim_multiplier)
- [Path Overrides](#path-overrides)
- [Example Themes](#example-themes)
- [Error Handling](#error-handling)

---

## File Location

The configuration file is located at `~/.itint`. It is automatically created on first install with all settings commented out (using defaults).

---

## Settings

### ITINT_DEFAULT_SATURATION

Controls the color saturation for tab backgrounds.

| Property | Value |
|----------|-------|
| **Type** | Integer (0-100) |
| **Default** | `50` |
| **Description** | Higher values produce more vivid colors; lower values are more muted |

**Example:**
```bash
ITINT_DEFAULT_SATURATION=70  # Vibrant colors
ITINT_DEFAULT_SATURATION=30  # Muted colors
```

---

### ITINT_DEFAULT_LIGHTNESS

Controls the brightness of tab backgrounds.

| Property | Value |
|----------|-------|
| **Type** | Integer (0-100) |
| **Default** | `50` |
| **Description** | Higher values are lighter; lower values are darker. Text color (black/white) is automatically chosen based on this value for optimal contrast |

**Example:**
```bash
ITINT_DEFAULT_LIGHTNESS=65  # Light/pastel backgrounds
ITINT_DEFAULT_LIGHTNESS=30  # Dark backgrounds
```

**Note:** Text color switches to white when lightness is below 55%, and black when at or above 55%.

---

### ITINT_HASH_MODE

Controls what string is hashed to generate the tab color.

| Property | Value |
|----------|-------|
| **Type** | String |
| **Default** | `absolute_path` |
| **Valid Values** | `absolute_path`, `folder_name_only` |

**Values:**

- **`absolute_path`** - Hash the full absolute path to the git root (or current directory for non-git paths). The same project cloned to different locations will have different colors.

- **`folder_name_only`** - Hash only the git root folder name. The same project will have the same color regardless of where it's cloned on the filesystem.

**Example:**
```bash
ITINT_HASH_MODE=folder_name_only  # Same project = same color everywhere
```

---

### ITINT_FOCUS_MODE

Controls which pane determines the tab color in split-pane views.

| Property | Value |
|----------|-------|
| **Type** | String |
| **Default** | `active_focus` |
| **Valid Values** | `active_focus`, `primary_pane` |

**Values:**

- **`active_focus`** - The currently focused pane determines the tab color. Clicking between panes updates the color instantly.

- **`primary_pane`** - The original pane (before any splits were created) determines the tab color. Color stays constant regardless of which pane is focused.

**Example:**
```bash
ITINT_FOCUS_MODE=primary_pane  # Color based on original pane
```

---

### ITINT_SUBMODULE_MODE

Controls how git submodules are handled for color generation.

| Property | Value |
|----------|-------|
| **Type** | String |
| **Default** | `parent` |
| **Valid Values** | `parent`, `unique` |

**Values:**

- **`parent`** - Continue searching upward to find the parent repository. Submodules share their parent's color.

- **`unique`** - Treat each submodule as its own repository. Submodules get unique colors based on their own paths.

**Example:**
```bash
ITINT_SUBMODULE_MODE=unique  # Submodules get their own colors
```

---

### ITINT_DIM_MULTIPLIER

> **Note:** This setting is reserved for a future feature.

Factor by which saturation and lightness are reduced for inactive tabs.

| Property | Value |
|----------|-------|
| **Type** | Float (0.0-1.0) |
| **Default** | `0.5` |
| **Description** | Inactive tabs will have S and L multiplied by this value to visually distinguish them from the active tab |

**Example:**
```bash
ITINT_DIM_MULTIPLIER=0.7  # Subtle dimming
ITINT_DIM_MULTIPLIER=0.3  # Strong dimming
```

---

## Path Overrides

The `[overrides]` section allows you to set specific colors for specific paths, bypassing the automatic hash-based color generation.

### Format

```bash
[overrides]
<path> <hue> [saturation lightness]
```

### Rules

1. **Tilde expansion** - Paths starting with `~` are expanded to the user's home directory
2. **Prefix matching** - An override applies to the specified path and all subdirectories
3. **Most specific wins** - If multiple overrides match, the longest matching prefix takes priority
4. **Priority** - Manual overrides take precedence over both git-root logic and standard path hashing

### Value Formats

| Format | Example | Description |
|--------|---------|-------------|
| Hue only | `~/work 180` | Uses default saturation and lightness |
| Full HSL | `~/work 180 60 45` | Specifies all three values |

**Note:** Only hue-only or full HSL formats are supported; partial values (for example, hue + saturation without lightness) are not allowed.

### Hue Reference

| Hue | Color |
|-----|-------|
| 0 | Red |
| 30 | Orange |
| 60 | Yellow |
| 120 | Green |
| 180 | Cyan |
| 240 | Blue |
| 270 | Purple |
| 300 | Magenta |

### Example

```bash
[overrides]
# Work projects - cyan
~/work 180

# Specific client with custom saturation/lightness
~/work/client-project 180 60 45

# Personal projects - green
~/personal 120

# Temporary files - dim red
/tmp 0 30 30
```

---

## Example Themes

Uncomment one of these theme blocks in your `~/.itint` to change the overall look:

### Vibrant
```bash
ITINT_DEFAULT_SATURATION=70
ITINT_DEFAULT_LIGHTNESS=50
```

### Muted
```bash
ITINT_DEFAULT_SATURATION=30
ITINT_DEFAULT_LIGHTNESS=45
```

### Dark
```bash
ITINT_DEFAULT_SATURATION=50
ITINT_DEFAULT_LIGHTNESS=30
```

### Pastel
```bash
ITINT_DEFAULT_SATURATION=40
ITINT_DEFAULT_LIGHTNESS=65
```

---

## Error Handling

If the configuration file contains syntax errors or invalid values:

- A **one-time warning** is printed per shell session
- **Default values** are used for any invalid or missing settings

The tool will continue to function with defaults rather than failing completely.
