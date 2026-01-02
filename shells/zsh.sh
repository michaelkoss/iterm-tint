# Zsh-specific shell hook for iterm-tint
# This file is sourced by iterm-tint.sh when running in Zsh

# Register chpwd hook for directory change detection
# The chpwd hook fires on cd, pushd, popd, and any other directory change
if [[ ! " ${chpwd_functions[*]} " =~ " _itint_update " ]]; then
    chpwd_functions+=(_itint_update)
fi
