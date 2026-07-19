# Staged cross-VM run scripts

Three shell scripts that run the GPX4 brieflow screen in three stages across a CPU VM
and a GPU VM, with RAM-serialized tile->well aggregation. See the top of each script for
the full rationale; quick reference below.

## Order of operations

1. **Stage A** (`stage_A_cpu_preseg.sh`) on `gpx4-cpu` — SBS + phenotype preprocessing up
   to (not including) segmentation. `--notemp` keeps the pre-seg intermediates on disk so
   Stage C does not recompute them. Then shut down the CPU VM and move the data disk.
2. **Stage B** (`stage_B_gpu_segmentation.sh`) on `gpx4-gpu` (L4) — segmentation only,
   `gpu` flag ON, `gpu=1` resource so one segment job runs per GPU. Then move the disk back.
3. **Stage C** (`stage_C_cpu_downstream_merge.sh`) on `gpx4-cpu` — everything downstream of
   segmentation, then merge (once notebook 5 has written the `merge:` config + merge_combo.tsv).

## Usage

```bash
source /mnt/miniconda3/bin/activate brieflow_GPX4
cd /mnt/brieflow-analysis-GPX4/analysis
# dry-run first (default):
bash run_staged/stage_A_cpu_preseg.sh
# execute for real:
DRYRUN='' bash run_staged/stage_A_cpu_preseg.sh
```

Each script defaults to `-n` (dry-run). Set `DRYRUN=''` to execute.

## RAM serialization

`--resources mem_mb=230000` is the global budget (CPU VM has 251 GB). The four tile->well
aggregation rules — `combine_reads`, `combine_cells`, `combine_sbs_info` (SBS) and
`combine_phenotype_info` (phenotype) — are pinned to `mem_mb=130000` each via
`--set-resources`. Because `130000 * 2 > 230000`, snakemake runs **exactly one** combine
job at a time while lighter per-tile jobs (align/filter/peaks/segment/extract/call, each a
few GB) fill the remaining RAM in parallel.

`130000` is a **scheduling lever, not a measured allocation**. To calibrate: run one
combine job under `/usr/bin/time -v`, read "Maximum resident set size", and set `mem_mb`
both **above** that true peak **and** **> 50%** of the global budget so serialization holds.

## Profile alternative (recommended for persistence)

Instead of the inline `--set-resources`, the same combine throttle plus per-rule
threads/mem live in `../scaleup/resources_profile/config.yaml`. Invoke with:

```bash
snakemake ... --workflow-profile scaleup/resources_profile --resources mem_mb=230000 ...
```

The profile persists the tuning in one file (no long CLI), and is rule-name-verified.

## Gotchas baked in

- `segment_sbs` / `segment_phenotype` are **not** valid positional targets (they carry
  wildcards -> `WorkflowError`). The scripts stage them via `--until` / `--omit-from` on
  the wildcard-free `all_sbs` / `all_phenotype`.
- The GPU flag is set with `--config 'sbs={"gpu":true}' 'phenotype={"gpu":true}'` (JSON
  dict, deep-merged). The `sbs/gpu=true` slash form is **invalid** in snakemake 8.30.
- No `--use-conda`: the env has zero `conda:` directives; everything runs in the activated
  `brieflow_GPX4` env.
- The SBS<->phenotype merge rules (`fast_alignment`/`merge`/`final_merge`) are separately
  RAM-heavy (16/16/12 GB in the profile). At a 230 GB budget those are < 50% and could
  co-run; raise them in the profile if you want them serialized too.
