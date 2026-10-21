# Nono configuration

The developer role installs nono and deploys these profiles, launcher scripts and fish functions.
Configuration is copied with backups, so editing the checkout does not change installed policy.

```text
config/
├── profiles/
│   ├── codex-local.jsonc
│   ├── claude-local.jsonc
│   ├── shell-local.jsonc
│   ├── base/
│   │   ├── agent-linux-base.jsonc
│   │   ├── agent-linux-local.jsonc
│   │   └── network-whitelist.jsonc
│   └── support/
│       └── support-*.jsonc
├── codex.fish
├── claude.fish
├── sandbox.fish
├── launcher/
└── tests/
```

## Install

Run from the repository root in an ordinary terminal outside nono:

```sh
bash ansible/roles/developer/tasks/nono/install.sh
```

The same task runs through `./bootstrap.sh dev` or `./bootstrap.sh dev,gaming`.
Additional Ansible arguments such as `--check --diff` can be passed to the script.
It installs the checksum-verified nono 0.80.0 binary in `~/.local/bin`, required tools,
and missing signed Codex 0.2.3 / Claude 0.1.4 packages. Existing packages are preserved.
Pins are in the developer role's `vars/vars.yml`; update packages with `nono update`.
The agent executables themselves are installed separately.

Deployment preserves the `base/` and `support/` profile folders. References such as
`base/agent-linux-local` were verified with nono 0.79.0. Conflicting `.json` profiles
must be moved aside before deployment.
`XDG_CONFIG_HOME` is respected; otherwise configuration goes under `~/.config`.

## Agent state and package integrations

The wrappers use the standard `~/.codex` and `~/.claude` directories. Both remain
persistent and writable by their respective agents, including their credentials.
The signed packages register their plugins, instructions and hooks directly in
these homes through `nono pull`. No local package bridge is needed.
Local profiles remain the permission authority; they do not inherit the packages'
agent profiles or run their profile session hooks.

Remove conflicting `codex` / `claude` aliases from fish startup files, and open a
fresh fish shell. `type codex`, `type claude` and `type sandbox` should show functions.

## Authentication

For Codex, select **Sign in with Device Code**, or run:

```sh
codex login --device-auth
```

All Codex commands run inside nono. Credentials use file storage in `~/.codex`,
avoiding desktop keyring access. Device-code login avoids a local callback listener.
It must be enabled in your ChatGPT account or workspace settings.

For Claude, run:

```sh
claude auth login
```

Only this command receives `--listen-port 0` for its dynamically assigned callback.
Open the displayed URL manually if browser opening is blocked. Re-authenticate
through this command rather than `/login` in a regular session. Claude's runtime
sockets stay under the session's `cc-socks` folder; its installation remains
read-only and automatic updates are disabled. Update it outside nono with
`command claude update`.

## Tool support and permissions

[agent-linux-base.jsonc](profiles/base/agent-linux-base.jsonc) defines shared Linux
restrictions. [agent-linux-local.jsonc](profiles/base/agent-linux-local.jsonc) selects
tool support through its `extends` array. Keep `base/agent-linux-base` and select
`support/support-*` fragments for .NET, Rust, Python, Node, Nix, Git, mise, editor
or Stride support as needed. Filesystem grants combine additively; these fragments
select access, rather than restricting which languages can execute.

Launch from the narrow project directory you want writable. Tool installations
remain read-only, while build caches use the launcher-created temporary directory.
The selected tool and Git configuration can itself contain secrets; review its contents.
Codex and Claude have separate filtered network policies. Add web destinations both
agents may reach to [network-whitelist.jsonc](profiles/base/network-whitelist.jsonc);
`allow_domain` entries combine additively across profiles. Do not add `--allow-net`
to their wrappers. Clipboard, Wayland, X11 and desktop-bus access are not granted.

The packages can help diagnose denials and write proposed profiles under
`nono/profile-drafts`. Review and promote drafts outside the sandbox, then restart.
They cannot change the running process's OS permissions.

## Sandboxed shell

`sandbox` opens fish with the shared development-tool support, project write
access and unrestricted networking. It has no agent-home grants. History and
caches are disposable, and fish starts with `--no-config`. `exit` cleans up its
session directory.

## Checks

```sh
fish --no-config -n ansible/roles/developer/tasks/nono/config/codex.fish
fish --no-config -n ansible/roles/developer/tasks/nono/config/claude.fish
fish --no-config -n ansible/roles/developer/tasks/nono/config/sandbox.fish
python3 ansible/roles/developer/tasks/nono/config/tests/check-launchers.py
```

See [validation results](validation.md) for the checks performed and their limits.
