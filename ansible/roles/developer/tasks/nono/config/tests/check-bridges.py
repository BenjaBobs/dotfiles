"""Check relocated package wiring without touching live agent state.

Optionally pass an installed packages/nolabs-ai directory to check real packs too.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib


BRIDGE = Path(__file__).resolve().parents[1] / "bridges/agent-bridge.py"


def fixture(root, agent):
    """Small upstream-shaped packs; no vendored third-party instructions."""
    pack = root / agent
    manifest_dir = ".codex-plugin" if agent == "codex" else ".claude-plugin"
    files = {
        f"{manifest_dir}/plugin.json": '{"name":"nono","version":"1.0.0"}',
        "skills/nono-sandbox/SKILL.md": "Fixture skill",
        "wiring/profile-drafts-dir-marker": "Fixture marker",
        "wiring/marketplace.json": '{"name":"nolabs-ai","plugins":[{"name":"nono","source":"./plugins/nono"}]}',
    }
    home = f"$HOME/.{agent}"
    wiring = [
        {"type": "write_file", "source": "wiring/profile-drafts-dir-marker",
         "dest": f"$NONO_CONFIG/profile-drafts/.nono-{agent}-pack-marker"},
        {"type": "symlink", "link": f"{home}/plugins/cache/$NS/nono/" + ("local" if agent == "codex" else "1.0.0"),
         "target": "$PACK_DIR"},
    ]
    if agent == "codex":
        files["bin/nono-draft-profile"] = "#!/usr/bin/env python3\nprint('fixture helper')\n"
        files["wiring/codex-block.toml"] = '''developer_instructions = "Use $HOME/.codex/bin/nono-draft-profile"
[marketplaces.nolabs-ai]
source_type = "local"
source = "$HOME/.codex/plugins/marketplaces/nolabs-ai"
[plugins."nono@nolabs-ai"]
enabled = true
'''
        wiring.extend([
            {"type": "write_file", "source": "bin/nono-draft-profile", "dest": home + "/bin/nono-draft-profile"},
            {"type": "symlink", "link": home + "/plugins/marketplaces/$NS/plugins/nono", "target": "$PACK_DIR"},
            {"type": "write_file", "source": "wiring/marketplace.json",
             "dest": home + "/plugins/marketplaces/$NS/.agents/plugins/marketplace.json"},
            {"type": "toml_block", "file": home + "/config.toml", "content": "wiring/codex-block.toml"},
        ])
    else:
        files["hooks/hooks.json"] = '{"hooks":{"PostToolUseFailure":[],"PostToolUse":[]}}'
        files["bin/nono-hook.sh"] = "#!/bin/sh\nexit 0\n"
        for source in (f"{manifest_dir}/plugin.json", "hooks/hooks.json", "bin/nono-hook.sh", "skills/nono-sandbox/SKILL.md"):
            wiring.append({"type": "write_file", "source": source,
                           "dest": home + "/plugins/marketplaces/$NS/plugins/nono/" + source})
        wiring.append({"type": "write_file", "source": "wiring/marketplace.json",
                       "dest": home + "/plugins/marketplaces/$NS/.claude-plugin/marketplace.json"})
        patches = {
            "known-marketplaces": ("plugins/known_marketplaces.json", {"nolabs-ai": {"installLocation": home + "/plugins/marketplaces/$NS"}}),
            "installed-plugin": ("plugins/installed_plugins.json", {"version": 2, "plugins": {"nono@nolabs-ai": [{"installPath": home + "/plugins/cache/$NS/nono/1.0.0"}]}}),
            "enabled-plugin": ("settings.json", {"enabledPlugins": {"nono@nolabs-ai": True}}),
        }
        for name, (dest, patch) in patches.items():
            source = f"wiring/{name}.json"
            files[source] = json.dumps(patch)
            wiring.append({"type": "json_merge", "file": home + "/" + dest, "patch": source})
    files["package.json"] = json.dumps({"schema_version": 1, "name": agent, "version": "1.0.0", "wiring": wiring})
    for relative, data in files.items():
        target = pack / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data)
    return pack


def check(root, source, agent):
    pack = root / "pack" / agent
    shutil.copytree(source, pack)
    original = {p.relative_to(pack): p.read_bytes() for p in pack.rglob("*") if p.is_file()}
    state = root / 'state with spaces " and $token' / agent
    state.mkdir(parents=True)
    config = root / "config/nono"
    config.mkdir(parents=True, exist_ok=True)
    user_config = '''developer_instructions = "Keep user instructions $NS"
model = "user-model"
[plugins."other@work.example"]
enabled = true
[marketplaces.work]
source_type = "local"
source = "$HOME/.codex/custom-$NS"
'''
    if agent == "codex":
        (state / "config.toml").write_text(user_config)
    else:
        (state / "settings.json").write_text(json.dumps({"permissions": {"allow": ["Read"]}, "enabledPlugins": {"other@work": True}}))
        (state / "plugins").mkdir()
        (state / "plugins/installed_plugins.json").write_text('{"version":2,"plugins":{"other@work":[]}}')
    command = [sys.executable, str(BRIDGE), "install", agent, "--pack-dir", str(pack),
               "--state-dir", str(state), "--nono-config", str(config)]
    def run(action="install", ok=True):
        argv = command.copy()
        argv[2] = action
        result = subprocess.run(argv, capture_output=True)
        assert (result.returncode == 0) == ok, result.stderr.decode()
        return result
    run("args", ok=False)  # No unprepared launch.
    # Simultaneous first launches serialize installation and keep stdout NUL-framed.
    prepare_command = command.copy()
    prepare_command[2] = "prepare"
    processes = [subprocess.Popen(prepare_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(3)]
    outputs = [process.communicate() for process in processes]
    assert all(process.returncode == 0 for process in processes), outputs
    assert sum(b"bridged nolabs-ai/" in stderr for _, stderr in outputs) == 1
    assert all(stdout.endswith(b"\0") and b"bridged nolabs-ai/" not in stdout for stdout, _ in outputs)
    before = {p: p.stat().st_mtime_ns for p in state.rglob("*") if p.is_file() and not p.is_symlink()}
    unchanged = run("prepare")
    assert not unchanged.stderr, unchanged.stderr
    assert before == {p: p.stat().st_mtime_ns for p in before}
    run()  # Idempotent links and merge.
    args = run("args").stdout.decode().split("\0")[:-1]
    assert agent + "-local" in " ".join(args)
    assert str(config / "profile-drafts") in " ".join(args)
    if agent == "codex":
        assert (state / "config.toml").read_text() == user_config
        overrides = tomllib.loads("\n".join(args[1::2]))
        assert "Keep user instructions" in overrides["developer_instructions"]
        assert "Keep user instructions $NS" in overrides["developer_instructions"]
        assert str(state / "bin/nono-draft-profile") in overrides["developer_instructions"]
        assert "$HOME/.codex" not in overrides["developer_instructions"]
        assert overrides["plugins"]["nono@nolabs-ai"]["enabled"] is True
        assert overrides["plugins"]["other@work.example"]["enabled"] is True
        assert overrides["marketplaces"]["work"]["source"] == "$HOME/.codex/custom-$NS"
        assert overrides["marketplaces"]["nolabs-ai"]["source"] == str(state / "plugins/marketplaces/nolabs-ai")
        helper = state / "bin/nono-draft-profile"
        assert helper.resolve() == (pack / "bin/nono-draft-profile").resolve()
        helper.unlink()
        run("args", ok=False)
        run("prepare", ok=False)  # Missing artifacts still stop an otherwise unchanged installation.
        run()
        if "argparse" in helper.read_text():
            env = dict(os.environ, XDG_CONFIG_HOME=str(config.parent))
            result = subprocess.run([sys.executable, str(helper), "--name", "codex-extra-read", "--extends", "codex-local", "--read", str(root)], env=env, capture_output=True)
            assert result.returncode == 0, result.stderr
            draft = json.loads((config / "profile-drafts/codex-extra-read.json").read_text())
            assert draft["extends"] == "codex-local"
    else:
        assert args[0] == "--append-system-prompt"
        settings = json.loads((state / "settings.json").read_text())
        assert settings["permissions"] == {"allow": ["Read"]}
        assert settings["enabledPlugins"] == {"other@work": True, "nono@nolabs-ai": True}
        installed = json.loads((state / "plugins/installed_plugins.json").read_text())
        assert "other@work" in installed["plugins"]
        assert installed["plugins"]["nono@nolabs-ai"][0]["installPath"].startswith(str(state))
        hooks = state / "plugins/marketplaces/nolabs-ai/plugins/nono/hooks/hooks.json"
        assert hooks.resolve() == (pack / "hooks/hooks.json").resolve()
        settings["enabledPlugins"]["nono@nolabs-ai"] = False
        (state / "settings.json").write_text(json.dumps(settings))
        run("args", ok=False)
        run("prepare", ok=False)  # No refresh when unchanged: retain a deliberate plugin disable.
        run()
        run("args")
    assert original == {p.relative_to(pack): p.read_bytes() for p in pack.rglob("*") if p.is_file()}
    cache = state / "plugins/cache/nolabs-ai/nono" / ("local" if agent == "codex" else "1.0.0")
    cache.unlink()
    cache.write_text("Conflicting user file")
    run(ok=False)
    assert cache.read_text() == "Conflicting user file"
    cache.unlink()
    run()
    # Registry wiring updates are refreshed on the next launch.
    marketplace = pack / "wiring/marketplace.json"
    marketplace.write_text(marketplace.read_text() + "\n")
    run("args", ok=False)
    refreshed = run("prepare")
    assert b"bridged nolabs-ai/" in refreshed.stderr
    run("args")
    # New package/plugin versions can introduce a different cache destination.
    manifest = json.loads((pack / "package.json").read_text())
    manifest["version"] = "2.0.0"
    for rule in manifest["wiring"]:
        if rule["type"] == "symlink" and "/cache/" in rule["link"]:
            rule["link"] = rule["link"].rsplit("/", 1)[0] + "/next-version"
    (pack / "package.json").write_text(json.dumps(manifest))
    run("prepare")
    assert (cache.parent / "next-version").resolve() == pack.resolve()
    assert json.loads((state / "nono-bridge.json").read_text())["version"] == "2.0.0"
    manifest = json.loads((pack / "package.json").read_text())
    manifest["wiring"].append({"type": "write_file", "source": "wiring/marketplace.json", "dest": str(root / "escape")})
    (pack / "package.json").write_text(json.dumps(manifest))
    run(ok=False)
    run("prepare", ok=False)
    assert not (root / "escape").exists()
    assert json.loads((state / "nono-bridge.json").read_text())["version"] == "2.0.0"
    hidden = pack.with_name(agent + "-missing")
    pack.rename(hidden)
    try:
        run("prepare", ok=False)  # Automatic preparation never downloads a missing pack.
    finally:
        hidden.rename(pack)
    print(f"{agent}: relocated wiring, preserved settings, arguments, drafts and update checks passed")


with tempfile.TemporaryDirectory(prefix="nono-bridge-check-", dir=os.environ.get("TMPDIR")) as tmp:
    root = Path(tmp)
    for agent in ("codex", "claude"):
        check(root / "synthetic" / agent, fixture(root / "fixtures", agent), agent)
        if len(sys.argv) > 1:
            check(root / "upstream" / agent, Path(sys.argv[1]) / agent, agent)
