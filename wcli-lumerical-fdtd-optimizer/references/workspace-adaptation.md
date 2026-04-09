# Workspace Adaptation Checklist

Use this checklist when moving the workflow to a new workspace.

## Inspect first

- Identify the main MATLAB entry script.
- Identify shared `Wcli_*` files.
- Identify the `.fsp` and `.lsf` files used by the current workspace.
- Confirm how the workspace saves results and which monitor is the objective.

## Decide what is editable

- Safe by default: copied main driver script, copied report generator, new helper script in the same workspace.
- Not safe by default: `Wcli_wg.m`, `Wcli_poly.m`, `Wcli_circuit.m`, shared `.fsp`, shared `.lsf`.

## Linux normalization

- Use `mfilename('fullpath')` to find the current script folder.
- Use `fullfile` for paths.
- Use explicit Lumerical executable resolution.
- Keep outputs local to the current workspace.

## Search design

- Coarse scan when you need the large-scale trend.
- Fine scan around the best basin after the coarse scan.
- Resume from disk instead of restarting from zero.

## Failure diagnosis

When a resumed fine search fails unexpectedly:

- Check whether the candidate `para` struct was polluted with result fields.
- Compare a failed candidate’s `matlab2fdtd_data.mat` against a manually reproduced clean point.
- Distinguish:
  - FDTD executable crash
  - Missing output file
  - Parse failure after a successful run

## General rule

The skill should adapt to the workspace’s current `Wcli` implementation, not freeze assumptions from an older workspace.
