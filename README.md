# EndeavourOS Bootstrap & Dotfiles

Automated EndeavourOS installation and configuration system using Ansible. This repository provides a complete, reproducible setup for fresh installations with support for different profiles (developer, gaming) and hardware configurations (AMD/AMD, Intel/Nvidia).

## Features

- **Tag-based installation profiles**: Choose exactly what you need (`dev`, `gaming`, or both)
- **Hardware auto-detection**: Automatically installs correct drivers for AMD, Nvidia, or Intel GPUs
- **Symlinked dotfiles**: All configurations are symlinked from this repo for easy version control
- **Locality of configuration**: Each tool's installation logic lives next to its configuration files
- **Idempotent**: Safe to re-run for updates or fixes
- **Beginner-friendly**: Clear structure with explicit includes for easy understanding

## Quick Start

```bash
# Clone this repository
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles

# Run bootstrap with desired profile(s)
./bootstrap.sh dev              # Developer setup
./bootstrap.sh gaming           # Gaming setup
./bootstrap.sh dev,gaming       # Full setup
```

## What Gets Installed

### Base (Always Installed)

- **Desktop Environment**: KDE Plasma with Wayland support
- **Display Manager**: SDDM
- **Hardware Drivers**: Auto-detected (AMD Mesa, Nvidia proprietary, or Intel)
- **Browser**: Firefox (via Snap)
- **Terminal**: Alacritty
- **Shells**: Fish (default) and Bash
- **Version Control**: Git
- **Terminal Multiplexer**: Tmux
- **System Tools**: base-devel, yay (AUR helper), and essential utilities

### Developer Profile (`dev` tag)

- **Editor**: Neovim with full Lua configuration (lazy.nvim, LSP, Treesitter, etc.)
- **IDE**: Visual Studio Code with common extensions
- **Containers**: Docker & Docker Compose
- **Languages**: Node.js, Python, Rust, Go
- **CLI Tools**: ripgrep, fd, fzf, lazygit, GitHub CLI
- **Additional**: Clipboard support (xclip, wl-clipboard), stylua formatter

### Gaming Profile (`gaming` tag)

- **Game Platform**: Steam with 32-bit library support
- **Compatibility Layer**: Proton GE (via ProtonUp-Qt GUI manager)
- **Game Launcher**: Lutris
- **Wine**: Full Wine stack with dependencies
- **Performance**: GameMode, MangoHud
- **Communication**: Discord
- **Graphics**: Vulkan support and 32-bit graphics libraries

## Project Structure

```
.
├── ansible/
│   ├── roles/
│   │   ├── base/                      # Always-run base system
│   │   │   ├── base.yml              # Entry point
│   │   │   ├── vars.yml              # Variables
│   │   │   └── tasks/
│   │   │       ├── system/           # OS-level tasks
│   │   │       │   ├── update.yml    # System updates, yay installation
│   │   │       │   ├── kde-plasma.yml
│   │   │       │   └── drivers.yml   # Auto-detect hardware
│   │   │       └── tools/            # Common tools
│   │   │           ├── firefox/
│   │   │           ├── alacritty/
│   │   │           │   ├── install.yml
│   │   │           │   └── config/   # ← Actual alacritty.toml
│   │   │           ├── fish/
│   │   │           ├── bash/
│   │   │           ├── git/
│   │   │           └── tmux/
│   │   │
│   │   ├── developer/                 # 'dev' tag
│   │   │   ├── developer.yml
│   │   │   ├── vars.yml
│   │   │   └── tasks/
│   │   │       ├── neovim/
│   │   │       │   ├── install.yml
│   │   │       │   └── config/       # ← Full nvim config
│   │   │       │       ├── init.lua
│   │   │       │       └── lua/...
│   │   │       └── vscode/
│   │   │
│   │   └── gaming/                    # 'gaming' tag
│   │       ├── gaming.yml
│   │       ├── vars.yml
│   │       └── tasks/
│   │           ├── multilib/         # Enable 32-bit repos
│   │           ├── steam/
│   │           ├── proton/
│   │           └── lutris/
│   │
│   ├── playbooks/
│   │   └── site.yml                  # Main orchestrator
│   ├── inventory/
│   │   └── localhost.yml
│   └── ansible.cfg
│
├── bootstrap.sh                       # Entry point script
└── README.md
```

## Design Philosophy

### Locality of Behavior

Each tool's installation logic lives **next to** its configuration files:

```
ansible/roles/base/tasks/tools/tmux/
├── install.yml          # Installs tmux + symlinks config
└── config/
    └── tmux.conf        # Your actual tmux configuration
```

This makes it easy to find and modify everything related to a specific tool in one place.

### Explicit Over Implicit

Unlike standard Ansible roles that use `tasks/main.yml` auto-discovery, this setup uses explicit entry points (`base.yml`, `developer.yml`, `gaming.yml`). This makes the flow clearer for newcomers and easier to understand when reading the code.

### Symlinked Configurations

All dotfiles are **symlinked** from the repository to their target locations (`~/.config/`, `~/.*rc`, etc.). This means:

- Configuration changes are immediately reflected in the system
- You can `git pull` to update configs across all machines
- Changes you make are version-controlled automatically
- No need to manually copy files around

## Usage

### First-Time Setup

```bash
# On a fresh EndeavourOS installation
git clone <your-repo> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh dev,gaming
```

### Update Existing Installation

```bash
# Re-run bootstrap to update packages and configurations
cd ~/dotfiles
git pull                    # Get latest configs
./bootstrap.sh dev,gaming   # Re-apply (idempotent)
```

### Sync Configurations Across Machines

```bash
# Machine 1: Make configuration changes
cd ~/dotfiles
# Edit files in ansible/roles/*/tasks/*/config/
git add -A
git commit -m "Update neovim config"
git push

# Machine 2: Pull changes
cd ~/dotfiles
git pull
# Configs are automatically updated (symlinked!)
```

### Adding New Tools

To add a new tool to the base role:

1. Create directory: `ansible/roles/base/tasks/tools/mytool/`
2. Add `install.yml` with installation + symlinking logic
3. Create `config/` directory with your configuration files
4. Add include statement to `ansible/roles/base/base.yml`

Example:

```yaml
# ansible/roles/base/tasks/tools/mytool/install.yml
---
- name: Install mytool
  pacman:
    name: mytool
    state: present
  become: yes

- name: Symlink mytool config
  file:
    src: "{{ role_path }}/tasks/tools/mytool/config/mytool.conf"
    dest: "{{ ansible_env.HOME }}/.config/mytool/mytool.conf"
    state: link
    force: yes
```

## Hardware Support

The bootstrap automatically detects your GPU and installs appropriate drivers:

- **AMD GPU**: Mesa drivers with Vulkan support
- **Nvidia GPU**: Proprietary drivers with settings utility
- **Intel GPU**: Mesa drivers with hardware acceleration
- **Hybrid systems** (e.g., Intel + Nvidia laptop): Both drivers installed

Detection is done via `lspci | grep -i vga` in `ansible/roles/base/tasks/system/drivers.yml`.

## Customization

### Modify Package Lists

Edit the `vars.yml` file in each role:

- `ansible/roles/base/vars.yml` - Base system packages
- `ansible/roles/developer/vars.yml` - Developer tools, VSCode extensions
- `ansible/roles/gaming/vars.yml` - Gaming packages

### Change Default Shell

Fish is set as the default shell in `ansible/roles/base/tasks/tools/fish/install.yml`. To use Bash instead, comment out the "Set fish as default shell" task.

### Disable Specific Tools

Comment out the include statement in the role's main entry point (`base.yml`, `developer.yml`, or `gaming.yml`).

## Troubleshooting

### Symlink Conflicts

If you have existing dotfiles, the bootstrap will remove them before creating symlinks. Back up important configs before running.

### AUR Package Installation Fails

The script installs `yay` as the AUR helper. If installation fails:

```bash
# Manually install yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Ansible Module Not Found

Ensure the `community.general` collection is installed:

```bash
ansible-galaxy collection install community.general
```

### Permission Errors

The bootstrap will prompt for your sudo password. Ensure your user is in the `wheel` group:

```bash
sudo usermod -aG wheel $USER
```

## Post-Installation Steps

After running the bootstrap:

1. **Reboot** your system for all changes to take effect
2. **Log out and back in** for group changes (Docker, etc.)

### For Developer Setup

- Launch Neovim: `nvim` (lazy.nvim will install plugins automatically)
- Verify Docker: `docker run hello-world`
- Configure Git:
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```

### For Gaming Setup

- Launch Steam: Enable Proton in Settings > Steam Play > Enable Steam Play for all titles
- Install Proton GE: Use ProtonUp-Qt GUI to download and install Proton GE
- Configure MangoHud: Edit `~/.config/MangoHud/MangoHud.conf` if needed

## Contributing

This is a personal dotfiles repository, but feel free to fork and adapt for your own use!

## License

MIT License - Use freely, modify as needed.
