# EndeavourOS Bootstrap & Dotfiles

Automated EndeavourOS installation and configuration system using Ansible. This repository provides a complete, reproducible setup for fresh installations with support for different profiles (developer, gaming) and hardware configurations (AMD/AMD, Intel/Nvidia).

## Features

- **Tag-based installation profiles**: Choose exactly what you need (`dev`, `gaming`, or both)
- **Three-layer package management**: System, Application, and Tool layers with different update strategies
- **Hardware auto-detection**: Automatically installs correct drivers for AMD, Nvidia, or Intel GPUs
- **Bootloader detection**: Validates systemd-boot installation before proceeding
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

## Package Management Strategy

This bootstrap uses a **three-layer architecture** for package management, balancing system integration, isolation, and independent updates.

### **System Layer** (pacman/AUR)

**Purpose**: Foundation packages that are integral to the Linux installation.

**Install Method**: `pacman` / `yay` (AUR helper)

**Update Method**: `yay -Syu` (system-wide updates)

**Location**: `/usr` (system-wide)

**What belongs here:**
- **Drivers**: GPU drivers (Mesa, Nvidia), hardware support
- **System libraries**: Vulkan, Wine, multilib packages
- **Core utilities**: base-devel, git, curl, wget
- **Development dependencies**: Rust toolchain, build tools
- **Gaming infrastructure**: GameMode, MangoHud, Steam (system integration)

**Philosophy**: These packages update together as a cohesive system. They provide the foundation that everything else builds on.

### **Application Layer** (Flatpak)

**Purpose**: End-user GUI applications that benefit from isolation.

**Install Method**: `flatpak install`

**Update Method**: `flatpak update`

**Location**: `/var/lib/flatpak` (sandboxed)

**What belongs here:**
- **Browsers**: Vivaldi, Firefox, Chrome
- **Communication**: Discord, Slack, Signal
- **Media**: Spotify, VLC
- **Office**: LibreOffice (if needed)
- **Any Electron apps**: VS Code could go here (currently AUR)

**Philosophy**: Isolated applications with independent update cycles. Slight performance trade-off for stability and security. Desktop integration is good with Flatpak (better than Snap).

### **Tool Layer** (User-space)

**Purpose**: CLI tools and development utilities that need fast updates and self-management.

**Install Method**: Cargo, manual binaries, language package managers

**Update Method**: Tool-specific (`mise self-update`, `cargo install --force`)

**Location**: `~/.cargo/bin`, `~/.local/bin` (user-space)

**What belongs here:**
- **Development tools**: Mise (runtime manager)
- **Terminal emulator**: Alacritty (Rust, Cargo-installed)
- **CLI utilities**: ripgrep, fd, bat (if using self-update)
- **Fast-changing tools**: Things you want latest features of immediately

**Philosophy**: Tools outside package manager control. Enables self-update features without version conflicts. No root required. User maintains control over versions.

### **Why Three Layers?**

**System Layer**: You want drivers and system libraries to update together (compatibility).

**Application Layer**: You want browsers and apps isolated and independently updatable (security, stability).

**Tool Layer**: You want CLI tools to self-update without waiting for AUR packages or system updates (velocity, features).

### **Update Workflow**

```bash
# Weekly/monthly: Update everything
yay -Syu              # System layer
flatpak update        # Application layer
mise self-update      # Tool layer (as needed)

# Daily: Just tools you're actively developing with
mise self-update
cargo install --force alacritty  # If new version available
```

**Key insight**: Each layer updates at its natural cadence without interfering with the others.

## What Gets Installed

### Base (Always Installed)

- **Cleanup**: Removes Firefox and other unwanted pre-installed software
- **Hardware Drivers**: Auto-detected (AMD Mesa, Nvidia proprietary, or Intel)
- **Browser**: Vivaldi (via Snap)
- **Terminal**: Alacritty
- **Shell**: Fish (default)
- **Version Control**: Git
- **Terminal Multiplexer**: Tmux
- **Runtime Manager**: Mise (manages Node.js, Python, Ruby, etc. versions)
- **System Tools**: base-devel, yay (AUR helper), and essential utilities
- **Note**: System updates are NOT automated - you manage updates manually
- **Note**: KDE Plasma is pre-installed by EOS and not modified by this bootstrap

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
│   │   │   ├── base.yml              # Role entry point
│   │   │   ├── vars.yml              # Role variables
│   │   │   └── tasks/
│   │   │       ├── system/           # OS-level tasks
│   │   │       │   ├── cleanup.yml   # Remove unwanted packages
│   │   │       │   ├── update.yml    # Install base packages + AUR helper
│   │   │       │   └── drivers.yml   # Auto-detect and install GPU drivers
│   │   │       └── tools/            # Common tools (always installed)
│   │   │           └── <tool>/       # One directory per tool
│   │   │               ├── install.yml
│   │   │               └── config/   # (optional) Tool-specific configs
│   │   │
│   │   ├── developer/                 # 'dev' tag
│   │   │   ├── developer.yml         # Role entry point
│   │   │   ├── vars.yml              # Role variables
│   │   │   └── tasks/
│   │   │       └── <tool>/           # Dev tools
│   │   │           ├── install.yml
│   │   │           └── config/       # (optional) Tool configs
│   │   │
│   │   └── gaming/                    # 'gaming' tag
│   │       ├── gaming.yml            # Role entry point
│   │       ├── vars.yml              # Role variables
│   │       └── tasks/
│   │           └── <component>/      # Gaming components
│   │               └── install.yml
│   │
│   ├── playbooks/
│   │   └── bootstrap.yml             # Main orchestrator
│   ├── inventory/
│   │   └── localhost.yml             # Local machine definition
│   └── ansible.cfg                   # Ansible configuration
│
├── bootstrap.sh                       # Entry point script
└── README.md                          # This file
```

## Design Philosophy

### Locality of Behavior

Each tool's installation logic lives **next to** its configuration files:

```
roles/<role>/tasks/<tool>/
├── install.yml          # Installation + configuration logic
└── config/              # Tool-specific configuration files
    └── <config-files>
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
# Edit configuration files in role directories
git add -A
git commit -m "Update configuration"
git push

# Machine 2: Pull changes
cd ~/dotfiles
git pull
# Configs are automatically updated (symlinked!)
```

### Adding New Tools

To add a new tool to any role:

1. Create directory: `roles/<role>/tasks/<tool>/`
2. Add `install.yml` with installation + configuration logic
3. Create `config/` directory with tool configuration files (if needed)
4. Add include statement to role's entry point

Example:

```yaml
# roles/<role>/tasks/<tool>/install.yml
---
- name: Install <tool>
  # Choose installation method based on layer:
  # System layer: pacman/yay
  # Application layer: flatpak
  # Tool layer: cargo/manual
  become: yes
  pacman:
    name: <tool>
    state: present

- name: Symlink <tool> configuration
  file:
    src: "{{ role_path }}/tasks/<tool>/config/<config-file>"
    dest: "{{ ansible_env.HOME }}/.config/<tool>/<config-file>"
    state: link
    force: yes
```

## Hardware Support

The bootstrap automatically detects your GPU and installs appropriate drivers:

- **AMD GPU**: Mesa drivers with Vulkan support
- **Nvidia GPU**: Proprietary drivers with settings utility + systemd-boot kernel parameters
- **Intel GPU**: Mesa drivers with hardware acceleration
- **Hybrid systems** (e.g., Intel + Nvidia laptop): Both drivers installed

Detection is done via `lspci | grep -i vga` in `ansible/roles/base/tasks/system/drivers.yml`.

## Bootloader Requirements

This bootstrap is **configured for systemd-boot**. The playbook will check for systemd-boot before executing and abort if not detected.

- **Expected**: `/boot/loader/loader.conf` must exist
- **Nvidia configuration**: Kernel parameters are added via `/etc/kernel/cmdline` and applied with `reinstall-kernels`

If you use a different bootloader (GRUB, rEFInd, etc.), you'll need to modify the bootloader check in `ansible/playbooks/bootstrap.yml` and the Nvidia configuration in `ansible/roles/base/tasks/system/drivers.yml`.

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
