function sandbox --description 'Fish under a project-scoped nono policy'
    set -l shell_bin (command --search fish)
    if test $status -ne 0; or test (count $shell_bin) -ne 1
        echo 'fish is not installed (not found on PATH).'
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
    set -lx XDG_CACHE_HOME "$session_tmp/cache"
    set -lx CARGO_HOME "$session_tmp/cargo"
    set -lx NUGET_PACKAGES "$session_tmp/nuget"
    set -lx DOTNET_CLI_HOME "$session_tmp/dotnet"
    set -lx MSBUILDDISABLENODEREUSE 1
    set -lx DOTNET_CLI_TELEMETRY_OPTOUT 1
    set -lx DOTNET_NOLOGO 1
    mkdir -p -- "$session_tmp/config" "$session_tmp/data" "$session_tmp/state" "$XDG_CACHE_HOME" "$session_tmp/runtime" "$CARGO_HOME" "$NUGET_PACKAGES" "$DOTNET_CLI_HOME"
    if test $status -ne 0
        sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
        return 1
    end
    # Redirect shell state after nono resolves its own configuration and protected state.
    command nono run --profile shell-local --allow-net -- /usr/bin/env \
        "XDG_CONFIG_HOME=$session_tmp/config" "XDG_DATA_HOME=$session_tmp/data" \
        "XDG_STATE_HOME=$session_tmp/state" "XDG_RUNTIME_DIR=$session_tmp/runtime" \
        "$shell_bin" --no-config --interactive $argv
    set -l run_status $status
    sh "$nono_config/hooks/tmp-cleanup.sh" "$session_tmp"
    return $run_status
end
