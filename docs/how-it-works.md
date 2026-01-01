# How It Works

This document explains the technical internals of iterm-tint.

## Overview

When you change directories, iterm-tint:

1. Detects the git root (if any) for the current directory
2. Generates a hash from the path
3. Converts the hash to an HSL color
4. Converts HSL to RGB
5. Sends iTerm2 escape codes to update the tab color

---

## Git Root Detection

### Recursive Upward Search

iterm-tint searches upward from the current directory looking for a `.git` folder or file:

```
/home/user/projects/myapp/src/components/
         ↑ search upward...
/home/user/projects/myapp/src/
/home/user/projects/myapp/        ← .git found here (git root)
```

The search stops at:
- The user's home directory (`~`)
- The system root (`/`)

### Non-Git Directories

For paths outside any git repository, the full absolute path of the current directory is used for color generation.

### Submodule Detection

The tool distinguishes between regular repositories and submodules:

| `.git` Type | Meaning | Behavior |
|-------------|---------|----------|
| Directory | Regular repository | Use this path for color hashing |
| File | Submodule | Behavior controlled by `ITINT_SUBMODULE_MODE` |

With `ITINT_SUBMODULE_MODE=parent`, the search continues upward to find the parent repository. With `unique`, the submodule gets its own color.

### Symlink Handling

Symlinked directories use the symlink path as-is without resolving to the real path. This means:

```bash
ln -s /home/user/projects/myapp ~/quick-access/myapp
cd ~/quick-access/myapp  # Uses ~/quick-access/myapp for hashing
```

---

## Color Generation

### DJB2 Hash Algorithm

iterm-tint uses the DJB2 hash algorithm to generate a consistent numeric hash from a path string:

```
Initial value: 5381
For each byte value in the UTF-8 encoded path string:
    hash = ((hash << 5) + hash) + byteValue

Final hue = hash mod 360
```

This produces a hue value between 0 and 360 degrees.

### Hash Modes

The `ITINT_HASH_MODE` setting controls what string is hashed:

| Mode | Input String | Use Case |
|------|--------------|----------|
| `absolute_path` | `/home/user/projects/myapp` | Different locations = different colors |
| `folder_name_only` | `myapp` | Same project name = same color everywhere |

### HSL Color Model

iterm-tint uses HSL (Hue, Saturation, Lightness) rather than RGB for color generation:

| Component | Range | Source |
|-----------|-------|--------|
| **Hue** | 0-360 | Generated from path hash |
| **Saturation** | 0-100 | From `ITINT_DEFAULT_SATURATION` or override |
| **Lightness** | 0-100 | From `ITINT_DEFAULT_LIGHTNESS` or override |

This ensures consistent perceived brightness across all colors - a green tab and a blue tab will appear equally "bright" if they share the same saturation and lightness.

### HSL to RGB Conversion

The HSL color is converted to RGB (0-255 per channel) for iTerm2:

```
1. Normalize: H' = H/360, S' = S/100, L' = L/100
2. Calculate chroma: C = (1 - |2L' - 1|) × S'
3. Calculate intermediate: X = C × (1 - |H' × 6 mod 2 - 1|)
4. Calculate match: m = L' - C/2
5. Map to RGB based on hue sector
6. Scale to 0-255 range
```

---

## Contrast Calculation

iterm-tint automatically selects black or white text for optimal readability:

| Background Lightness | Text Color |
|---------------------|------------|
| L < 55% | White |
| L >= 55% | Black |

This threshold is based on perceived contrast - lighter backgrounds need dark text, darker backgrounds need light text.

---

## iTerm2 Communication

### Escape Code Protocol

iterm-tint uses iTerm2's proprietary escape codes to set tab colors. Each color (background and foreground) requires three separate escape sequences, one for each RGB channel:

**Background:**
```
\033]6;1;bg;red;brightness;{R}\a
\033]6;1;bg;green;brightness;{G}\a
\033]6;1;bg;blue;brightness;{B}\a
```

**Foreground:**
```
\033]6;1;fg;red;brightness;{R}\a
\033]6;1;fg;green;brightness;{G}\a
\033]6;1;fg;blue;brightness;{B}\a
```

Where `{R}`, `{G}`, and `{B}` are decimal values from 0-255.

### Terminal Detection

Before emitting escape codes, iterm-tint checks that it's running in iTerm2. In other terminals (Terminal.app, VS Code integrated terminal, SSH sessions, etc.), the tool silently does nothing.

---

## Override Priority

When determining which color to use, iterm-tint follows this priority order:

1. **Path override** (from `[overrides]` section) - highest priority
2. **Git root hash** (if in a git repository)
3. **Absolute path hash** (for non-git directories) - lowest priority

For path overrides, the most specific (longest matching prefix) wins:

```bash
[overrides]
~/work 180           # Matches ~/work and all subdirectories
~/work/client 240    # More specific, wins for ~/work/client/*
```

---

## Performance

### Synchronous Design

iterm-tint is designed to be synchronous - it runs to completion before the shell prompt appears. This is possible because:

- Upward directory traversal is fast (few filesystem calls)
- Hash calculation is O(n) where n is path length
- Color math is trivial computation
- Escape code output is minimal

### Optimization Boundaries

The recursive git root search stops at:
- User home directory (`~`)
- System root (`/`)

This prevents runaway searches on deep directory structures or slow network filesystems.
