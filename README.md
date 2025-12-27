# EndeavourOS Bootstrap & Dotfiles

Setup my dotfiles on a fresh EndeavourOS install with KDE and systemd-boot.

Assumptions:
- EndeavourOS with KDE Plasma
- systemd-boot

Quick start:
```bash
git clone https://github.com/BenjaBobs/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh dev,gaming
```

Quick overview:
- `bootstrap.sh` entry point
- `ansible/playbooks/bootstrap.yml` orchestrator
- `ansible/roles/base` base system + common tools
- `ansible/roles/developer` dev tools (tagged)
- `ansible/roles/gaming` gaming tools (tagged)

Tags:
- `dev` developer tools
- `gaming` gaming stack

Package layers:
- System layer: pacman/AUR (drivers, system libs, core tools), updated together
- Tool layer: user-space custom installs (e.g. mise-managed tools/runtime or similar that need to be able to be updated individually and run fast)
- Application layer: Flatpak (GUI apps)

## Project Structure

Repo layout (abstract):
- Roles are explicit entry points (`base.yml`, `developer.yml`, `gaming.yml`).
- Each tool lives in `roles/<role>/tasks/<tool>/` with `install.yml` and optional `config/`.
- Configs are symlinked from this repo into `~/.config` and `~/.*`.

```java
.
├── bootstrap.sh // Entry point script
├── README.md // This file
│
└── ansible/
    │
    ├── ansible.cfg // Ansible configuration
    │
    ├── playbooks/
    │   └── bootstrap.yml // Main orchestrator
    │
    ├── inventory/
    │   └── localhost.yml // tells ansible to run on localhost
    │
    └── roles/
        ├── base/ // Always-run base system
        │   ├── base.yml // Role entry point
        │   ├── vars.yml // Role variables
        │   └── tasks/
        │       ├── system/ // OS-level tasks
        │       │   ├── remove_bloat.yml // Remove unwanted packages
        │       │   ├── install_base_packages.yml // Install base packages + AUR helper
        │       │   └── gpu_drivers.yml // Auto-detect and install GPU drivers
        │       │
        │       └── tools/ // Common tools (always installed)
        │           └── <tool>/ // One directory per tool
        │               ├── install.yml
        │               └── config/ // Tool-specific configs, often sym-linked
        │
        ├── developer/ // 'dev' tag
        │   ├── developer.yml // Role entry point
        │   ├── vars.yml // Role variables
        │   └── tasks/
        │       └── <tool>/ // Dev tools
        │           ├── install.yml
        │           └── config/ // Tool-specific configs, often sym-linked
        │
        └── gaming/ // 'gaming' tag
            ├── gaming.yml // Role entry point
            ├── vars.yml // Role variables
            └── tasks/
                └── <component>/ // Gaming components
                    └── install.yml
```

