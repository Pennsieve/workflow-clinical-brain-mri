#!/usr/bin/env bash
# Fetches the CC0 sample subjects used by the demo from OpenNeuro (no credentials needed).
# Usage: scripts/fetch-sample-data.sh [dest-dir]   (default: data/sample)
set -euo pipefail
DEST="${1:-data/sample}"
S3="s3://openneuro.org"
cp() { aws s3 cp --no-sign-request --quiet "$1" "$2"; echo "fetched $2"; }
mkdir -p "$DEST/ds000117/sub-01/anat" "$DEST/ds000117/sub-02/anat" "$DEST/ds000221/sub-010200/anat"
cp "$S3/ds000117/sub-01/ses-mri/anat/sub-01_ses-mri_T1w.nii.gz" "$DEST/ds000117/sub-01/anat/sub-01_T1w.nii.gz"
cp "$S3/ds000117/sub-01/ses-mri/anat/sub-01_ses-mri_T1w.json"   "$DEST/ds000117/sub-01/anat/sub-01_T1w.json"
cp "$S3/ds000117/sub-02/ses-mri/anat/sub-02_ses-mri_T1w.nii.gz" "$DEST/ds000117/sub-02/anat/sub-02_T1w.nii.gz"
cp "$S3/ds000221/sub-010200/ses-01/anat/sub-010200_ses-01_acq-mp2rage_T1w.nii.gz"  "$DEST/ds000221/sub-010200/anat/sub-010200_T1w.nii.gz"
cp "$S3/ds000221/sub-010200/ses-01/anat/sub-010200_ses-01_acq-highres_FLAIR.nii.gz" "$DEST/ds000221/sub-010200/anat/sub-010200_FLAIR.nii.gz"
cp "$S3/ds000221/sub-010200/ses-01/anat/sub-010200_ses-01_acq-highres_FLAIR.json"   "$DEST/ds000221/sub-010200/anat/sub-010200_FLAIR.json"
echo "Data: OpenNeuro ds000117 (Wakeman & Henson, CC0) and ds000221 MPI-Leipzig Mind-Brain-Body (CC0). See README.md for citations."
