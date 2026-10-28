# Available to applications launched from fish, including during login.
set -gx EDITOR nvim

if status is-interactive
    # Activate mise first so its tools are available below.
    ~/.local/bin/mise activate fish | source

    zoxide init fish | source

    # Expose private mode to Starship.
    if set -q fish_private_mode
        set -gx FISH_PRIVATE_MODE 1
    else
        set -e FISH_PRIVATE_MODE
    end

    starship init fish | source
end

# Source local overrides if they exist.
if test -f ~/.config/fish/local_config.fish
    source ~/.config/fish/local_config.fish
end
