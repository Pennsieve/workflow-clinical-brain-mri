#!/usr/bin/env bash
# Runs the whole Clinical Brain MRI Volumetrics chain locally with Docker, the way the
# compute node would: every step gets INPUT_DIR assembled from the linked outputs of the
# steps before it (INPUT_DIR/<input>/ -> OUTPUT_DIR/<output>/ of the source), and writes
# to its own OUTPUT_DIR. No Pennsieve account needed.
#
# Usage: scripts/run-local.sh <input-dir-with-nifti-files> [work-dir]
#   The sibling repos processor-* must be checked out next to this one (../processor-<name>)
#   or set IMAGE_PREFIX to use already-built images named <prefix>/processor-<name>.
set -euo pipefail
IN="$(cd "$1" && pwd)"; WORK="$(mkdir -p "${2:-data/work}" && cd "${2:-data/work}" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${PLATFORM:-linux/amd64}"
IMAGE_PREFIX="${IMAGE_PREFIX:-clinical-brain-mri}"
SKIP_WMH="${SKIP_WMH:-0}"

build() { # build <repo>
  local repo="$1" dir="$ROOT/../$1"
  if [ -d "$dir" ]; then docker build --platform "$PLATFORM" -q -t "$IMAGE_PREFIX/$repo" "$dir" >/dev/null; echo "built $IMAGE_PREFIX/$repo"; fi
}
link_input() { # link_input <step> <input-name> <source-step> <source-output>   (subfolder placement)
  local dst="$WORK/$1/input/$2" src="$WORK/$3/output/$4"
  mkdir -p "$dst"; [ -d "$src" ] && cp -R "$src/." "$dst/" || true
}
run_step() { # run_step <step> <repo> [ENV=VAL ...]
  local step="$1" repo="$2"; shift 2
  local envs=(); for e in "$@"; do envs+=(-e "$e"); done
  mkdir -p "$WORK/$step/input" "$WORK/$step/output"
  echo "== $step ($repo)"; local t0=$(date +%s)
  docker run --rm --platform "$PLATFORM" -u 1000:1000 \
    -v "$WORK/$step/input:/data/input:ro" -v "$WORK/$step/output:/data/output" \
    -e INPUT_DIR=/data/input -e OUTPUT_DIR=/data/output ${envs[@]+"${envs[@]}"} "$IMAGE_PREFIX/$repo" \
    2>&1 | tee "$WORK/$step/log.txt" | sed 's/^/   /'
  echo "   done in $(( $(date +%s) - t0 ))s"
}

for r in processor-nifti-prep processor-synthstrip processor-ants-n4 processor-synthseg processor-ants-mni processor-lst-ai processor-brain-volumetrics; do build "$r"; done

# prep: everything the user selected, at the root (unlinked data sources merge at the root)
rm -rf "$WORK/prep"; mkdir -p "$WORK/prep/input"; cp -R "$IN/." "$WORK/prep/input/"
run_step prep processor-nifti-prep

# strip: single input at the root, from prep's t1w output
rm -rf "$WORK/strip"; mkdir -p "$WORK/strip/input"; cp -R "$WORK/prep/output/t1w/." "$WORK/strip/input/"
run_step strip processor-synthstrip THREADS=4

rm -rf "$WORK/n4"; link_input n4 image strip brain; link_input n4 mask strip mask
run_step n4 processor-ants-n4 THREADS=4

rm -rf "$WORK/seg"; mkdir -p "$WORK/seg/input"; cp -R "$WORK/n4/output/corrected/." "$WORK/seg/input/"
run_step seg processor-synthseg THREADS=4

rm -rf "$WORK/mni"; link_input mni image n4 corrected; link_input mni labels seg labels
run_step mni processor-ants-mni THREADS=4 TRANSFORM_TYPE="${TRANSFORM_TYPE:-s}"

if [ "$SKIP_WMH" != "1" ]; then
  rm -rf "$WORK/wmh"; link_input wmh t1w prep t1w; link_input wmh flair prep flair
  run_step wmh processor-lst-ai THREADS=4
fi

rm -rf "$WORK/report"
link_input report volumes seg volumes; link_input report qc seg qc; link_input report labels seg labels
link_input report brain strip brain;   link_input report mask strip mask
link_input report warped mni warped;   link_input report transforms mni transforms
[ "$SKIP_WMH" != "1" ] && { link_input report lesions wmh lesions; link_input report lesion-volumes wmh lesion-volumes; }
link_input report metadata prep metadata
run_step report processor-brain-volumetrics
echo; echo "Report: $WORK/report/output/report/index.html"
