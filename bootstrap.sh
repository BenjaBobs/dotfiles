#!/bin/bash
# EndeavourOS Bootstrap Script
# Installs and configures system using Ansible based on specified tags

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

show_help() {
    cat << EOF
${BLUE}===================================
EndeavourOS Bootstrap Script
===================================${NC}

${GREEN}USAGE:${NC}
    ./bootstrap.sh <tags>

${GREEN}TAGS:${NC}
    ${YELLOW}dev${NC}        Install developer tools (neovim, vscode, docker, etc.)
    ${YELLOW}gaming${NC}     Install gaming setup (steam, proton, lutris, etc.)

${GREEN}EXAMPLES:${NC}
    ./bootstrap.sh dev              # Base system + developer tools
    ./bootstrap.sh gaming           # Base system + gaming setup
    ./bootstrap.sh dev,gaming       # Base system + developer + gaming
    ./bootstrap.sh gaming,dev       # Same as above (order doesn't matter)

${GREEN}WHAT GETS INSTALLED:${NC}

    ${BLUE}Base (always installed):${NC}
    - KDE Plasma desktop environment
    - Hardware drivers (auto-detected AMD/Nvidia/Intel)
    - Common tools: Firefox, Alacritty, Fish, Git, Tmux
    - System utilities and configurations

    ${BLUE}Developer tag (dev):${NC}
    - Neovim with full configuration
    - Visual Studio Code
    - Docker & Docker Compose
    - Programming languages: Node.js, Python, Rust, Go
    - CLI tools: ripgrep, fd, fzf, lazygit, gh

    ${BLUE}Gaming tag (gaming):${NC}
    - Steam with multilib support
    - Proton GE (via ProtonUp-Qt)
    - Lutris game launcher
    - Wine, Winetricks
    - GameMode, MangoHud
    - Discord

${GREEN}REQUIREMENTS:${NC}
    - Fresh EndeavourOS installation
    - Internet connection
    - Sudo privileges

${GREEN}NOTES:${NC}
    - All dotfiles are symlinked from this repo
    - Changes to configs are tracked by git
    - Run 'git pull' in this repo to update configs on all machines
    - Safe to re-run to update/fix installations

EOF
}

install_prerequisites() {
    echo -e "${BLUE}Installing prerequisites...${NC}"

    # Update system
    sudo pacman -Syu --needed --noconfirm git ansible

    # Install required Ansible collections
    echo -e "${BLUE}Installing Ansible collections...${NC}"
    ansible-galaxy collection install community.general
}

validate_tags() {
    local tags="$1"
    local valid_tags=("dev" "gaming")

    if [ -z "$tags" ]; then
        return 1
    fi

    # Split tags by comma
    IFS=',' read -ra TAG_ARRAY <<< "$tags"

    for tag in "${TAG_ARRAY[@]}"; do
        # Trim whitespace
        tag=$(echo "$tag" | xargs)

        # Check if tag is valid
        if [[ ! " ${valid_tags[@]} " =~ " ${tag} " ]]; then
            echo -e "${RED}Error: Invalid tag '$tag'${NC}"
            echo -e "${YELLOW}Valid tags: ${valid_tags[*]}${NC}"
            return 1
        fi
    done

    return 0
}

main() {
    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # Check for help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    INSTALL_TAGS="$1"

    # Validate tags
    if ! validate_tags "$INSTALL_TAGS"; then
        echo ""
        echo -e "${YELLOW}Run './bootstrap.sh --help' for usage information${NC}"
        exit 1
    fi

    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}EndeavourOS Bootstrap${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "${BLUE}Installation tags: ${YELLOW}$INSTALL_TAGS${NC}"
    echo -e "${BLUE}Base system: ${YELLOW}always${NC}"
    echo ""
    echo -e "${YELLOW}This will install and configure your system.${NC}"
    echo -e "${YELLOW}You will be prompted for your sudo password.${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi

    # Install prerequisites
    install_prerequisites

    # Change to ansible directory
    cd "$ANSIBLE_DIR"

    # Run Ansible playbook
    echo -e "${BLUE}Running Ansible playbook...${NC}"
    ansible-playbook playbooks/site.yml -e "install_tags=$INSTALL_TAGS" -K

    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Bootstrap complete!${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "${YELLOW}Please reboot your system and log back in.${NC}"
}

main "$@"
