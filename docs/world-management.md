# World Management

Multiple world saves coexist on the server's persistent volume under `/mnt/valheim-world/worlds_local/`. Terraform controls which world is active.

## Uploading a new world

Use the upload script to SCP world files directly to the server. The flags depend on which save format the world is in:

```bash
# Valheim 1.0+ — a world is a directory of chunked save files
./scripts/upload-world.sh --world-dir <path-to>/<WorldName> --host <server-ip>

# Pre-1.0 — a world is a flat .db/.fwl pair
./scripts/upload-world.sh --db <path-to>.db --fwl <path-to>.fwl --host <server-ip>
```

For `--world-dir`, the script checks for a `_main.*.fwl2` file to confirm it's a real world directory, and refuses to upload if a world of the same name already exists on the server (to avoid merging stale chunks from a previous upload). For `--db`/`--fwl`, both files must share the same base name (e.g. `Panthera.db` and `Panthera.fwl`) — the script validates this before uploading.

### Where to find world files

Local Valheim world saves are typically at:

- **Linux:** `~/.config/unity3d/IronGate/Valheim/worlds_local/`
- **Windows:** `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local\`

As of Valheim 1.0, each world is a directory named after it (`worlds_local/<WorldName>/`) holding `_main.<n>.db2` (save data), `_main.<n>.fwl2` (metadata), `_main.<n>.chunks`/`.ok`, and many `<region>.chunk` files. Worlds not yet loaded since the 1.0 update may still be the older flat `<WorldName>.db` + `<WorldName>.fwl` pair.

## Switching the active world

The active world is set by `valheim_world_name` in `terraform/main.tf` (line 33). To switch:

1. Change the value in `terraform/main.tf`:
   ```hcl
   valheim_world_name = "NewWorldName"
   ```
2. Open a PR on a `world-switch/<name>` branch
3. Merge to `main` — the deploy writes the new name to `.env` and the container restarts with that world

The previous world's files remain on the volume and can be switched back to at any time.

## Full workflow: adding and activating a new world

1. Upload the world files:
   ```bash
   ./scripts/upload-world.sh --world-dir ~/worlds/Midgard --host 203.0.113.42
   ```
2. Update `terraform/main.tf` to set `valheim_world_name = "Midgard"`
3. Push a PR on a `world-switch/midgard` branch and merge

## Notes

- Uploading a world does **not** activate it — the Terraform deploy does.
- World files on the volume are never deleted by switching. All worlds persist.
- The server must be running and reachable via SSH for the upload script to work.
