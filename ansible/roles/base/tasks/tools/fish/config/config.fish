if status is-interactive
    # Commands to run in interactive sessions can go here
end
zoxide init fish | source
~/.local/bin/mise activate fish | source
starship init fish | source
set EDITOR nvim

# Source local overrides if they exist
if test -f ~/.config/fish/local_config.fish
    source ~/.config/fish/local_config.fish
end
