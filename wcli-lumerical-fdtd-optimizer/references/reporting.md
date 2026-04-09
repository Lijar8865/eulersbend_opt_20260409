# Reporting Checklist

Generate reports from saved artifacts, not from transient console output.

## Required outputs

- `all_results.csv`
- `best_result_summary.mat`
- `optimization_log.txt`
- `*.md` report
- `*.html` report

## Recommended figures

### Joint sweep heatmap

Use `imagesc` when plotting a 2D joint optimization result.

Recommended styling:

- Put the colorbar outside the axes.
- Use one restrained colormap across related heatmaps.
- Mark the best point with a red star or pentagram marker.
- Keep axes labels and titles consistent.

### Local fine-search heatmap

- Restrict the plot to the local search window.
- Show the refined optimum clearly.
- Use the same colormap family as the coarse heatmap.

### One-dimensional refinement curves

Plot:

- `W_inout` vs objective
- `arc_angle` slice at the best `mk`, when helpful

Annotate the best point or the current optimum.

## Report structure

1. Problem statement and constraints
2. Search strategy
3. Final best result
4. Stage-by-stage summary
5. Figures and trend analysis
6. File links

## Path handling in reports

Avoid placing long absolute paths inside tables.

Prefer:

- Relative links in bullet lists
- Short labels for long folders

## HTML-first recommendation

For stable output across machines:

- Treat Markdown as the source of truth
- Generate HTML alongside Markdown
- Do not assume PDF generation is available or desirable
