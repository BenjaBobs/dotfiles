# Nono configuration

This directory contains the nono policies and launchers managed by this dotfiles repository.
It also retains the supplied profile's read-only `$HOME/.dotnet/tools` grant.
[agent-linux-base.jsonc](profiles/base/agent-linux-base.jsonc) contains shared Linux restrictions and session-state policy.
[agent-linux-local.jsonc](profiles/base/agent-linux-local.jsonc) selects that base and optional tool support through an `extends` array.
[codex-local.jsonc](profiles/codex-local.jsonc) adds Codex state, authentication URLs and its network policy.
[claude-local.jsonc](profiles/claude-local.jsonc) adds Claude Code's separate subscription state, native installation access and network policy.
[Package bridges](bridges/README.md) retain the upstream Codex and Claude plugins, instructions and hooks inside their dedicated homes.
See [validation results](validation.md) for checks and remaining uncertainties.

```text
ansible/roles/developer/tasks/nono/config/
├── profiles/
│   ├── codex-local.jsonc
│   ├── claude-local.jsonc
│   ├── base/
│   │   ├── agent-linux-base.jsonc
│   │   └── agent-linux-local.jsonc
│   └── support/
│       └── support-*.jsonc
├── codex.fish
├── claude.fish
├── hooks/
├── bridges/
└── tests/
```

## Install

The developer bootstrap (`./bootstrap.sh dev` or `./bootstrap.sh dev,gaming`) installs
nono and deploys these files through the system setup playbook. Run from the repo root:

```sh
./bootstrap.sh dev
```

To deploy only nono using the same installation task:

```sh
bash ansible/roles/developer/tasks/nono/install.sh
```

This also checks dependencies and installs missing signed packages. Replaced
config files are backed up. Run it outside nono; it asks for your sudo password
for package dependencies. Additional Ansible arguments such as `--check --diff`
can be passed to the script.

Run deployment from an ordinary terminal outside nono. The task installs the
checksum-verified official nono 0.79.0 binary into `~/.local/bin`, plus Python,
fish and `jq`. Ensure `~/.local/bin` is on PATH. Missing signed packages are pulled
at the tested Codex 0.2.3 and Claude 0.1.4 versions; existing packages are preserved.
Package pulls also apply upstream wiring to ordinary agent homes. Back up their
settings before the first installation; existing authentication is not copied.
The agent executables themselves are installed separately.

Configuration is copied, with backups of replaced files, rather than symlinked:
editing an agent-writable checkout must not directly change installed policy or
host-side launch helpers. Deploy reviewed changes by rerunning the playbook.
It manages only the named source files, preserving unrelated profiles, packages,
drafts and persistent agent state. Removed source files are not automatically deleted
from the installed configuration; review obsolete installed files separately.
Conflicting `.json` versions of managed `.jsonc` profiles must be moved aside first.
Review old aliases and the obsolete profiles listed below during migration.

Ansible uses `XDG_CONFIG_HOME` when set, otherwise `~/.config`. You can override
`nono_config_home` explicitly with `-e`; use the same value in your fish environment.
Version, checksum and initial package pins live in
`ansible/roles/developer/vars/vars.yml`. Updating the nono version also requires
updating its architecture checksums from the official release. Package updates
remain a separate `nono update` maintenance step; verify profiles and bridges afterward.
Check mode previews configuration tasks but skips binary downloads and package pulls.

### Manual installation

Run these commands from the repository root in an ordinary terminal outside the current nono session.
Back up the existing Codex and Claude profiles, temporary hooks and any fish definitions for `codex`, `claude`, `llm` or `cllm` before replacing them.

```sh
nono_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$nono_config_home/nono/profiles" "$nono_config_home/nono/hooks" "$nono_config_home/nono/bridges" "$nono_config_home/fish/functions"
cp -R ansible/roles/developer/tasks/nono/config/profiles/. "$nono_config_home/nono/profiles/"
cp ansible/roles/developer/tasks/nono/config/hooks/tmp-setup.sh "$nono_config_home/nono/hooks/tmp-setup.sh"
cp ansible/roles/developer/tasks/nono/config/hooks/tmp-cleanup.sh "$nono_config_home/nono/hooks/tmp-cleanup.sh"
cp ansible/roles/developer/tasks/nono/config/bridges/agent-bridge.py "$nono_config_home/nono/bridges/agent-bridge.py"
cp ansible/roles/developer/tasks/nono/config/codex.fish "$nono_config_home/fish/functions/codex.fish"
cp ansible/roles/developer/tasks/nono/config/claude.fish "$nono_config_home/fish/functions/claude.fish"
```

After backing them up, remove obsolete `~/.config/nono/profiles/cdx.json` and `cdx.jsonc` definitions if present.
The Codex wrapper now selects `codex-local` directly.
Remove existing `codex` and `claude` aliases or function definitions from fish startup files so they cannot override the installed wrappers.
Remove the obsolete `llm` and `cllm` aliases and autoload files if you installed the earlier launchers.
The helpers are invoked through `sh` and do not require executable permissions.
Leave registry-managed nono package files unchanged.
Install the relevant signed packages as described in [bridge setup](bridges/INSTALL.md).
The wrappers automatically create or refresh their dedicated-home bridge before entering nono.
The launchers now require the bridges and Python 3.11 or newer whenever their agent executable is present.
Installation preserves `profiles/base/` and `profiles/support/`. Inheritance uses
`base/…` and `support/…` references, verified with nono 0.79.0. Older flat copies
of these fragments are no longer used; review and remove them separately.

On first interactive launch, run `codex` and select **Sign in with Device Code**.
Open the displayed URL in your browser and enter the code. Alternatively, run
`codex login --device-auth`. All Codex commands, including login, run inside nono.
The profile allows HTTPS to `auth.openai.com` for device-code authentication.
Credentials use file storage in `~/.local/state/sandbox-agents/codex`, so no desktop
keyring access is needed. Later launches reuse that login. Device-code login avoids
the browser callback listener and does not require desktop-bus access.
Device-code login must be enabled in your ChatGPT account or workspace settings.
Noninteractive workloads require a saved login.
Transfer intended Codex configuration separately. The launcher does not copy the
normal Codex home's credentials, plugins or history.
This dedicated state remains persistent and writable by the agent.

Start a fresh fish shell after installing the functions.
Launch `codex` or `claude` from the narrow project directory you intend to grant access to.
Do not restore `--allow-net`, which overrides the profile's network filtering in the reviewed version.

## Compose tool support

Edit the `extends` array in [profiles/base/agent-linux-local.jsonc](profiles/base/agent-linux-local.jsonc) to select support shared by both agents.
Keep `base/agent-linux-base` first and add the support profiles needed in that environment.
For example, a Python and .NET environment can use:

```json
"extends": [
  "base/agent-linux-base",
  "support/support-python",
  "support/support-dotnet",
  "support/support-git",
  "support/support-mise"
]
```

The current selection retains all tool support from the earlier configuration.
Each support profile has its own file under [profiles/support/](profiles/support/):

| Profile | Explicit support |
| --- | --- |
| `support-dotnet` | .NET tools, NuGet reads, .NET environment variables and the reviewed read-only `/proc` baseline |
| `support-rust` | Rust toolchain and Cargo executable reads, Cargo credential denials and disposable `CARGO_HOME` |
| `support-python` | Upstream Python runtime group and bytecode rollback exclusion |
| `support-node` | Upstream Node runtime group, pnpm reads and Node build rollback exclusions |
| `support-nix` | Upstream Nix runtime group |
| `support-git` | Upstream Git settings group and shared Git configuration |
| `support-mise` | Upstream `mise-dev` profile, installed mise tools and configuration |
| `support-editor` | Neovim runtime reads |
| `support-stride` | Stride installation reads |

Support profiles are fragments intended to be combined with `agent-linux-base`, rather than used as standalone agent policies.
Nono merges multiple bases from left to right; filesystem grants, environment allowlists and rollback exclusions combine additively.
Removing a support profile removes its explicit contribution, but overlapping system or other profile grants may still make a tool accessible.
This composition selects required access; it is not a language execution allowlist.
Host installations remain read-only and disposable caches remain under the launcher-created temporary directory.
The launchers still prepare Cargo and .NET cache locations, but only selected support profiles admit their environment variables.
Mise is now selected through `support-mise`, with no separate `--extends mise-dev` hidden in the launchers.

To give the agents different tool sets, replace their `extends: "base/agent-linux-local"` with arrays selecting `base/agent-linux-base` and their respective support profiles.
Keep the agent-specific state and network declarations in their existing files.
Preserve the profile directory structure, then inspect the composed result with `nono profile show codex-local --json` or `nono profile show claude-local --json`.
Named user-profile lookup supports these JSONC files in the reviewed version.

## Command names

Fish autoloads these wrappers when you type `codex` or `claude`, including invocations such as `codex --help`.
Each wrapper resolves the actual executable on PATH and passes its absolute path to `command nono run`.
Neither wrapper falls back to an unsandboxed invocation when setup or nono fails.
If the agent executable is absent from PATH, its wrapper prints that it is not installed and returns status 127 without setting up a session.
Check `type codex` and `type claude` in the fresh fish shell to confirm they resolve to the installed functions.
These defaults apply to fish; explicit `command codex`, absolute executable paths, other shells and IDE launches can bypass fish functions.

Validate the wrappers without launching either agent:

```sh
fish --no-config -n ansible/roles/developer/tasks/nono/config/codex.fish
fish --no-config -n ansible/roles/developer/tasks/nono/config/claude.fish
python3 ansible/roles/developer/tasks/nono/config/tests/check-launchers.py
python3 ansible/roles/developer/tasks/nono/config/tests/check-bridges.py
```

## Claude Code subscription setup

The `claude` function uses `~/.local/state/sandbox-agents/claude` as its dedicated `CLAUDE_CONFIG_DIR`.
Claude Code stores settings, plugins and history under that directory, and Linux subscription credentials move there too.
See the official [environment reference](https://code.claude.com/docs/en/env-vars) and [credential storage documentation](https://code.claude.com/docs/en/authentication#credential-management).
Prepare the dedicated login through the installed fish wrapper:

```sh
claude auth login
```

Select your work subscription. This command runs inside nono with a temporary
`--listen-port 0` grant for Claude's dynamically assigned OAuth callback listener.
Regular agent sessions, auth status and logout do not receive this grant.
Claude's runtime sockets use `cc-socks` under the disposable session directory;
the profile grants socket connect/bind only there. The documented
`downloads.claude.ai` service is allowed for plugin executables and version checks.
If automatic browser opening is blocked, open the displayed URL manually.
Re-authenticate with `claude auth login` rather than `/login` inside a regular
agent session, whose callback listener remains restricted.
Transfer the intended work settings explicitly, including company-required integrations; the launcher does not copy your normal Claude configuration.
The candidate retains read access to `/etc/claude-code` for managed configuration, but compliance with your actual company setup has not been verified.
Then launch `claude` from your project in a fresh fish shell.
It retains Claude Code's normal permission behavior and forwards your arguments.
This launcher covers the foreground CLI process and its descendants; background supervisors or IDE launches need separate review.
The official [network documentation](https://code.claude.com/docs/en/network-config#apply-network-settings-to-background-agents) describes background processes that can use a shared supervisor outside a shell wrapper.

The native Claude installation is read-only, and the launcher sets `DISABLE_AUTOUPDATER=1`.
Update Claude Code outside the sandbox, using `command claude update` in fish and following the official [installation documentation](https://code.claude.com/docs/en/setup#auto-updates).
The profile uses nono's `claude-code` network policy, whose destinations may include development services as well as Anthropic.
See [nono network filtering](https://www.nono.sh/network-filtering).
Extra work services, remote MCP endpoints or corporate proxy requirements need specific grants after checking the resolved policy.
Subscription credentials remain readable and writable within the dedicated Claude state; this is not brokered credential custody.

## Verify after installation

Review the effective policy after nono or package updates because `default`, `mise-dev` and the `codex` network profile remain upstream dependencies.
Test environment filtering with dummy exported tokens, rather than real credentials.
Check Wayland, X11 and desktop-bus denial without reading private clipboard contents.
Run representative Cargo, NuGet, .NET runfile, pnpm and Stride tasks before depending on the new setup.
Record specific failures before adding filesystem, socket or network grants.

Deploy installed policy changes outside the agent sandbox. If an agent session
needs additional access, use a one-off `nono run --allow` grant at launch, or
create a profile draft and review it outside the sandbox with `nono profile promote`.
