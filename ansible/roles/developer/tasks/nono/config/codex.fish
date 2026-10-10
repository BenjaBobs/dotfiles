function codex --description 'Codex under a task-scoped nono policy'
    set -l agent_bin (command --search codex)
    if test $status -ne 0; or test (count $agent_bin) -ne 1
        echo 'codex is not installed (not found on PATH).'
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
    set -lx CODEX_HOME "$HOME/.local/state/sandbox-agents/codex"
    set -lx XDG_CACHE_HOME "$session_tmp/cache"
    set -lx CARGO_HOME "$session_tmp/cargo"
    set -lx NUGET_PACKAGES "$session_tmp/nuget"
    set -lx DOTNET_CLI_HOME "$session_tmp/dotnet"
    set -lx MSBUILDDISABLENODEREUSE 1
    set -lx DOTNET_CLI_TELEMETRY_OPTOUT 1
    set -lx DOTNET_NOLOGO 1
    mkdir -p -- "$CODEX_HOME" "$XDG_CACHE_HOME" "$CARGO_HOME" "$NUGET_PACKAGES" "$DOTNET_CLI_HOME"
    if test $status -ne 0
        sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
        return 1
    end
    # Refresh changed package wiring on the host before entering nono, then read launch arguments.
    set -l bridge_args (command python3 "$nono_config/bridges/agent-bridge.py" prepare codex | string split0)
    if test $pipestatus[1] -ne 0; or test (count $bridge_args) -eq 0
        sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
        return 1
    end
    command nono run --profile codex-local -- "$agent_bin" --no-daemon --sandbox danger-full-access -a never $bridge_args $argv
    set -l run_status $status
    sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
    return $run_status
end
