# Candidate validation

## Ansible deployment

The system bootstrap includes `nono/install.yml` through the developer role.
The bootstrap playbook passed Ansible syntax checks.
The launcher and bridge fixture suites also passed after integration,
and `bootstrap.sh` passed `bash -n`.

Official 0.79.0 Linux archive names and SHA-256 hashes were checked against the
release assets. Deployment pins those hashes and the previously tested signed
package versions, copies configuration with backups, flattens profile names and
refuses conflicting JSON profiles. It preserves existing packages and unrelated
configuration. Authentication remains a manual step outside nono.

A disposable Ansible execution test could not run because the enclosing nono
sandbox denied `/dev/shm`, which Ansible multiprocessing requires. Deployment
idempotence and a real installation therefore remain unverified. No live config,
system packages or agent authentication were changed during implementation.

## Policy validation

Checked on 2026-10-10 with installed nono 0.79.0.
Both shell helpers passed `sh -n`.
Both launchers passed `fish --no-config -n`.
All four JSONC profiles passed named-profile resolution and policy preparation in a temporary XDG configuration root under the assigned `$TMPDIR`.
After extracting the shared Linux base, the Codex dry run produced the same effective capabilities as the earlier two-profile candidate, after normalizing process IDs.
The validation used empty package storage and disposable stand-ins for Codex state and tool caches.
It did not inspect or modify live nono configuration.

The dry run used these arguments:

```text
nono run --dry-run -v --allow-cwd --profile cdx --extends mise-dev -- codex --no-daemon --sandbox danger-full-access -a never
```

The effective policy selected proxy networking and enforced the requested Landlock signal and abstract-socket scopes.
It granted writes to the selected temporary directory, dedicated Codex home, approved working directory and explicit terminal/device/descriptor paths.
It did not grant writes to shared `/tmp`, normal Codex state, host caches or host tool installations.
Host Cargo executables and .NET tools remained read-only, and `/proc` was read-only except for the explicit descriptor grant.
The inherited `/run/systemd/userdb` socket allowance remained present.

This establishes syntax and policy preparation only.
No candidate workload, Codex authentication, environment-filtering probe, clipboard-denial probe or toolchain compatibility test was executed.
Pathname-socket mediation still needs runtime verification for the intended workloads.

## Claude candidate and shared state correction

The Claude candidate passed a dry run with `--profile claude-local --extends mise-dev --allow-cwd` and `/usr/bin/true` as the command stand-in.
The active outer nono sandbox denied reading the installed native Claude binary, so its version and launch behavior could not be checked.
`nono why` identified the ungranted target under `~/.local/share/claude/versions/`.
The candidate adds read-only access to that installation directory, without changing the current session's grants.

The first Claude dry run rejected a writable state directory under `$XDG_STATE_HOME/nono` because that is protected nono runtime state.
Both launchers now select separate homes under `~/.local/state/sandbox-agents/`.
The Claude profile grants `$XDG_STATE_HOME/sandbox-agents/claude`; its launcher selects the same location through `CLAUDE_CONFIG_DIR`.
The corrected Claude dry run selected proxy networking, session-scoped temporary writes and its own persistent state.
It did not grant Codex state or writes to the Claude installation.
The managed configuration path `/etc/claude-code` was absent in this environment and skipped.
The Codex candidate also passed a new dry run with its dedicated home under a disposable `state/sandbox-agents/codex` directory.

Neither subscription login nor a Claude workload was executed.
The CLI launcher does not establish containment of shared background supervisors or IDE-launched sessions.

## Fish command wrappers

The launchers are now autoloadable `codex.fish` and `claude.fish` functions.
Both passed `fish --no-config -n` after the rename.
Each resolves the external agent executable and invokes nono through `command`, avoiding function recursion.
The mock-based checks in `tests/check-launchers.py` passed for both wrappers.
They verified absolute executable routing, argument preservation, exit-status preservation, cleanup, and failure when setup, directory creation or nono is unavailable.
Checks with each agent executable removed from PATH confirmed a single “not installed” message, exit status 127, and no setup, cleanup or nono invocation.
The checks did not execute either real agent or write host state.
No failure case fell back to running the agent directly.
Fish functions can still be bypassed deliberately, or by launch paths outside fish.

## Composable tool support

The Linux policy was split into `agent-linux-base.jsonc` and separate support profiles selected by `agent-linux-local.jsonc`.
The `mise-dev` extension moved from the launch commands into `support-mise.jsonc`.
Dry runs for both concrete agents passed after composition and produced the same effective filesystem, socket and network capabilities as before, after normalizing process IDs.
The checks used disposable state and `/usr/bin/true` as the command stand-in.
Resolved JSON checks confirmed that both agents retained their isolation settings and rollback exclusions.
A temporary profile combining only the base and Python support resolved without the explicit Rust/.NET path grants, while retaining isolation settings.
Cargo and .NET environment allowlists were moved into their respective support files; this version's profile JSON display omits environment filtering, and no runtime environment probe was performed.
Both fish syntax checks and the updated launcher checks passed without the old CLI mise extension.
These checks establish composition and launch routing, not toolchain workload compatibility.

## Access rationale comments

All 14 JSONC profiles now explain their explicit filesystem grants, runtime groups, environment variables and policy choices beside the corresponding entries.
Comments distinguish inherited compatibility grants and supplied paths from demonstrated workload requirements.
Parsed JSON values were compared before and after annotation and were unchanged.
Both concrete profiles also passed nono's named-profile resolution after annotation.

## Profile folders

Agent profiles now live in `profiles/`, shared Linux profiles in `profiles/base/`, and tool support in `profiles/base/support/`.
All 14 profile files were moved without changing their contents.
The installation procedure copies all three source levels into one user profile directory, preserving bare-name inheritance supported by nono 0.79.
Both concrete profiles resolved successfully and passed policy dry runs using that installation layout.
Their effective capabilities matched the previous layout after normalizing process IDs.

## Single Codex profile

The Codex network policy was merged into `profiles/codex-local.jsonc`, and `profiles/cdx.jsonc` was removed.
The wrapper now selects `codex-local` directly.
With the old profile absent from the temporary installation, the merged profile resolved and passed a policy dry run.
The resolved policy matched the previous `cdx` policy except for metadata and the inheritance declaration.
Effective capabilities were unchanged after normalizing process IDs.
The Codex fish syntax check and both launcher checks passed.

## Package bridges for both agents

The shared adapter passed synthetic fixture checks and checks against disposable copies of installed signed `nolabs-ai/codex` `0.2.3` and `nolabs-ai/claude` `0.1.4` packages.
Checks covered relocated plugin/cache wiring, Claude registrations and hook-file links, preservation of unrelated settings, unchanged Codex configuration, idempotent installation and unchanged package bytes.
Generated Codex CLI config values parsed as TOML, including paths with spaces, quotes and dollar signs.
Runtime overrides retained user developer instructions and the enabled package plugin.
The installed Codex helper created a disposable draft extending `codex-local` when invoked through Python.
Missing bridge metadata, changed package wiring and an escaping wiring destination were rejected.
The launcher checks also covered bridge failure, cleanup and preservation of multiline arguments containing shell metacharacters.
Both wrappers passed fish syntax checks.

Both concrete profiles passed nono 0.79 dry runs with the additional writable `profile-drafts` directory.
The temporary setup used a separate session directory for `$TMPDIR` so it did not overlap nono's protected state root.
Installed profiles and packages retain their read-only grants; neither agent policy gained ordinary-home or network access.
No live configuration, ordinary agent home or subscription login was modified.
Real agent plugin discovery and hook execution remain untested.
The inspected environment lacks `jq`, which the upstream Claude hook scripts require.

## Automatic bridge preparation

Both fish wrappers now call `prepare` before entering nono.
Synthetic fixtures and disposable copies of the installed signed packages passed checks for automatic first installation and refresh after wiring changes and package version/cache-path changes.
Three simultaneous preparations produced one installation report and valid NUL-framed arguments for every caller.
An unchanged preparation preserved settings and metadata modification times and produced no refresh report.
Checks confirmed preservation of unrelated settings, refusal of unsupported destinations and conflicting paths, and failure when packages are missing or an unchanged Claude plugin is deliberately disabled.
Both launcher checks and fish syntax checks passed with the new action, retaining failure cleanup and the early absent-agent behavior.
No sandbox profiles or live configuration were changed by this update.
