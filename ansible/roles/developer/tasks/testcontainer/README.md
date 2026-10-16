# Test containers

`testcontainer` runs test services outside nono under gVisor. Sandboxed agents and
the `sandbox` shell reach them only through a Unix socket directory.

```sh
testcontainer up postgres     # start and wait until it accepts connections
testcontainer down postgres   # stop; data is discarded
testcontainer status
testcontainer logs postgres
```

Run it in an ordinary terminal; it needs podman and the systemd user instance.
Inside nono, connect through `$TESTCONTAINER_SOCKET_DIR/<service>`, for example
Npgsql `Host=$TESTCONTAINER_SOCKET_DIR/postgres;Username=postgres;Database=postgres`.
The postgres container trusts socket connections, so no password is needed.

## Install

Run from the repository root outside nono:

```sh
bash ansible/roles/developer/tasks/testcontainer/install.sh
```

It installs the pinned gVisor release root-owned in `/usr/local/lib/gvisor`, the
script in `~/.local/bin`, the `testcontainer@.service` user unit and one socket
directory per service under `~/.local/state/testcontainers`. Socket directories
must exist before a sandbox starts; nono skips grants for missing paths.

## Isolation

- **gVisor** (`runsc`) runs the container on a user-space kernel under rootless podman.
- **No network**: `--network=none`. Postgres listens only on its socket.
- **Container hardening**: all capabilities dropped, `no-new-privileges`, a read-only
  root filesystem and data on tmpfs. It runs as the image's postgres user.
- **Host sockets**: `host-uds=create` lets the container create its socket on the host
  but not connect to host sockets.
- **Sandbox grants**: [support-testcontainers](../nono/config/profiles/support/support-testcontainers.jsonc)
  grants connect-only access to each service directory.
- **Resource limits**: runsc ignores cgroups, so the unit enforces memory, CPU, task and
  runtime limits.

A postgres superuser can run commands inside the container (`COPY ... FROM PROGRAM`);
the container is the boundary. All sandbox sessions share each service's data.

## Caveats

- The container can create files and symlinks in its socket directory, including links
  to host paths. nono resolves links before checking grants and `testcontainer` clears
  the directory without following them, but host tools outside nono should not follow
  or open anything in these directories.
- Exceeding `MemoryMax` kills the unit. The desktop then reports that the system is low
  on memory, even though only the unit's limit was reached. A client in the middle of a
  query may hang until its own timeout instead of failing immediately.
- After a kill, the old socket stays in the directory; the next `up` removes it.

## Adding a service

Add it to `define_service` and `services` in the script, to `testcontainer_services`
in the role's `vars/vars.yml`, and to the profile's `unix_socket_dir` grants. Only
services that can listen on a Unix socket fit this model.
