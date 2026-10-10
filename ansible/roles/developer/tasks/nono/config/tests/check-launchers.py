"""Exercise fish wrapper routing with external stand-ins and no agent execution."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FISH = shutil.which("fish")
assert FISH, "fish is required"

with tempfile.TemporaryDirectory(prefix="nono-launcher-check-", dir=os.environ.get("TMPDIR")) as tmp:
    fixture = Path(tmp)
    mock_bin = fixture / "bin"
    mock_bin.mkdir()
    session = fixture / "session"
    session.mkdir()
    call_log = fixture / "call.json"
    cleanup_log = fixture / "cleanup"
    direct_log = fixture / "direct"
    setup_log = fixture / "setup"

    for agent in ("codex", "claude"):
        executable = mock_bin / agent
        executable.write_text('#!/bin/sh\nprintf direct > "$NONO_TEST_DIRECT"\nexit 99\n')
        executable.chmod(0o700)

    nono = mock_bin / "nono"
    nono.write_text(
        "#!/usr/bin/python3\n"
        "import json, os, pathlib, sys\n"
        "keys = ('TMPDIR', 'CODEX_HOME', 'CLAUDE_CONFIG_DIR', 'CLAUDE_CODE_TMPDIR')\n"
        "record = {'args': sys.argv[1:], 'env': {k: os.environ.get(k) for k in keys}}\n"
        "pathlib.Path(os.environ['NONO_TEST_CALL']).write_text(json.dumps(record))\n"
        "sys.exit(37)\n"
    )
    nono.chmod(0o700)

    bridge_python = mock_bin / "python3"
    bridge_python.write_text(
        "#!/usr/bin/python3\n"
        "import os, sys\n"
        "assert sys.argv[2] == 'prepare'\n"
        "if os.environ.get('NONO_TEST_FAILURE') == 'bridge': sys.exit(13)\n"
        "sys.stdout.buffer.write(b'--bridge-test\\0multiline\\nquote \\\" ;$token\\0')\n"
    )
    bridge_python.chmod(0o700)

    env = os.environ.copy()
    env.update({
        "PATH": str(mock_bin),
        "NONO_TEST_SESSION": str(session),
        "NONO_TEST_CALL": str(call_log),
        "NONO_TEST_CLEANUP": str(cleanup_log),
        "NONO_TEST_DIRECT": str(direct_log),
        "NONO_TEST_SETUP": str(setup_log),
    })
    # Mock trusted setup/cleanup and directory creation without touching host state.
    harness = """
function sh
    if string match -q '*/tmp-setup.sh' -- $argv[1]
        printf setup > "$NONO_TEST_SETUP"
        if test "$NONO_TEST_FAILURE" = setup
            return 1
        end
        printf '%s\\n' "$NONO_TEST_SESSION"
    else
        printf '%s\\n' "$argv[2]" > "$NONO_TEST_CLEANUP"
    end
end
function mkdir
    if test "$NONO_TEST_FAILURE" = mkdir
        return 1
    end
    return 0
end
source $argv[1]
$argv[2] --model 'value with spaces' 'literal;$token'
exit $status
"""

    for agent, profile in (("codex", "codex-local"), ("claude", "claude-local")):
        for failure in ("", "agent", "setup", "mkdir", "bridge", "nono"):
            for log in (call_log, cleanup_log, direct_log, setup_log):
                log.unlink(missing_ok=True)
            env["NONO_TEST_FAILURE"] = failure
            if failure == "nono":
                nono.rename(mock_bin / "nono-disabled")
            if failure == "agent":
                (mock_bin / agent).rename(mock_bin / f"{agent}-disabled")
            try:
                result = subprocess.run(
                    [FISH, "--no-config", "-c", harness, str(ROOT / f"{agent}.fish"), agent],
                    env=env, capture_output=True, text=True,
                )
            finally:
                if failure == "nono":
                    (mock_bin / "nono-disabled").rename(nono)
                if failure == "agent":
                    (mock_bin / f"{agent}-disabled").rename(mock_bin / agent)
            expected = 37 if not failure else 127 if failure in ("agent", "nono") else 1
            assert result.returncode == expected, (agent, failure, result.stderr)
            assert not direct_log.exists(), "Agent was executed outside nono"
            assert call_log.exists() == (not failure), (agent, failure)
            assert setup_log.exists() == (failure != "agent"), (agent, failure)
            assert cleanup_log.exists() == (failure not in ("agent", "setup")), (agent, failure)
            if failure == "agent":
                assert result.stdout == f"{agent} is not installed (not found on PATH).\n"
                assert not result.stderr, result.stderr
            if cleanup_log.exists():
                assert cleanup_log.read_text().strip() == str(session)
            if call_log.exists():
                call = json.loads(call_log.read_text())
                args = call["args"]
                assert args[:4] == ["run", "--profile", profile, "--"]
                assert args[4] == str(mock_bin / agent)
                assert args[-3:] == ["--model", "value with spaces", "literal;$token"]
                assert args[-5:-3] == ["--bridge-test", 'multiline\nquote " ;$token']
                assert "--allow-net" not in args
                assert call["env"]["TMPDIR"] == str(session)
                key = "CODEX_HOME" if agent == "codex" else "CLAUDE_CONFIG_DIR"
                assert call["env"][key].endswith(f"/.local/state/sandbox-agents/{agent}")
                if agent == "claude":
                    assert call["env"]["CLAUDE_CODE_TMPDIR"] == str(session)
        print(f"{agent}: routing, arguments, exit status, cleanup and failure checks passed")
