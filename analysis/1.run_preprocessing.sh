#!/bin/bash

# Run only the preprocess rules
#
snakemake --use-conda --cores all\
    --snakefile "../brieflow/workflow/Snakefile" \
    --configfile "config/config.yml" \
    --rerun-triggers mtime \
    --rerun-incomplete \
    --resources ic_exclusive=100 \
    --default-resources ic_exclusive=1 \
    --set-resources calculate_ic_sbs:ic_exclusive=50 calculate_ic_phenotype:ic_exclusive=100 \
    --until all_preprocess
