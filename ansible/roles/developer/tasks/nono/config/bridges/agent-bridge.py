"""Adapt installed nono pack wiring to dedicated agent homes (Python 3.11+)."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import sys
import tempfile
import tomllib


def read_json(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"Expected an object in {path}")
    return value


def merge(base, patch):
    result = dict(base)
    for key, value in patch.items():
        if isinstance(value, dict):
            old = result.get(key, {})
            if not isinstance(old, dict):
                raise ValueError(f"Cannot merge object into {key}")
            result[key] = merge(old, value)
        else:
            result[key] = value
    return result


def contains(actual, expected):
    """Check required registration fields while allowing unrelated user settings."""
    if isinstance(expected, dict):
        return isinstance(actual, dict) and all(
            key in ("installedAt", "lastUpdated") or
            (key in actual and contains(actual[key], value))
            for key, value in expected.items())
    if isinstance(expected, list):
        return isinstance(actual, list) and all(
            any(contains(item, required) for item in actual) for required in expected)
    return actual == expected


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Rename prevents truncated settings if the process is interrupted.
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                     prefix=".nono-bridge-", delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(data)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


class Bridge:
    def __init__(self, args):
        self.agent = args.agent
        config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        self.config = Path(args.nono_config or config_home / "nono").absolute()
        default_state = Path.home() / ".local/state/sandbox-agents" / self.agent
        state_env = "CODEX_HOME" if self.agent == "codex" else "CLAUDE_CONFIG_DIR"
        self.state = Path(args.state_dir or os.environ.get(state_env, default_state)).absolute()
        self.pack = Path(args.pack_dir or self.config / "packages/nolabs-ai" / self.agent).absolute()
        self.manifest = read_json(self.pack / "package.json")
        if self.manifest.get("name") != self.agent or self.manifest.get("schema_version") != 1:
            raise ValueError("Unsupported package manifest")
        self.metadata = self.state / "nono-bridge.json"
        self.now = datetime.now(timezone.utc).isoformat()

    def expand(self, text):
        # Only relocate the package's agent home, never unrelated host paths.
        replacements = dict((
            (f"$HOME/.{self.agent}", str(self.state)),
            ("$NONO_CONFIG", str(self.config)), ("$PACK_DIR", str(self.pack)),
            ("$NS", "nolabs-ai"), ("$NOW", self.now),
        ))
        pattern = "|".join(re.escape(key) for key in replacements)
        return re.sub(pattern, lambda match: replacements[match.group()], text)

    def expanded(self, value):
        if isinstance(value, str):
            return self.expand(value)
        if isinstance(value, dict):
            return {k: self.expanded(v) for k, v in value.items()}
        if isinstance(value, list):
            return [self.expanded(v) for v in value]
        return value

    def source(self, relative):
        path = self.pack / relative
        if not path.resolve().is_relative_to(self.pack.resolve()) or not path.is_file():
            raise ValueError(f"Missing or invalid package artifact: {path}")
        return path

    def patch(self, relative):
        return self.expanded(read_json(self.source(relative)))

    def destination(self, text):
        if set(re.findall(r"\$[A-Za-z_][A-Za-z_0-9]*", text)) - {"$HOME", "$NS", "$NONO_CONFIG"}:
            raise ValueError(f"Unsupported wiring variable: {text}")
        path = Path(self.expand(text))
        if not path.is_absolute():
            raise ValueError(f"Unsupported wiring destination: {text}")
        # Resolve ancestors too, so existing symlinks cannot redirect installation.
        resolved_parent = path.parent.resolve() / path.name
        if not any(resolved_parent.is_relative_to(root.resolve()) for root in
                   (self.state, self.config / "profile-drafts")):
            raise ValueError(f"Wiring escapes dedicated state/drafts: {text}")
        return path

    def stamp(self):
        digest = hashlib.sha256((self.pack / "package.json").read_bytes())
        for path in sorted((self.pack / "wiring").iterdir()):
            if path.is_file():
                digest.update(path.name.encode())
                digest.update(path.read_bytes())
        return {"agent": self.agent, "pack": str(self.pack),
                "version": self.manifest["version"], "wiring_hash": digest.hexdigest()}

    def plan(self):
        operations = []
        for rule in self.manifest["wiring"]:
            kind = rule["type"]
            if kind == "toml_block" and self.agent == "codex":
                self.destination(rule["file"])
                block = tomllib.loads(self.source(rule["content"]).read_text())
                if not isinstance(block.get("developer_instructions"), str):
                    raise ValueError("Codex pack has no developer instructions")
                continue  # Loaded through CLI config overrides; preserve config.toml verbatim.
            if kind == "symlink":
                if rule["target"] != "$PACK_DIR":
                    raise ValueError("Unsupported package symlink target")
                operations.append(("link", self.destination(rule["link"]), self.pack))
            elif kind == "write_file":
                source = self.source(rule["source"])
                dest = self.destination(rule["dest"])
                if rule["source"].startswith("wiring/"):
                    operations.append(("write", dest, source.read_text()))
                else:
                    # Plugin/helper files stay linked to the registry-managed originals.
                    operations.append(("link", dest, source))
            elif kind == "json_merge" and self.agent == "claude":
                dest = self.destination(rule["file"])
                # Expand parsed strings, rather than raw JSON (paths may contain quotes).
                patch = self.patch(rule["patch"])
                old = read_json(dest) if dest.exists() else {}
                if dest.name == "installed_plugins.json" and old.get("version", 2) != 2:
                    raise ValueError("Unsupported Claude installed_plugins.json version")
                operations.append(("write", dest, json.dumps(merge(old, patch), indent=2) + "\n"))
            else:
                raise ValueError(f"Unsupported wiring type: {kind}")
        # Check all collisions before making changes.
        for kind, path, target in operations:
            if kind == "link" and (path.exists() or path.is_symlink()):
                if not path.is_symlink() or path.resolve() != target.resolve():
                    raise ValueError(f"Conflicting bridge path; move it aside first: {path}")
            if kind == "write" and path.is_symlink():
                raise ValueError(f"Refusing to overwrite symlink: {path}")
        return operations

    @contextmanager
    def locked(self):
        # Two shells may perform first launch or refresh at the same time.
        self.state.mkdir(parents=True, exist_ok=True)
        with (self.state / ".nono-bridge.lock").open("a") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            yield

    def install(self, report_to=sys.stdout):
        operations = self.plan()
        for kind, path, value in operations:
            if kind == "link":
                path.parent.mkdir(parents=True, exist_ok=True)
                if not path.is_symlink():
                    path.symlink_to(value, target_is_directory=value.is_dir())
            else:
                write(path, value)
        write(self.metadata, json.dumps(self.stamp(), indent=2) + "\n")
        print(f"{self.agent}: bridged nolabs-ai/{self.agent} {self.manifest['version']} into {self.state}", file=report_to)

    def prepare(self):
        with self.locked():
            if not self.metadata.is_file() or read_json(self.metadata) != self.stamp():
                # Wrapper calls this on the host before nono starts. Never download
                # packages or touch policy here; adapt the already installed pack.
                self.install(report_to=sys.stderr)
            return self.arguments()

    def context(self):
        return (
            f"Nono launch context: active profile is {self.agent}-local. "
            f"Dedicated agent home is {self.state}; profile drafts directory is {self.config / 'profile-drafts'}. "
            f"Draft a new name extending {self.agent}-local, never overwrite an installed profile. "
            "Diagnose ambiguous permission errors with nono why --self before treating them as nono denials. "
            "Ask the user to review and promote drafts outside the sandbox; do not promote them yourself. "
            "Restart guidance must retain this dedicated home and local profile, plus the wrapper's launch flags. "
            "Bare upstream restart examples omit this local configuration. "
            + (f"The pack draft helper is {self.state / 'bin/nono-draft-profile'}; "
               f"invoke it as python3 {shlex.quote(str(self.state / 'bin/nono-draft-profile'))} "
               "instead of executing ~/.codex/bin/nono-draft-profile directly. "
               if self.agent == "codex" else "")
        )

    def arguments(self):
        if not self.metadata.is_file() or read_json(self.metadata) != self.stamp():
            raise ValueError("Bridge missing or package wiring changed; rerun the bridge install command outside nono")
        # Check plugin/helper links remain installed without writing launch-time state.
        for rule in self.manifest["wiring"]:
            if rule["type"] == "symlink":
                path = self.destination(rule["link"])
                if not path.is_symlink() or path.resolve() != self.pack.resolve():
                    raise ValueError(f"Missing bridge plugin link: {path}")
            elif rule["type"] == "write_file" and not rule["source"].startswith("wiring/"):
                path = self.destination(rule["dest"])
                if not path.is_symlink() or path.resolve() != self.source(rule["source"]).resolve():
                    raise ValueError(f"Missing bridge helper/plugin artifact: {path}")
            elif rule["type"] == "json_merge":
                path = self.destination(rule["file"])
                if not contains(read_json(path), self.patch(rule["patch"])):
                    raise ValueError(f"Missing bridge plugin registration: {path}; rerun bridge install")
            elif rule["type"] == "write_file" and rule["source"] == "wiring/marketplace.json":
                path = self.destination(rule["dest"])
                if path.read_bytes() != self.source(rule["source"]).read_bytes():
                    raise ValueError(f"Changed bridge marketplace: {path}; rerun bridge install")
        if self.agent == "claude":
            settings = read_json(self.state / "settings.json")
            if settings.get("enabledPlugins", {}).get("nono@nolabs-ai") is not True:
                raise ValueError("Claude nono plugin disabled; rerun bridge install to enable it")
            return ["--append-system-prompt", self.context()]
        rules = [r for r in self.manifest["wiring"] if r["type"] == "toml_block"]
        if len(rules) != 1:
            raise ValueError("Expected exactly one Codex instruction block")
        block = tomllib.loads(self.source(rules[0]["content"]).read_text())
        config_path = self.state / "config.toml"
        config = tomllib.loads(config_path.read_text()) if config_path.exists() else {}
        user_instructions = config.get("developer_instructions", "")
        if not isinstance(user_instructions, str):
            raise ValueError("developer_instructions must be a string")
        helper_command = "python3 " + shlex.quote(str(self.state / "bin/nono-draft-profile"))
        instructions = block["developer_instructions"].replace(
            "$HOME/.codex/bin/nono-draft-profile", helper_command)
        block = self.expanded(block)
        block["developer_instructions"] = "\n\n".join(filter(None, (
            user_instructions, self.expand(instructions), self.context())))
        def toml_value(value):
            if isinstance(value, dict):
                return "{" + ", ".join(
                    f"{json.dumps(k, ensure_ascii=False)} = {toml_value(v)}"
                    for k, v in value.items()) + "}"
            if isinstance(value, list):
                return "[" + ", ".join(toml_value(v) for v in value) + "]"
            if not isinstance(value, (str, bool, int, float)):
                raise ValueError("Unsupported Codex config value")
            return json.dumps(value, ensure_ascii=False)
        args = []
        for key, value in block.items():
            if not re.fullmatch(r"[A-Za-z0-9_-]+", key):
                raise ValueError(f"Unsupported Codex root config key: {key}")
            if isinstance(value, dict):
                # Codex CLI paths aren't TOML keys; use root inline tables so plugin
                # names with @/dots are parsed as TOML values, preserving user entries.
                value = merge(config.get(key, {}), value)
            args.extend(["--config", f"{key}={toml_value(value)}"])
        return args


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "args", "prepare"))
    parser.add_argument("agent", choices=("codex", "claude"))
    parser.add_argument("--pack-dir", help="Installed signed package root (default: nono config/packages/nolabs-ai/agent)")
    parser.add_argument("--state-dir", help="Dedicated agent home")
    parser.add_argument("--nono-config", help="Nono configuration root")
    args = parser.parse_args()
    try:
        bridge = Bridge(args)
        if args.action == "install":
            with bridge.locked():
                bridge.install()
        else:
            # NUL framing preserves whitespace, newlines and shell metacharacters in fish.
            values = bridge.prepare() if args.action == "prepare" else bridge.arguments()
            sys.stdout.buffer.write(b"".join(value.encode() + b"\0" for value in values))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"{args.agent} nono bridge: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
