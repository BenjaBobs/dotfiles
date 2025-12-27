# Ansible Bootstrap

Structure overview for the Ansible setup used by `bootstrap.sh`.

Layout model:
- Explicit role entry points (`base.yml`, `developer.yml`, `gaming.yml`)
- Tool-local tasks: `roles/<role>/tasks/<tool>/install.yml`
- Tool-local configs: `roles/<role>/tasks/<tool>/config/`
- System tasks live in `roles/<role>/tasks/system/`

Entry points:
- `playbooks/bootstrap.yml` orchestrator
- `inventory/localhost.yml` local target
- `ansible.cfg` defaults

Roles:
- `roles/base` base system + common tools
- `roles/developer` dev tools (tag: `dev`)
- `roles/gaming` gaming stack (tag: `gaming`)

Vars:
- `roles/base/vars/vars.yml`
- `roles/developer/vars/vars.yml`
- `roles/gaming/vars/vars.yml`
