function claude --description 'Claude Code under a task-scoped nono policy'
    set -l agent_bin (command --search claude)
    if test $status -ne 0; or test (count $agent_bin) -ne 1
        echo 'claude is not installed (not found on PATH).'
        return 127
    end
    set -l nono_config "$HOME/.config/nono"
    if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        set nono_config "$XDG_CONFIG_HOME/nono"
    end
    set -l session_tmp (sh "$nono_config/hooks/tmp-setup.sh")
    if test $status -ne 0; or test (count $session_tmp) -ne 1
        return 1
    end
    set -lx TMPDIR "$session_tmp"
    set -lx XDG_STATE_HOME "$HOME/.local/state"
    set -lx CLAUDE_CONFIG_DIR "$XDG_STATE_HOME/sandbox-agents/claude"
    set -lx CLAUDE_CODE_TMPDIR "$session_tmp"
    set -lx DISABLE_AUTOUPDATER 1
    set -lx XDG_CACHE_HOME "$session_tmp/cache"
    set -lx CARGO_HOME "$session_tmp/cargo"
    set -lx NUGET_PACKAGES "$session_tmp/nuget"
    set -lx DOTNET_CLI_HOME "$session_tmp/dotnet"
    set -lx MSBUILDDISABLENODEREUSE 1
    set -lx DOTNET_CLI_TELEMETRY_OPTOUT 1
    set -lx DOTNET_NOLOGO 1
    mkdir -p -- "$CLAUDE_CONFIG_DIR" "$XDG_CACHE_HOME" "$CARGO_HOME" "$NUGET_PACKAGES" "$DOTNET_CLI_HOME"
    if test $status -ne 0
        sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
        return 1
    end
    # Refresh changed package wiring on the host and supply the actual launch context.
    set -l bridge_args (command python3 "$nono_config/bridges/agent-bridge.py" prepare claude | string split0)
    if test $pipestatus[1] -ne 0; or test (count $bridge_args) -eq 0
        sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
        return 1
    end
    command nono run --profile claude-local -- "$agent_bin" $bridge_args $argv
    set -l run_status $status
    sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
    return $run_status
end
