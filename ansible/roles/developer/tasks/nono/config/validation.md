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

## nono 0.80.0 upgrade

Checked on 2026-10-16 from a live `claude-local` session.

- The session launched with the unchanged profiles.
- 40 and 200 back-to-back connects to a granted pathname Unix socket all
  succeeded. On 0.79.0, connects beyond a burst of five failed with a silent
  `EPERM` (supervisor rate limiter, nolabs-ai/nono#1420, fixed by #2047).
- An ungranted socket (`/run/user/1000/bus`) was still denied with `EACCES`.

The 0.79.0 dry runs and launcher fixtures above were not repeated, and
`codex-local` and `shell-local` were not launched on 0.80.0.
