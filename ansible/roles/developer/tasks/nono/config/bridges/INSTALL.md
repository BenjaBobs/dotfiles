# Bridge installation and maintenance

Run installation from an ordinary terminal outside nono, after backing up the dedicated agent settings.
Python 3.11 or newer is required.
Install the profiles, launchers and helpers using the [main installation procedure](../README.md#install).
The commands below assume the default `~/.config` configuration root.
For a custom `XDG_CONFIG_HOME`, install the profiles, helpers and bridge under `$XDG_CONFIG_HOME/nono` and use that path in these commands.
Both wrappers and the adapter respect that variable.

Check installed signed packages with `nono list`.
If needed, install the relevant packages through nono's registry verification:

```sh
nono pull nolabs-ai/codex
nono pull nolabs-ai/claude
```

The package manager also applies upstream wiring to ordinary `~/.codex` and `~/.claude` homes.
The bridge adds wiring for the dedicated homes; it does not remove upstream wiring or transfer ordinary-home credentials.
Do not use raw GitHub downloads as production package installation.

The wrappers install the bridge automatically on first launch and refresh it after installed package updates, before starting nono.
After copying the files and installing signed packages, no separate bridge command is required.
To prepare a bridge ahead of first launch or explicitly repair an existing installation, these commands remain available:

```sh
python3 "$HOME/.config/nono/bridges/agent-bridge.py" install codex
python3 "$HOME/.config/nono/bridges/agent-bridge.py" install claude
```

If an existing helper or plugin path conflicts, move it aside after review and rerun installation.
Installation merges the package's Claude registration keys and explicitly enables its plugin, preserving unrelated keys.
Codex instructions and registration are supplied at launch through config overrides, preserving its config file.
Prepare subscription authentication in the dedicated homes using the main setup instructions.
Start a fresh fish shell and launch the relevant agent from the intended project directory.
Confirm the nono plugin appears in the agent's plugin interface and that Claude registers its hooks.

After `nono update`, launch `codex` or `claude` normally; its wrapper refreshes changed package wiring automatically.
The automatic refresh uses the package already on disk and does not perform `nono pull` or `nono update` itself.
Review the effective profiles after updates because built-in runtime groups and network policies remain upstream dependencies.
If upstream introduces unsupported wiring, update the adapter before relying on that integration.
If the bridge is unchanged but you have disabled its Claude plugin or damaged its registration, launch stops rather than silently rewriting that state.
Use the explicit installation commands above after reviewing the issue.

Run the offline checks from the repository root:

```sh
python3 ansible/roles/developer/tasks/nono/config/tests/check-bridges.py
python3 ansible/roles/developer/tasks/nono/config/tests/check-launchers.py
fish --no-config -n ansible/roles/developer/tasks/nono/config/codex.fish
fish --no-config -n ansible/roles/developer/tasks/nono/config/claude.fish
```

To additionally check the installed package layouts in disposable copies, pass their parent directory:

```sh
python3 ansible/roles/developer/tasks/nono/config/tests/check-bridges.py "$HOME/.config/nono/packages/nolabs-ai"
```

These checks do not start real agents or verify subscription authentication.
