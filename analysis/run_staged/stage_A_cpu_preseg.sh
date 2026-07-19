#!/bin/bash
# ============================================================================
# GPX4 staged cross-VM run — Stage A: CPU, preprocessing up to (not incl.) segmentation
# ============================================================================
# Activate env + cd to analysis dir before running, OR run from analysis/:
#   source /mnt/miniconda3/bin/activate brieflow_GPX4
#   cd /mnt/brieflow-analysis-GPX4/analysis
#
# RAM serialization: --resources mem_mb=230000 is the global budget (VM has 251 GB).
#   combine_* (tile->well aggregation) are pinned to 130000 each, so 130000*2 >
#   230000 forces exactly ONE combine job at a time while lighter per-tile jobs
#   fill the rest of RAM in parallel. 130000 is a SCHEDULING lever, not a measured
#   allocation — re-measure one combine job's true peak with /usr/bin/time -v and
#   keep the value both above that peak AND > 50% of the global budget.
#
# --notemp keeps ALL pre-seg intermediates (brieflow marks align_sbs / log_filter /
#   compute_standard_deviation / find_peaks / max_filter / apply_ic_field_* as temp());
#   without it the return CPU stage (C) recomputes the whole pre-seg chain.
#
# segment_sbs / segment_phenotype are NOT valid positional targets (they carry
#   wildcards -> WorkflowError). Stage them only via --until / --omit-from on the
#   wildcard-free aggregation targets all_sbs / all_phenotype.
# ============================================================================
set -euo pipefail

SNK="../brieflow/workflow/Snakefile"
CFG="config/config.yml"
MEM_GLOBAL=230000
COMBINE_MEM=130000
DRYRUN="${DRYRUN:--n}"   # default dry-run; call with DRYRUN='' to execute

echo ">>> STAGE A (CPU): SBS + phenotype up to segmentation  [DRYRUN='$DRYRUN']"
snakemake --snakefile "$SNK" --configfile "$CFG" --cores all --notemp \
  --rerun-triggers mtime \
  --resources mem_mb=$MEM_GLOBAL \
  --set-resources \
    combine_reads:mem_mb=$COMBINE_MEM \
    combine_cells:mem_mb=$COMBINE_MEM \
    combine_sbs_info:mem_mb=$COMBINE_MEM \
    combine_phenotype_info:mem_mb=$COMBINE_MEM \
  --omit-from segment_sbs segment_phenotype \
  $DRYRUN \
  -- all_sbs all_phenotype
echo ">>> STAGE A done. Shut down gpx4-cpu, move disk to gpx4-gpu, run Stage B."
