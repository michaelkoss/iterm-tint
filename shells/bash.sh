# Bash-specific shell hook for iterm-tint
# This file is sourced by iterm-tint.sh when running in Bash

# Bash wrapper for PROMPT_COMMAND that only updates on directory change
_itint_prompt_command() {
    if [ "$PWD" != "$_ITINT_LAST_DIR" ]; then
        _itint_update
        _ITINT_LAST_DIR="$PWD"
    fi
}

# Register PROMPT_COMMAND hook
# Handle both string and array (bash 5+) PROMPT_COMMAND formats
if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" =~ "declare -a" ]]; then
    # PROMPT_COMMAND is an array (bash 5+)
    PROMPT_COMMAND=("_itint_prompt_command" "${PROMPT_COMMAND[@]}")
else
    # PROMPT_COMMAND is a string or unset
    PROMPT_COMMAND="_itint_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
