# Requirements Document: `iterm-tint`

---

## 1. Core Purpose

**`iterm-tint`** is a shell-integrated utility for macOS iTerm2 that dynamically changes tab colors based on the current working directory. It utilizes **HSL** color logic to provide a consistent visual identity for projects while ensuring high text readability and terminal performance.

---

## 2. User Behavior & Expectations

* **Git-Awareness:** The tool performs a **Recursive Upward Search** for a `.git` folder. All sub-folders within a repository share the same color.
* **Non-Git Folders:** Paths outside of Git repositories are colored based on a hash of the **Full Absolute Path**.
* **Active Focus:** In iTerm2 split-pane views, the tab color reflects the **currently active pane**. Clicking between panes updates the tab color instantly.
* **Visual Hierarchy:** **Inactive tabs** are automatically dimmed (reduced Lightness and Saturation) to distinguish them from the active tab.
* **Responsiveness:** Updates are **Asynchronous**. The terminal prompt is never blocked, ensuring zero lag during navigation.

---

## 3. Technical Logic

### 3.1 Color Generation (HSL)

The background color is determined by the HSL (Hue, Saturation, Lightness) model to maintain consistent "brightness" regardless of the specific color.

* **Hue ():** A value between  and  generated via a string hash of the directory path.
* **Saturation () & Lightness ():** Static constants pulled from the configuration file to maintain a specific visual "vibe."

### 3.2 Contrast Awareness

The tool automatically determines the optimal grayscale color for the tab text (Foreground) to ensure maximum contrast.

* If the background lightness , the text color is set to **Black**.
* If the background lightness , the text color is set to **White**.

### 3.3 Integration

* **Trigger:** Utilizes shell hooks (e.g., `chpwd` in Zsh) to execute logic upon directory changes.
* **iTerm2 Control:** Communication is handled via proprietary escape codes:
* **Background:** `\033]6;1;bg;red;brightness;[value]\a`
* **Foreground:** `\033]6;1;fg;red;brightness;[value]\a`



---

## 4. Configuration (`~/.itint`)

The configuration file is located at `~/.itint`. It allows users to define the aesthetic and behavioral rules of the tool.

| Setting | Description | Default |
| --- | --- | --- |
| **`default_saturation`** | Global saturation percentage for active tabs. | `50%` |
| **`default_lightness`** | Global lightness percentage for active tabs. | `50%` |
| **`dim_multiplier`** | Factor by which  and  are reduced for inactive tabs. | `0.5` |
| **`hash_mode`** | Choose between `absolute_path` or `folder_name_only`. | `absolute_path` |
| **`focus_mode`** | Toggle between `active_focus` or `primary_pane`. | `active_focus` |
| **`overrides`** | A map of specific paths to custom HSL values. | `{}` |

### 4.1 Override Inheritance

If a directory is defined in the `overrides` section of `~/.itint`, that color is applied to that directory and **all sub-directories** (Top-Down Inheritance), taking precedence over standard hashing and Git-root logic.

---

## 5. Edge Cases

* **Slow File Systems:** For network drives or massive monorepos, the asynchronous background process prevents the UI from freezing while searching for `.git`.
* **Deep Nesting:** Recursive searches stop at the User Home (`~`) or System Root (`/`) to optimize performance.
* **Conflict Resolution:** If a folder is both a Git-root and has a manual override in `.itint`, the **Manual Override** takes priority.