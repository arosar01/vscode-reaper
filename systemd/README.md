# systemd units

A timer and oneshot service for running `vscode-reaper.sh --kill` periodically.

## Files

- `vscode-reaper.service`: runs `/opt/vscode-reaper/vscode-reaper.sh --kill` as a oneshot service.
- `vscode-reaper.timer`: triggers the service five minutes after boot, then five minutes after each service activation, with up to 60 seconds of randomized delay to help prevent multiple hosts from triggering simultaneously.

Enable the timer rather than the service directly. The timer's `WantedBy=timers.target` setting defines its enablement target.

The service expects `vscode-reaper.sh` at:

```text
/opt/vscode-reaper/vscode-reaper.sh
```

Update `ExecStart=` in `vscode-reaper.service` if the script is installed elsewhere.

## Checking status

```bash
# Timer status and next scheduled run
systemctl status vscode-reaper.timer
systemctl list-timers --all vscode-reaper.timer

# Recent service output
journalctl -u vscode-reaper.service -n 50
```

## Notes

- `vscode-reaper.service` is a oneshot service and does not remain running between timer activations. After it completes, its status normally returns to `inactive`.
- See the top-level [README.md](../README.md) for details about the script.
