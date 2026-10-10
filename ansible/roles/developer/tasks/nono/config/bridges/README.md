# Nono package bridges

[agent-bridge.py](agent-bridge.py) relocates the wiring from installed `nolabs-ai/codex` and `nolabs-ai/claude` packages into the launchers' dedicated agent homes.
See [installation and maintenance](INSTALL.md) for the procedure.
The local profiles remain the authority for filesystem, network and environment permissions.
The adapter does not inherit either package's agent policy or execute its profile session hooks.

The shared adapter reads each package's `package.json` wiring declarations, rather than maintaining separate copies of their instructions and hook code.
It maps the package's ordinary agent home into `~/.local/state/sandbox-agents/{codex,claude}`.
It links plugin artifacts and helpers to registry-managed files, copies marketplace declarations, and merges Claude's registration patches.
It leaves the installed signed package files unchanged.
Unsupported wiring types and destinations outside dedicated state or `profile-drafts` cause installation to fail.

| Integration | Package content retained | Local adaptation |
| --- | --- | --- |
| Codex | Nono plugin, skill, developer instructions and draft helper | CLI config overrides register the relocated marketplace and plugin, combine root user developer instructions with upstream instructions, and identify `codex-local` |
| Claude Code | Nono plugin, skill, failure hooks and Bash hooks | Relocated marketplace/cache and JSON registration enable the plugin; an appended system prompt identifies `claude-local` |

Codex's `config.toml` remains unchanged by installation and launch.
Its existing root plugin and marketplace settings are merged into the runtime overrides.
Claude's unrelated permissions, settings, marketplaces and plugins remain in their existing dedicated-home files.
The adapter explicitly enables `nono@nolabs-ai` for both agents.
It supplies exact draft paths and advises a new derived profile name, review and promotion outside the sandbox, and restart commands that retain the dedicated home and wrapper flags.
Codex's installed draft helper is invoked through Python because the inspected installed artifact has mode `0644`.

Both concrete profiles grant write access to `$NONO_CONFIG/profile-drafts` so the package workflow can propose a persistent fix.
Installed profiles and package storage retain their inherited read-only grants.
The bridge grants no access to ordinary agent homes or additional network destinations.
Agent instructions can request a draft, but cannot change the active process's OS capabilities.

Before entering nono, each launcher calls the adapter's `prepare` action.
It installs the bridge on first launch and refreshes it when the installed package version, location or wiring changes.
An unchanged bridge is validated without rewriting its settings or metadata.
Preparation uses a per-agent file lock so simultaneous launches do not race through installation.
Refresh messages go to stderr, keeping generated launch arguments separate.
Missing packages, unsupported wiring, conflicting paths or invalid registrations stop the launch and trigger cleanup.
Preparation uses already installed packages and does not download updates, modify profiles or promote drafts.
An unchanged Claude installation with its nono plugin deliberately disabled still stops until explicitly re-enabled.
They retain the initial executable check, so machines without an agent still get its “not installed” message before any bridge setup.
Explicit user CLI overrides can replace bridge config or prompt settings; the shell functions provide defaults, while nono enforces the selected policy.

The implementation was checked against installed Codex pack `0.2.3` and Claude pack `0.1.4`.
The authoritative layouts are their [Codex manifest](https://github.com/nolabs-ai/nono-packs/blob/main/codex/package.json) and [Claude manifest](https://github.com/nolabs-ai/nono-packs/blob/main/claude/package.json).
Codex's [plugin documentation](https://developers.openai.com/plugins/build/plugins) describes local marketplace/plugin discovery.
The adapter uses root inline TOML tables because the [Codex CLI override implementation](https://github.com/openai/codex/blob/main/codex-rs/config/src/overrides.rs) splits override paths on literal dots.
Claude's [plugin reference](https://code.claude.com/docs/en/plugins-reference) describes automatic discovery of `hooks/hooks.json` and `${CLAUDE_PLUGIN_ROOT}`.
Its [CLI reference](https://code.claude.com/docs/en/cli-reference) documents `--append-system-prompt`.
The upstream Claude hooks also require `jq`; it is absent from the inspected environment, so hook execution remains unverified here.
