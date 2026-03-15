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

if command -q claude
    if command -q nono
        function claude-work
            mkdir -p ~/.claude-work
            CLAUDE_CONFIG_DIR=~/.claude-work nono run -v --profile claude-flex --allow-cwd --allow ~/.claude-work -- claude $argv
        end
        function claude-home
            mkdir -p ~/.claude-home
            CLAUDE_CONFIG_DIR=~/.claude-home nono run -v --profile claude-flex --allow-cwd --allow ~/.claude-home -- claude $argv
        end
    else
        function claude-work
            echo "Don't use claude-code without nono"
        end
        function claude-home
            echo "Don't use claude-code without nono"
        end
    end
end
