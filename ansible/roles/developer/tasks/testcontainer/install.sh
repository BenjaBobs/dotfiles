#!/usr/bin/env bash
# Run the test container task without the rest of the system bootstrap.
set -euo pipefail

testcontainer_task_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
testcontainer_ansible_dir="$(cd -- "$testcontainer_task_dir/../../../.." && pwd)"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo 'ansible-playbook is required. Install Ansible before running this script.' >&2
    exit 1
fi

testcontainer_playbook="$(mktemp "${TMPDIR:-/tmp}/dotfiles-testcontainer.XXXXXXXX.yml")"
trap 'rm -f -- "$testcontainer_playbook"' EXIT
cat > "$testcontainer_playbook" <<'YAML'
---
- name: Deploy gVisor test containers
  hosts: localhost
  connection: local
  become: false
  tasks:
    - name: Run the test container installation task
      ansible.builtin.import_role:
        name: developer
        tasks_from: testcontainer/install.yml
        vars_from: vars.yml
YAML

export ANSIBLE_CONFIG="$testcontainer_ansible_dir/ansible.cfg"
export ANSIBLE_ROLES_PATH="$testcontainer_ansible_dir/roles"
export ANSIBLE_COLLECTIONS_PATH="$testcontainer_ansible_dir/collections:$HOME/.ansible/collections:/usr/share/ansible/collections"
ansible-playbook --inventory "$testcontainer_ansible_dir/inventory/localhost.yml" \
    --ask-become-pass "$testcontainer_playbook" "$@"
