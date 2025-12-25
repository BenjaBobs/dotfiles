sudo pacman -Syu --needed git ansible
ansible-galaxy collection install community.general
ansible-playbook ansible/site.yml -K
