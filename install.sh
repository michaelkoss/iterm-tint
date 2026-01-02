#!/bin/sh
# iterm-tint installer
# https://github.com/michaelkoss/iterm-tint
#
# Usage: curl -fsSL https://raw.githubusercontent.com/michaelkoss/iterm-tint/main/install.sh | sh

set -e

INSTALL_DIR="$HOME/.iterm-tint"
CONFIG_FILE="$HOME/.itint"
REPO_URL="https://github.com/michaelkoss/iterm-tint.git"

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

info() {
    printf "${BLUE}[info]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[done]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[warn]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[error]${NC} %s\n" "$1" >&2
    exit 1
}

# Check for required commands
check_requirements() {
    if ! command -v git >/dev/null 2>&1; then
        error "git is required but not installed. Please install git first."
    fi
}

# Clone or update the repository
install_repo() {
    if [ -d "$INSTALL_DIR" ]; then
        info "Updating existing installation..."
        cd "$INSTALL_DIR" || error "Cannot enter directory $INSTALL_DIR"
        if git pull --quiet origin main 2>/dev/null || git pull --quiet 2>/dev/null; then
            success "Updated iterm-tint"
        else
            warn "Could not update repository"
        fi
    else
        info "Cloning iterm-tint..."
        if ! git clone --quiet "$REPO_URL" "$INSTALL_DIR"; then
            error "Failed to clone iterm-tint repository"
        fi
        success "Installed iterm-tint to $INSTALL_DIR"
    fi
}

# Detect the user's default shell
detect_shell() {
    # Check SHELL environment variable first
    case "$SHELL" in
        */zsh)  echo "zsh" ;;
        */bash) echo "bash" ;;
        */fish) echo "fish" ;;
        *)
            # Fall back to checking which rc files exist
            if [ -f "$HOME/.zshrc" ]; then
                echo "zsh"
            elif [ -f "$HOME/.bashrc" ]; then
                echo "bash"
            elif [ -f "$HOME/.config/fish/config.fish" ]; then
                echo "fish"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Get the rc file path for a given shell
get_rc_file() {
    case "$1" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *)    echo "" ;;
    esac
}

# Get the source line for a given shell
get_source_line() {
    case "$1" in
        zsh|bash) echo "source ~/.iterm-tint/iterm-tint.sh" ;;
        fish)     echo "source ~/.iterm-tint/shells/fish.fish" ;;
        *)        echo "" ;;
    esac
}

# Add source line to rc file if not already present
add_source_line() {
    local shell_name="$1"
    local rc_file="$2"
    local source_line="$3"

    # Create rc file if it doesn't exist (especially for fish)
    if [ ! -f "$rc_file" ]; then
        if [ "$shell_name" = "fish" ]; then
            mkdir -p "$(dirname "$rc_file")"
        fi
        touch "$rc_file"
    fi

    # Check if source line already exists
    if grep -qF ".iterm-tint/" "$rc_file" 2>/dev/null; then
        info "Source line already present in $rc_file"
        return 0
    fi

    # Add source line
    printf "\n# iterm-tint: dynamic iTerm2 tab colors\n%s\n" "$source_line" >> "$rc_file"
    success "Added source line to $rc_file"
}

# Create default config file
create_config() {
    if [ -f "$CONFIG_FILE" ]; then
        info "Config file already exists at $CONFIG_FILE"
        return 0
    fi

    cat > "$CONFIG_FILE" << 'EOF'
# iterm-tint configuration
# https://github.com/michaelkoss/iterm-tint
#
# Uncomment and modify settings as needed.
# All settings are optional - defaults are shown below.

# Color settings (0-100)
# ITINT_DEFAULT_SATURATION=50
# ITINT_DEFAULT_LIGHTNESS=50

# Hash mode: absolute_path | folder_name_only
# - absolute_path: Same project in different locations = different colors
# - folder_name_only: Same project name = same color everywhere
# ITINT_HASH_MODE=absolute_path

# Submodule handling: parent | unique
# - parent: Submodules share parent repo's color
# - unique: Submodules get their own color
# ITINT_SUBMODULE_MODE=parent

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

# ─────────────────────────────────────────────
# Path-specific color overrides
# ─────────────────────────────────────────────
# Format: <path> <hue> [saturation lightness]
# - Hue: 0=Red, 60=Yellow, 120=Green, 180=Cyan, 240=Blue, 300=Magenta
# - Most specific path wins (longest prefix match)
#
# [overrides]
# ~/work 180
# ~/work/client-project 180 60 45
# ~/personal 90
# /tmp 0 30 30
EOF

    success "Created config file at $CONFIG_FILE"
}

# Main installation
main() {
    printf "\n"
    info "Installing iterm-tint..."
    printf "\n"

    # Check requirements
    check_requirements

    # Install/update repository
    install_repo

    # Detect shell and configure
    local user_shell
    user_shell=$(detect_shell)

    if [ "$user_shell" = "unknown" ]; then
        warn "Could not detect shell. Please manually add the source line to your shell config."
        warn "For zsh/bash: source ~/.iterm-tint/iterm-tint.sh"
        warn "For fish: source ~/.iterm-tint/shells/fish.fish"
    else
        local rc_file source_line
        rc_file=$(get_rc_file "$user_shell")
        source_line=$(get_source_line "$user_shell")
        add_source_line "$user_shell" "$rc_file" "$source_line"
    fi

    # Create config file
    create_config

    printf "\n"
    success "iterm-tint installed successfully!"
    printf "\n"
    info "To start using iterm-tint, either:"
    info "  1. Open a new terminal tab/window, or"
    if [ "$user_shell" != "unknown" ]; then
        info "  2. Run: source $rc_file"
    else
        info "  2. Source the appropriate file for your shell (see above)"
    fi
    printf "\n"
    info "Configuration: $CONFIG_FILE"
    info "Documentation: https://github.com/michaelkoss/iterm-tint"
    printf "\n"
}

main "$@"
