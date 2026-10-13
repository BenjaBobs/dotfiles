if status is-interactive
    # Commands to run in interactive sessions can go here
end
zoxide init fish | source
~/.local/bin/mise activate fish | source
# Expose private mode (fish -P) to starship, which can't see unexported vars
if set -q fish_private_mode
    set -gx FISH_PRIVATE_MODE 1
else
    set -e FISH_PRIVATE_MODE
end
starship init fish | source
set EDITOR nvim

# Source local overrides if they exist
if test -f ~/.config/fish/local_config.fish
    source ~/.config/fish/local_config.fish
end

