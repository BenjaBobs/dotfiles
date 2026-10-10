# Validation

Checked with nono 0.79.0 on 2026-10-10.

- `codex-local`, `claude-local` and `shell-local` resolved from the nested profile
  layout and passed policy dry runs in disposable standard-home fixtures.
- Moving profiles to sibling `base/` and `support/` folders preserved their
  effective permissions apart from the changed inheritance references.
- Launcher fixtures checked sandbox routing, argument preservation, cleanup,
  exit status and failure handling. Codex login commands stayed inside nono;
  Claude's callback listener was granted only to `auth login`.
- Fish functions and the Ansible installation entry point passed syntax checks.

The generic shell has unrestricted networking and disposable state. Agent
profiles retain filtered networking and temporary runtime/cache directories,
while their standard homes remain persistent and writable.

Live agent homes were not inspected or changed: the enclosing nono boundary
reported them as ungranted. The user confirmed that deployment succeeded.
Interactive agent/shell launches and subscription authentication with the
standard homes remain runtime checks.
