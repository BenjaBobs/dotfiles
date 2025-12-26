# Ansible Bootstrap Configuration

This directory contains the Ansible configuration for bootstrapping EndeavourOS installations. The setup uses explicit, locality-focused architecture designed for maintainability and clarity.

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── localhost.yml        # Local machine inventory
├── playbooks/
│   └── bootstrap.yml        # Main orchestration playbook
└── roles/
    ├── base/                # Always-run base system setup
    │   ├── base.yml        # Role entry point
    │   ├── vars.yml        # Role variables
    │   └── tasks/
    │       ├── system/     # OS-level tasks
    │       │   ├── cleanup.yml
    │       │   ├── update.yml
    │       │   └── drivers.yml
    │       └── tools/      # Common tool installations
    │           └── <tool>/ # One directory per tool
    │               ├── install.yml
    │               └── config/ (optional, for tools with configs)
    │
    ├── developer/           # 'dev' tag setup
    │   ├── developer.yml   # Role entry point
    │   ├── vars.yml        # Role variables
    │   └── tasks/
    │       └── <tool>/     # Dev tools (neovim, vscode, etc.)
    │           ├── install.yml
    │           └── config/ # Tool-specific configuration
    │
    └── gaming/              # 'gaming' tag setup
        ├── gaming.yml      # Role entry point
        ├── vars.yml        # Role variables
        └── tasks/
            └── <component>/ # Gaming components (steam, proton, etc.)
                └── install.yml
```

## Execution Flow

### Entry Point: `bootstrap.sh`
1. Validates tags (dev, gaming)
2. Installs Ansible prerequisites
3. Runs: `ansible-playbook playbooks/bootstrap.yml -e "install_tags=$INSTALL_TAGS" -K`

### Main Playbook: `playbooks/bootstrap.yml`
1. **Pre-tasks**:
   - Display installation plan
   - Verify EndeavourOS/Arch
   - **Verify systemd-boot** (FAILS if not present)

2. **Tasks**:
   - Include `base` role (always)
   - Include `developer` role (if 'dev' tag)
   - Include `gaming` role (if 'gaming' tag)

3. **Post-tasks**:
   - Display completion message

### Base Role Execution: `roles/base/base.yml`
1. Load `vars.yml`
2. System tasks:
   - `cleanup.yml` - Remove unwanted pre-installed software
   - `update.yml` - Install base packages + yay AUR helper
   - `drivers.yml` - Auto-detect GPU, install drivers
3. Tool tasks (one per tool):
   - `tools/<tool>/install.yml` - Install tool and symlink configs
   - Each tool is self-contained in its own directory

## Design Principles

### 1. Locality of Behavior
Each tool's installation logic lives next to its configuration files:

```
roles/<role>/tasks/<tool>/
├── install.yml         # Installation + configuration logic
└── config/             # Tool-specific configuration files
    └── <config-files>
```

**Benefits**:
- Everything for a tool is in one directory
- Easy to find and modify
- Self-contained and portable

### 2. Explicit Over Implicit
- Entry points named explicitly: `base.yml`, `developer.yml`, `gaming.yml` (not `main.yml`)
- Uses `include_tasks` with explicit paths (not auto-discovery)
- Clear execution flow for newcomers

### 3. Symlinked Configurations
Dotfiles are **symlinked** from role directories to system locations:

```yaml
- name: Symlink tmux configuration
  file:
    src: "{{ role_path }}/tasks/tools/tmux/config/tmux.conf"
    dest: "{{ ansible_env.HOME }}/.tmux.conf"
    state: link
    force: yes
```

**Benefits**:
- Git tracks all configuration changes
- `git pull` updates configs across machines
- No manual file copying

### 4. Idempotency
All tasks are safe to re-run:
- Package installations check if already present
- Symlinks use `force: yes` (safe replacement)
- Conditional checks prevent redundant work

## YAML Task Structure

### Required Property Order

**All Ansible tasks MUST follow this property order:**

```yaml
- name: Task description
  when: conditional_expression        # ← Position 2 (if present)
  become: yes                         # ← Position 3 (if present)
  become_user: someuser               # ← Position 4 (if present)
  args:                               # ← Position 5 (if present - module behavior modifiers)
    creates: /path/to/check
    chdir: /some/directory
  environment:                        # ← Position 6 (if present - runtime context)
    PATH: /custom/path
    HOME: /custom/home
  module_name:                        # ← Position 7 (the actual action)
    parameter: value
  register: variable_name             # ← Position 8+ (everything else)
  changed_when: condition             # ← Position 8+
  failed_when: condition              # ← Position 8+
```

### Property Order Rules

1. **`name`** - ALWAYS first (describes what the task does)
2. **`when`** - Conditional execution (if present, always position 2)
3. **`become` / `become_user`** - Privilege escalation (if present, always positions 3-4)
4. **`args`** - Module behavior modifiers (if present, always position 5)
   - Examples: `creates`, `removes`, `chdir`, `executable`
   - Controls HOW Ansible handles the module (idempotency checks, working directory, etc.)
5. **`environment`** - Runtime environment variables (if present, always position 6)
   - Examples: `PATH`, `HOME`, `HTTP_PROXY`
   - Defines the execution CONTEXT for the command
6. **Module call** - The actual action (pacman, file, shell, command, etc.)
7. **Everything else** - register, changed_when, failed_when, tags, etc. (order doesn't matter)

### Examples

**Correct (basic):**
```yaml
- name: Install package
  when: package_needed
  become: yes
  pacman:
    name: foo
    state: present
```

**Correct (with args and environment):**
```yaml
- name: Install tool via cargo
  args:
    creates: "{{ ansible_env.HOME }}/.cargo/bin/tool"
  environment:
    PATH: "{{ ansible_env.HOME }}/.cargo/bin:{{ ansible_env.PATH }}"
  shell: cargo install tool
```

**Wrong:**
```yaml
- name: Install package
  pacman:
    name: foo
    state: present
  become: yes           # ← Wrong! Should be before module
  when: package_needed  # ← Wrong! Should be position 2
```

**Wrong (args/environment after module):**
```yaml
- name: Install tool
  shell: cargo install tool
  args:               # ← Wrong! Should be before shell
    creates: /path
  environment:        # ← Wrong! Should be before shell
    PATH: /custom
```

**Correct (block with when):**
```yaml
- name: Install Nvidia drivers
  when: "'NVIDIA' in gpu_info.stdout"
  block:
    - name: Install drivers
      become: yes
      pacman:
        name: nvidia
```

**Wrong (block with when):**
```yaml
- name: Install Nvidia drivers
  block:
    - name: Install drivers
      become: yes
      pacman:
        name: nvidia
  when: "'NVIDIA' in gpu_info.stdout"  # ← Wrong! Should be after name
```

### Rationale

This ordering makes tasks **scannable**. When reading a task, you immediately see:
1. **What** it does (`name`)
2. **If** it will run (`when`)
3. **Who** runs it (`become`)
4. **Under what conditions** Ansible handles it (`args`)
5. **In what context** it executes (`environment`)
6. **How** it does it (module + parameters)

Reading context (args + environment) before action (module) provides clarity - you understand the constraints and environment before seeing the command itself.

## Hardware-Specific Behavior

### GPU Auto-Detection (`roles/base/tasks/system/drivers.yml`)

**Detection method:**
```yaml
- name: Gather GPU information
  shell: lspci | grep -i vga
  register: gpu_info
```

**Driver installation:**
- **AMD**: Mesa drivers (open source) - no special kernel parameters needed
- **Nvidia**: Proprietary drivers + `nvidia-drm.modeset=1` kernel parameter
  - Adds parameter to `/etc/kernel/cmdline`
  - Runs `reinstall-kernels` to regenerate initramfs via dracut
  - Applies parameters to systemd-boot entries
- **Intel**: Mesa drivers (open source) - no special kernel parameters needed

**Why Nvidia is different:**
- Proprietary drivers require explicit kernel parameter for DRM mode setting
- Needed for Wayland support and proper display manager integration
- AMD/Intel work out-of-box with defaults

## Bootloader Requirements

**This setup requires systemd-boot.** The playbook checks for `/boot/loader/loader.conf` and **fails** if not found.

**For other bootloaders:**
1. Modify bootloader check in `playbooks/bootstrap.yml` (pre-tasks)
2. Update Nvidia kernel parameter handling in `roles/base/tasks/system/drivers.yml`

## Variables

### Base Role (`roles/base/vars.yml`)
- `target_user`: Current user (from `ansible_env.USER`)
- `user_home`: Home directory (from `ansible_env.HOME`)
- `base_packages`: System packages (base-devel, git, curl, etc.)
- `aur_helper`: AUR helper to install (yay)

### Developer Role (`roles/developer/vars.yml`)
- `dev_packages`: Development tools (neovim, nodejs, docker, etc.)
- `vscode_extensions`: VSCode extensions to install

### Gaming Role (`roles/gaming/vars.yml`)
- `gaming_packages`: Gaming packages (steam, gamemode, wine, etc.)
- `gaming_aur_packages`: AUR packages (protonup-qt, lutris, discord)

## Common Patterns

### Installing Packages
```yaml
- name: Install package
  become: yes
  pacman:
    name: package-name
    state: present
```

### Installing from AUR
```yaml
- name: Install AUR package
  become: yes
  become_user: "{{ target_user }}"
  args:
    creates: /usr/bin/package-binary
  shell: yay -S --noconfirm package-name
```

### Symlinking Dotfiles
```yaml
- name: Symlink configuration
  file:
    src: "{{ role_path }}/tasks/tools/mytool/config/myconfig"
    dest: "{{ ansible_env.HOME }}/.config/mytool/myconfig"
    state: link
    force: yes
```

### Conditional Execution
```yaml
- name: Do something conditionally
  when: some_variable.rc == 0
  command: /some/command
```

### Read-Only Checks
```yaml
- name: Check if something exists
  command: which some-binary
  register: binary_check
  changed_when: false  # ← Don't count as "changed"
  failed_when: false   # ← Don't fail if binary not found
```

## Modifying the Setup

### Adding a New Tool to Any Role

1. Create directory: `roles/<role>/tasks/<tool>/`
2. Create `install.yml`:
   ```yaml
   ---
   - name: Install <tool>
     # Use appropriate installation method for the layer
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
3. Create `config/` directory with your configuration files
4. Add include to role entry point (`<role>.yml`):
   ```yaml
   - name: Setup <tool>
     include_tasks: tasks/<tool>/install.yml
   ```

### Adding Packages to Existing Roles

Edit the appropriate `vars.yml` file:
- `roles/base/vars.yml` - Add to `base_packages`
- `roles/developer/vars.yml` - Add to `dev_packages`
- `roles/gaming/vars.yml` - Add to `gaming_packages`

### Removing Unwanted Pre-Installed Software

Edit `roles/base/tasks/system/cleanup.yml`:
```yaml
- name: Remove other unwanted pre-installed software
  become: yes
  pacman:
    name:
      - thunderbird
      - libreoffice-still
      # Add more here
    state: absent
```

## Best Practices

1. **Always read files before editing**: Use the Read tool before Write/Edit
2. **Follow property order**: name → when → become → args → environment → module → everything else
3. **Use `changed_when: false` for checks**: Don't inflate the "changed" count
4. **Use `role_path` for file references**: Makes roles portable
5. **Document complex logic**: Add comments for non-obvious behavior
6. **Test idempotency**: Re-run playbooks to verify no unnecessary changes
7. **Keep roles focused**: Each role has one clear responsibility

## Troubleshooting

### Playbook Fails on Bootloader Check
**Error**: "systemd-boot was NOT detected"
**Solution**: Install EndeavourOS with systemd-boot, or modify bootloader check in `playbooks/bootstrap.yml`

### AUR Package Installation Fails
**Cause**: yay not installed or not working
**Solution**: Check `roles/base/tasks/system/update.yml` - ensure yay installation succeeds

### Symlink Conflicts
**Cause**: Existing dotfiles at target location
**Solution**: Tasks use `force: yes` to replace - but backup first if needed

### Task Shows as "Changed" Every Run
**Cause**: Command/shell module without `changed_when`
**Solution**: Add `changed_when: false` if it's a read-only check

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [EndeavourOS Wiki](https://discovery.endeavouros.com/)
- [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot)
