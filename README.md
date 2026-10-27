# Clinical Brain MRI Volumetrics — a Pennsieve workflow

A real, end-to-end neuroimaging pipeline built from reusable Pennsieve apps. It takes T1-weighted
brain MRI volumes in NIfTI format (optionally with a FLAIR per subject) and produces a volumetric
report a researcher or clinician can read, plus every derived volume as data.

```
             ┌──────────┐    ┌────────────┐    ┌──────────┐    ┌──────────┐
 t1w ──────► │  prep    │ ──►│ synthstrip │ ──►│  ants-n4 │ ──►│ synthseg │──┐
 flair ────► │ (nifti)  │    └────────────┘    └────┬─────┘    └────┬─────┘  │
             └────┬─────┘           │  brain, mask   │ corrected    │ labels  │
                  │ t1w, flair      │                ▼              ▼         │
                  ▼                 │          ┌───────────┐ ◄──────┘         │
             ┌──────────┐           │          │ ants-mni  │                  │
             │  lst-ai  │ (WMH)     │          └─────┬─────┘                  │
             └────┬─────┘           │                │ warped, transforms     │
                  │ lesions         ▼                ▼                        ▼
                  └──────────► ┌──────────────────────────────────────────────┐
                               │            brain-volumetrics (report)        │
                               └──────────────────────────────────────────────┘
```

| Step | App | Tool | What it adds |
|---|---|---|---|
| prep | [processor-nifti-prep](https://github.com/Pennsieve/processor-nifti-prep) | nibabel, dcm2niix | Validates and reorients to RAS, names files by subject and modality, records header and scanner metadata |
| strip | [processor-synthstrip](https://github.com/Pennsieve/processor-synthstrip) | SynthStrip 1.8 | Skull stripping: brain image + mask |
| n4 | [processor-ants-n4](https://github.com/Pennsieve/processor-ants-n4) | ANTs 2.6.5 | Bias-field correction inside the brain mask |
| seg | [processor-synthseg](https://github.com/Pennsieve/processor-synthseg) | SynthSeg 2.0 | Whole-brain segmentation (FreeSurfer labels), structure volumes, QC scores |
| mni | [processor-ants-mni](https://github.com/Pennsieve/processor-ants-mni) | ANTs 2.6.5 + MNI152NLin2009cAsym | Registration to MNI space, warps the label map along, registration Dice |
| wmh | [processor-lst-ai](https://github.com/Pennsieve/processor-lst-ai) | LST-AI 2.0 | White-matter hyperintensity segmentation from T1w + FLAIR (skipped when no FLAIR) |
| report | [processor-brain-volumetrics](https://github.com/Pennsieve/processor-brain-volumetrics) | nilearn, pandas | Per-subject HTML report, ICV-normalised volumes, asymmetry indices, screening flags, cohort tables |

Every step loops over all subjects it finds, so one run processes a cohort. Files are named in
BIDS-derivatives style (`<subject>_desc-brain_T1w.nii.gz`, `<subject>_dseg.nii.gz`, ...) and steps
match each other's files by the subject label, which is everything before the first `_`.

## Workflow interface

The workflow (`workflow/clinical-brain-mri-volumetrics.json`) declares two inputs and six outputs:

| | Id | Bound at run time to |
|---|---|---|
| input | `t1w` | the T1w NIfTI files to process |
| input | `flair` (optional) | FLAIR files, one per subject, for the lesion branch |
| output | `report_out` | the HTML report (default: dataset folder `derivatives/report`) |
| output | `tables_out` | `volumes.csv` and `metrics.json` (default: `derivatives/tables`) |
| output | `segmentation_out` | SynthSeg label maps (default: `derivatives/synthseg`) |
| output | `mni_out` | MNI-space volumes (default: `derivatives/mni`) |
| output | `lesions_out` | WMH masks (default: `derivatives/wmh`) |
| output | `brain_out` | skull-stripped volumes (no default: pick a destination or none) |

Label maps, masks and MNI-space volumes open directly in Pennsieve's NIfTI viewer.

## Platform features it exercises

Linked, named ports with `placement: subfolder`; steps with several outputs; a fan-out/fan-in DAG;
an optional input; a Lambda-capable step next to Fargate steps; a workflow interface bound to data
and destinations when it runs; results that render in the app (NIfTI, HTML, CSV).

## Run it locally (no Pennsieve account needed)

```sh
scripts/fetch-sample-data.sh data/sample            # CC0 subjects from OpenNeuro
scripts/run-local.sh data/sample/ds000221 data/work # whole chain with Docker; prints the report path
SKIP_WMH=1 scripts/run-local.sh data/sample/ds000117 # T1w-only subjects, no lesion branch
```

The runner builds the sibling `processor-*` repos (checked out next to this one) and wires each
step's `INPUT_DIR` from the previous outputs exactly as a compute node does.

## Sample data and credit

The demo dataset in Pennsieve and `scripts/fetch-sample-data.sh` use CC0 data from OpenNeuro:

- **ds000117** — Wakeman DG, Henson RN. A multi-subject, multi-modal human neuroimaging dataset.
  *Sci Data* 2015;2:150001. https://openneuro.org/datasets/ds000117 (T1w, 1 mm MPRAGE).
- **ds000221** — Babayan A, et al. A mind-brain-body dataset of MRI, EEG, cognition, emotion, and
  peripheral physiology in young and old adults. *Sci Data* 2019;6:180308.
  https://openneuro.org/datasets/ds000221 (T1w MP2RAGE + 3D FLAIR).

"This data was obtained from the OpenNeuro database. Its accession number is ds000117 / ds000221."

## Licences of the tools

SynthStrip and SynthSeg come from FreeSurfer (FreeSurfer Software License: research use,
redistribution with notice). ANTs, nibabel, nilearn, dcm2niix and LST-AI are Apache-2.0, BSD or MIT.
Each app's `THIRD_PARTY.md` has the details. The apps' own code is Apache-2.0.
