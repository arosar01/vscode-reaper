# vscode-reaper

`vscode-reaper` finds and terminates VS Code Remote-SSH and Cursor remote server processes.

VS Code Remote-SSH and Cursor install persistent server components (`.vscode-server` and `.cursor-server`) on the remote host. These processes can accumulate across sessions and consume CPU, memory, and filesystem resources on shared infrastructure.

## What it does

`vscode-reaper.sh` scans the local process table for configured remote-server markers, skips processes owned by excluded users, and either reports or terminates what it finds.

- **Report mode** (no args): prints matching processes and takes no action.
- **Kill mode** (`--kill`): sends `SIGKILL` to matching processes, with no graceful shutdown. Must run as root.

Kill mode is not scoped to a single user; it terminates any matching process on the host except users listed in `EXCLUDE_USERS`. Multiple passes help catch matching processes that are recreated during the same cleanup run.

## Usage

Report matching processes:

```bash
./vscode-reaper.sh
```

Terminate matching processes:

```bash
sudo ./vscode-reaper.sh --kill
```

## Configuration

Process markers and excluded users are defined near the top of the script:

```bash
PATTERNS=(
  '[.]vscode-server'
  '[.]cursor-server'
)
EXCLUDE_USERS=(
  root
)
```

Add a new remote editor marker to `PATTERNS`. Add a user whose processes should be left alone to `EXCLUDE_USERS`.

These can also be overridden at runtime with environment variables:

| Variable | Default | Description |
|---|---|---|
| `KILL_PASSES` | `3` | Number of scan-and-kill passes in kill mode |
| `SLEEP_SECONDS` | `2` | Delay between passes |
| `PAT` | built from `PATTERNS` | Override the process-matching regular expression directly |
| `EXCLUDE_RE` | built from `EXCLUDE_USERS` | Override the user-exclusion regular expression directly |

```bash
sudo env KILL_PASSES=5 SLEEP_SECONDS=1 \
  ./vscode-reaper.sh --kill
```

Run the script in report mode after changing patterns or exclusions, to confirm the expected matches before running `--kill`.

## How matching works

The script reads the process table with:

```bash
ps ww -eo pid=,ppid=,user:32=,args=
```

and filters it with `awk`:

- Excludes its own PID and its parent process.
- Excludes any user matching `EXCLUDE_RE`.
- Matches the full process record, including command-line arguments, against `PAT`.

`PATH` is hardcoded to a fixed set of system directories at the top of the script, so it does not depend on the caller's environment.

Each kill pass re-scans the process table from scratch rather than tracking PIDs from the first scan, so newly created matching processes can also be terminated in a later pass.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Completed normally, including when no processes matched |
| `1` | `--kill` was requested without root privileges |
| `2` | The first argument was neither empty nor `--kill` |

Individual `kill` command failures are not treated as fatal, and there is no verification pass after the last kill pass. Run the script again in report mode to confirm no matching processes remain.

## Scheduled execution

vscode-reaper.sh can be scheduled with cron, systemd, or any other job runner. Example systemd service and timer units are included under [`systemd/`](systemd/). UBC Advanced Research Computing deploys the script using a systemd oneshot service and timer.

See [`systemd/README.md`](systemd/README.md) for details.

## Maintainer
 
[University of British Columbia Advanced Research Computing (UBC ARC)](https://arc.ubc.ca)
