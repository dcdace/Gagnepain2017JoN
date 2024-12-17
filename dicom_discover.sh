#!/bin/bash

# Path to the raw DICOM files
DICOM_PATH='/imaging/anderson/archive/users/pg02/Exp1/EmoTNT_fMRI/20_2624_186_A_1'

# Location of the output data (it will be created if it doesn't exist)
OUTPUT_PATH='/imaging/correia/da05/students/mohith/PierreJoN/scratch/dicom_discovery2'

# Subject ID
SUBJECT_ID='186'

# ------------------------------------------------------------
# Run the heudiconv
# ------------------------------------------------------------
heudiconv \
    --files "${DICOM_PATH}"/* \
    --outdir "${OUTPUT_PATH}" \
    --heuristic convertall \
    --subjects "${SUBJECT_ID}" \
    --converter none \
    --bids \
    --overwrite
# ------------------------------------------------------------

# HeudiConv parameters:
# --files: Files or directories containing files to process
# --outdir: Output directory
# --heuristic: Name of a known heuristic or path to the Python script containing heuristic
# --subjects: Subject ID
# --converter : dicom to nii converter (dcm2niix or none)
# --bids: Flag for output into BIDS structure
# --overwrite: Flag to overwrite existing files
# 
# For a full list of parameters, see: https://heudiconv.readthedocs.io/en/latest/usage.html 