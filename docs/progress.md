# Progress

## 2026-03-17: Remove `WORLD_NAME` GitHub variable, update backup artifact naming

**Branch:** `world-switch/panthera`
**Commit:** `93e49c5` — "Sever the WORLD_NAME thread — carve the realm name into the hearthstone"

### Context

`valheim_world_name` was hardcoded as `"Panthera"` directly in `terraform/main.tf` (commit `2f779c1`), making the `WORLD_NAME` GitHub Actions variable unnecessary. This session cleaned up all references and updated the backup artifact naming strategy.

### New artifact naming pattern

`{prefix}-{short_sha}-{timestamp}` (e.g. `pre-deploy-abc1234-20260317-1430`)

- Short SHA ties the backup to the exact commit/deploy
- Timestamp keeps artifacts human-readable and sortable
- Replaces old pattern that used `world_name` and `run_id`

### Files modified

| File | Change |
|---|---|
| `.github/actions/backup-world/action.yml` | Removed `world_name` input; added metadata capture step (`short_sha`, `timestamp`); updated artifact name pattern |
| `.github/workflows/deploy.yml` | Removed `TF_VAR_valheim_world_name` env var and `world_name` input from backup call |
| `.github/workflows/plan.yml` | Removed `TF_VAR_valheim_world_name` env var |
| `.github/workflows/manual-deploy.yml` | Removed `TF_VAR_valheim_world_name` env var and `world_name` input from backup call |
| `.github/workflows/destroy.yml` | Removed `TF_VAR_valheim_world_name` env var |
| `.github/workflows/backup.yml` | Removed `world_name` input from backup call |
| `terraform/variables.tf` | Removed `valheim_world_name` variable (no longer passed from workflows) |
| `docs/getting-started.md` | Updated `valheim_world_name` description to note it's hardcoded in `main.tf` |
| `scripts/upload-world.sh` | Updated next-steps text to reference `main.tf` instead of GitHub variable |
| `CLAUDE.md` | Updated key variables list and world switching section |
| `docs/github-actions.md` | Removed `WORLD_NAME` row from Variables table |

### Key design decisions

1. **Short SHA via bash expansion**: Composite actions can't use `${{ github.sha }}` substring expressions, so a dedicated metadata step uses `${GITHUB_SHA::7}` bash parameter expansion and writes to `$GITHUB_OUTPUT`.
2. **Module variable preserved**: `modules/valheim-hetzner/variables.tf` still has `valheim_world_name` — it's a module input. Only the root `variables.tf` variable was removed since the root `main.tf` now hardcodes the value.
3. **Intentional remaining references**: `WORLD_NAME` in `scripts/upload-world.sh` (local bash variable) and `cloud-init.yaml` (Terraform template/Docker Compose vars) are correct and expected.

### Verification

- Grep for `vars.WORLD_NAME` in workflows: zero matches
- Grep for `world_name` in `.github/`: zero matches
- `valheim_world_name` confirmed absent from `terraform/variables.tf`
- `terraform/main.tf` hardcodes `valheim_world_name = "Panthera"` (line 33)

### Status

Pushed to `origin/world-switch/panthera`. Ready for PR to `main`.
