#!/bin/bash

# ============================================================
# This script runs the HeuDiConv tool to convert DICOM files to NIfTI files and organize them into a BIDS structure.
# The script is designed to be run on a SLURM cluster.
# 
# Usage: sbatch heudiconv_script.sh <subject_id_list> <dicom_path_list> <heuristic_file> <output_path>
# 
# Arguments:
#   <subject_id_list> is a list of subject IDs to process, separated by spaces
#   <dicom_path_list> is a list of paths to the DICOM files for each subject, separated by spaces
#   <heuristic_file> is the name of the heuristic file to use (e.g. heuristic.py)
#   <output_path> is the path to the output directory
#
# Notes:
#   <subject_id_list> and <dicom_path_list> should be the same length.
# 
# Example usage: 
#   sbatch --array=0-1 heudiconv_script.sh "01 02" "/path/to/dicom/sub-01 /path/to/dicom/sub-02" heuristic.py /path/to/output
#
# It is assumed that you have a conda environment called 'heudiconv' available (check with 'conda env list'). 
# If not, create a conda environment with the heudiconv and dcm2niix packages installed.
#
# ============================================================

# ------------------------------------------------------------
# Parse the arguments passed to the script
# ------------------------------------------------------------
# The two lists are passed as a single string, so we need to split them into 
# separate arrays using 'Internal Field Separator' (IFS) set to space
# -r prevents backslash escapes from being interpreted
# -a assigns the values to an array
IFS=' ' read -r -a SUBJECT_ID_LIST <<< "$1"
IFS=' ' read -r -a DICOM_PATH_LIST <<< "$2"
# The heuristic file and output path are passed as single strings
HEURISTIC_FILE="${3}"
OUTPUT_PATH="${4}"

# ------------------------------------------------------------
# Get the SLURM job task ID
# ------------------------------------------------------------
task_id=$SLURM_ARRAY_TASK_ID

# ------------------------------------------------------------
# Set the subject ID and DICOM path for this task
# ------------------------------------------------------------
SUBJECT_ID=${SUBJECT_ID_LIST[$task_id]}
DICOM_PATH=${DICOM_PATH_LIST[$task_id]}

# ------------------------------------------------------------
# Print out some information about the script (it will be saved in the SLURM output file)
# ------------------------------------------------------------
echo "Processing subject ${SUBJECT_ID}"
echo "DICOM path: ${DICOM_PATH}"

# ------------------------------------------------------------
# Activate the heudiconv environment
# ------------------------------------------------------------
# This assumes you have a conda environment called heudiconv available (check with 'conda env list'). 
# If not, create one with the heudiconv and dcm2niix packages installed.
conda activate heudiconv

# ------------------------------------------------------------
# Run the heudiconv
# ------------------------------------------------------------
heudiconv \
    --files "${DICOM_PATH}"/* \
    --outdir "${OUTPUT_PATH}" \
    --heuristic "${HEURISTIC_FILE}" \
    --subjects "${SUBJECT_ID}" \
    --converter dcm2niix \
    --bids \
    --overwrite

# ------------------------------------------------------------
# Deactivate the heudiconv environment
# ------------------------------------------------------------
conda deactivate

# ============================================================
# HeudiConv parameters:
# --files: Files or directories containing files to process
# --outdir: Output directory
# --heuristic: Name of a known heuristic or path to the Python script containing heuristic
# --subjects: Subject ID
# --ses: Session ID
# --converter : dicom to nii converter (dcm2niix or none)
# --bids: Flag for output into BIDS structure
# --overwrite: Flag to overwrite existing files
# 
# For a full list of parameters type 'heudiconv --help' in a terminal
#
# ============================================================