# Environment Intelligence (development only)

Foundry detects the host and source filesystem when running setup or `make up`.
The host-specific, ignored `compose.override.yaml` only adjusts container UID/GID
and enables optional Chokidar polling for Windows/shared source mounts.
It **never** changes database volumes, APP_KEY, project identity, secrets,
portable `.foundry.json`, or application source.

## Profiles

- `windows-native`: PowerShell on Windows; Windows bind mount; Chokidar polling.
- `wsl-windows-fs`: WSL2 running a project under `/mnt/<drive>/` or a shared filesystem.
- `wsl-native`: WSL2 project on Linux filesystem; native filesystem watcher.
- `linux-native`: native Linux filesystem; dynamic UID/GID and native watchers.
- `linux-shared-fs`: shared filesystem on Linux; polling as a compatibility fallback.
- `macos-native`: macOS PowerShell or POSIX, keep native watcher by default.
- `portable`: unknown POSIX environment, conservative defaults.

`make doctor` displays the detected environment; `make host-config` regenerates
the override without starting Docker. The generated override is identified by
a leading Foundry marker. An unmarked `compose.override.yaml` belongs to the
developer and is never overwritten; use it to maintain intentional overrides.
There is no automated migration of source code from NTFS to WSL ext4.

**Important:** Docker Compose reads an override only when running Compose from
this project root. Scripts detect the host running them, not the computer
hosting a remote Docker daemon. A custom `COMPOSE_FILE` environment can
replace Compose's automatic discovery; include `compose.override.yaml`
explicitly if using it.

Polling can increase CPU consumption. It is intended for unreliable file
change notifications, not as an unconditional performance boost. Vite versions
and watch implementations differ; if a project uses another watcher, configure
it in that project's own override.

## Windows/WSL performance

For best I/O performance with Docker Desktop's WSL2 backend, clone a Linux
container project under `/home/<user>/...` in WSL2 (not `/mnt/c`).
Do not move or remove named Docker volumes to switch profiles. Shut down
old containers and recreate them from the new checkout location. Preserve
local credentials, Laravel APP_KEY and Compose project name.

## Validation

Run `python3 tests/environment-detection.py`, `make doctor`, and
`docker compose config -q`. After moving a project, use `make up`, not
`make start`, to reconcile mounts. Full Windows/WSL performance comparisons
require measurements on the target machine; CI cannot reproduce its disk I/O.
