#!/usr/bin/env bash
# Run the existing nono task without the rest of the system bootstrap.
set -euo pipefail

nono_task_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
nono_ansible_dir="$(cd -- "$nono_task_dir/../../../.." && pwd)"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo 'ansible-playbook is required. Install Ansible before running this script.' >&2
    exit 1
fi

nono_playbook="$(mktemp "${TMPDIR:-/tmp}/dotfiles-nono.XXXXXXXX.yml")"
trap 'rm -f -- "$nono_playbook"' EXIT
cat > "$nono_playbook" <<'YAML'
---
- name: Deploy nono
  hosts: localhost
  connection: local
  become: false
  tasks:
    - name: Run the nono installation task
      ansible.builtin.import_role:
        name: developer
        tasks_from: nono/install.yml
        vars_from: vars.yml
YAML

export ANSIBLE_CONFIG="$nono_ansible_dir/ansible.cfg"
export ANSIBLE_ROLES_PATH="$nono_ansible_dir/roles"
export ANSIBLE_COLLECTIONS_PATH="$nono_ansible_dir/collections:$HOME/.ansible/collections:/usr/share/ansible/collections"
ansible-playbook --inventory "$nono_ansible_dir/inventory/localhost.yml" \
    --ask-become-pass "$nono_playbook" "$@"
