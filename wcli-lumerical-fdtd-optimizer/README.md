# wcli-lumerical-fdtd-optimizer

A Codex skill for optimizing MATLAB-driven Lumerical FDTD workflows built around Wcli geometry helpers and stable `.fsp` / `.lsf` simulation interfaces.

## Included Files

- `SKILL.md`: main skill instructions
- `agents/openai.yaml`: agent configuration
- `references/workspace-adaptation.md`: workspace adaptation checklist
- `references/reporting.md`: reporting checklist

## Purpose

This skill helps:

- inspect a Wcli + Lumerical FDTD workspace safely
- copy and adapt the main MATLAB driver instead of rewriting shared infrastructure
- run smoke tests before large parameter searches
- resume interrupted scans from saved results
- parse monitor metrics from saved MAT files
- generate Markdown and HTML optimization reports
