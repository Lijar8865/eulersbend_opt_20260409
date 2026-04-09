---
name: wcli-lumerical-fdtd-optimizer
description: Optimize MATLAB-driven Lumerical FDTD simulations in workspaces that use Wcli geometry/helper classes, existing .fsp/.lsf interfaces, and result monitors saved to MAT/CSV files. Use when Codex needs to inspect a new Wcli-based photonics workspace, copy and adapt a driver script instead of editing shared Wcli libraries, run and debug parameter sweeps, resume interrupted scans, extract the best monitor value, and generate Markdown/HTML reports with plots.
---

# Wcli Lumerical FDTD Optimizer

## Overview

Use this skill for Wcli-based MATLAB + Lumerical FDTD projects where the workspace already contains shared geometry helpers such as `Wcli_wg`, `Wcli_poly`, or `Wcli_circuit`, plus an existing `.fsp` / `.lsf` interface that should stay stable.

Default behavior:

- Inspect the current workspace before proposing changes.
- Treat `Wcli_*` MATLAB files and existing `.fsp` / `.lsf` interfaces as shared infrastructure.
- Copy the main driver script and optimize in the copied script unless the user explicitly asks to modify shared files.
- Prefer Linux-safe paths via `fullfile`, `mfilename('fullpath')`, and explicit executable paths.
- Generate `Markdown` and `HTML` reports only. Do not generate PDF unless the user explicitly asks.

Read [references/workspace-adaptation.md](references/workspace-adaptation.md) before changing a new workspace.
Read [references/reporting.md](references/reporting.md) before generating plots or reports.

## Workflow

### 1. Inspect the workspace

Identify:

- The main MATLAB driver script that builds geometry and launches FDTD.
- Shared helper files such as `Wcli_wg.m`, `Wcli_poly.m`, `Wcli_circuit.m`.
- The stable simulation interface files such as `.fsp`, `.lsf`, and MAT handoff files.
- The result monitor and the exact metric to optimize.
- The existing output structure for run folders, MAT files, CSV summaries, and reports.

Use `rg`, `sed`, and MATLAB/terminal inspection to confirm:

- Which files are safe to duplicate and edit.
- Which files must remain untouched.
- How results are stored (`basic.mat`, `T_list`, `T_net`, monitor tables, CSV rows, etc.).

### 2. Copy the driver, do not rewrite the framework

Create a new optimizer-focused script by copying the current main driver. Keep the shared workflow recognizable.

Preserve:

- Existing FDTD object names.
- Existing `.fsp` / `.lsf` interface expectations.
- Existing data handoff fields unless the current workspace clearly requires a change.

Avoid:

- Editing `Wcli_*` shared libraries unless explicitly requested.
- Replacing the user’s existing workflow with a totally new framework.

### 3. Normalize the workspace for Linux execution

When adapting older Windows-era scripts:

- Replace hard-coded backslash paths with `fullfile`.
- Resolve the script folder from `mfilename('fullpath')`.
- Use explicit Lumerical executable paths or a small resolver that searches likely install locations.
- Keep run folders and report folders under the current workspace unless the user asks otherwise.

### 4. Build the optimizer around the workspace’s native data model

Use the current workspace’s own `para` / `fdtd_data` structures instead of inventing a new interface.

Typical structure:

- Create a clean base parameter struct.
- Define the search variables and fixed constraints.
- Generate candidate points.
- Reuse existing valid results when possible.
- For each candidate:
  - Build geometry with the shared Wcli helpers.
  - Launch FDTD through the workspace’s normal runner.
  - Parse the resulting MAT file.
  - Record the target monitor value and auxiliary metrics.

Keep candidate generation generic:

- Single-parameter sweep when the user wants a coarse scan.
- Joint grid search when interactions matter.
- Fine search around the current best point when the coarse scan identifies a promising basin.

### 5. Keep resume/restart behavior explicit

Always support interrupted runs.

The optimizer should:

- Scan existing output folders first.
- Parse any valid results already on disk.
- Skip already-valid points.
- Re-run invalid or incomplete points only when needed.
- Log each stage to a text file.

When a run crosses calendar days, avoid silently switching to a new date directory if the user expects resume behavior. Add an explicit `run_date` or `run_root` option when necessary.

### 6. Parse results from the actual saved files

Do not assume the monitor structure from memory alone. Confirm it in the saved files.

Typical checks:

- Does the MAT file contain `T_list`?
- Which port or monitor index is the real objective?
- Is the objective the center wavelength value, the max over wavelength, an average, or another derived metric?

If the user wants “the best result,” record at minimum:

- Parameter values
- Objective value
- Optional dB value
- Smoothness or secondary metric if needed
- Folder path and source file paths
- Valid/invalid state and failure reason

### 7. Validate with real runs before scaling

Always smoke-test the copied optimizer before launching a large search.

Recommended order:

1. Run one known-good or near-best point.
2. Confirm `basic.mat` and the expected monitor data are produced.
3. Confirm the result parser returns the right target metric.
4. Only then launch the larger search.

If the search later fails:

- Inspect the log.
- Compare a successful point and a failing point.
- Check whether the failing run inherited polluted fields from result structs instead of clean parameter structs.
- Check whether the executable crashed or whether the parser only failed after a successful run.

### 8. Generate Markdown and HTML reports

Produce:

- `all_results.csv`
- `best_result_summary.mat`
- `optimization_log.txt`
- `*.md` report
- `*.html` report
- Plot images referenced by both reports

Keep the report focused on:

- Problem definition and constraints
- Search strategy
- Final best result
- Stage-by-stage best values
- Trend analysis from the actual data
- File links using relative paths when long absolute paths would break layout

Use `imagesc` for 2D sweeps rather than MATLAB `heatmap` when you need full style control.

## Plotting rules

For report-quality figures:

- Prefer `imagesc` + explicit axes styling for 2D optimization maps.
- Put the colorbar outside the plotting area.
- Use clean fonts consistently across titles and axes.
- Mark the best point on joint heatmaps.
- Keep line plots and heatmaps visually consistent.

Avoid overloading tables with long absolute paths. Move file paths into a short “File links” subsection using relative links.

See [references/reporting.md](references/reporting.md) for the detailed plotting and reporting checklist.

## Output contract

Unless the user asks otherwise, keep this output pattern:

- Run folders: `sim*` or `sim_<variant>_*`
- Report folders: `optimization_report*`
- Final report formats: `Markdown` and `HTML`
- Plot files stored beside the report

If the user asks for a reusable report generator, create a separate script that:

- Reads `all_results.csv`
- Reads `best_result_summary.mat`
- Regenerates plots
- Rewrites the `md/html` reports without rerunning FDTD

## References

- [references/workspace-adaptation.md](references/workspace-adaptation.md)
- [references/reporting.md](references/reporting.md)
