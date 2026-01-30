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

# Disable colors if terminal doesn't support them
if [ ! -t 1 ] || [ "$TERM" = "dumb" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

show_help() {
    printf "${BLUE}===================================\n"
    printf "EndeavourOS Bootstrap Script\n"
    printf "===================================${NC}\n\n"

    printf "${GREEN}USAGE:${NC}\n"
    printf "    ./bootstrap.sh <tags>\n\n"

    printf "${GREEN}TAGS:${NC}\n"
    printf "    ${YELLOW}dev${NC}        Install developer tools (neovim, vscode, docker, etc.)\n"
    printf "    ${YELLOW}gaming${NC}     Install gaming setup (steam, proton, lutris, etc.)\n\n"

    printf "${GREEN}EXAMPLES:${NC}\n"
    printf "    ./bootstrap.sh dev              # Base system + developer tools\n"
    printf "    ./bootstrap.sh gaming           # Base system + gaming setup\n"
    printf "    ./bootstrap.sh dev,gaming       # Base system + developer + gaming\n"
    printf "    ./bootstrap.sh gaming,dev       # Same as above (order doesn't matter)\n\n"

    printf "${GREEN}WHAT GETS INSTALLED:${NC}\n\n"

    printf "    ${BLUE}Base (always installed):${NC}\n"
    printf "    - Hardware drivers (auto-detected AMD/Nvidia/Intel)\n"
    printf "    - Common tools: Vivaldi (Flatpak), Ghostty, Fish, Git, Tmux, Mise\n"
    printf "    - System utilities and configurations\n"
    printf "    - Cleanup: Removes Firefox and other unwanted pre-installed software\n\n"

    printf "    ${BLUE}Developer tag (dev):${NC}\n"
    printf "    - Neovim with full configuration\n"
    printf "    - Visual Studio Code\n"
    printf "    - Podman & podman-compose\n"
    printf "    - Programming languages managed via mise (Node.js, Python, Go, etc.)\n"
    printf "    - CLI tools: ripgrep, fd, fzf, lazygit, gh\n\n"

    printf "    ${BLUE}Gaming tag (gaming):${NC}\n"
    printf "    - Steam with multilib support\n"
    printf "    - Proton GE (via ProtonUp-Qt)\n"
    printf "    - Lutris game launcher\n"
    printf "    - Wine, Winetricks\n"
    printf "    - GameMode, MangoHud\n"
    printf "    - Discord\n\n"

    printf "${GREEN}REQUIREMENTS:${NC}\n"
    printf "    - Fresh EndeavourOS installation\n"
    printf "    - Internet connection\n"
    printf "    - Sudo privileges\n\n"

    printf "${GREEN}NOTES:${NC}\n"
    printf "    - All dotfiles are symlinked from this repo\n\n"
}

install_prerequisites() {
    echo -e "${BLUE}Installing prerequisites...${NC}"

    # Update system
    sudo pacman -Syu --needed --noconfirm git ansible

    # Install required Ansible collections
    echo -e "${BLUE}Installing Ansible collections...${NC}"
    ansible-galaxy collection install -r "$ANSIBLE_DIR/collection_requirements.yml" -p "$ANSIBLE_DIR/collections" --force
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

    # Prompt for sudo once and keep it alive during bootstrap
    sudo -v
    while true; do sudo -v; sleep 60; done & SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID' EXIT

    # Install prerequisites
    install_prerequisites

    # Change to ansible directory
    cd "$ANSIBLE_DIR"

    # Run Ansible playbook
    echo -e "${BLUE}Running Ansible playbook...${NC}"
    ansible-playbook playbooks/bootstrap.yml -e "install_tags=$INSTALL_TAGS"

    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Bootstrap complete!${NC}"
    echo -e "${GREEN}====================================${NC}"
}

main "$@"
