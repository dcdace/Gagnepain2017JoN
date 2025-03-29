#!/bin/bash

PROJECT_PATH="/imaging/correia/da05/students/mohith/Gagnepain2017JoN"
SCRIPT_PATH="$PROJECT_PATH/code/dcm_analysis/convert_mni_to_native_ROIs.py"
JOB_DIR="$PROJECT_PATH/scratch/mne_to_native_roi_job_logs"

# Which conda environment to use
CONDA_ENV=mri

# Get all subject IDs
SUBJECTS=($(ls -d ${PROJECT_PATH}/data/sub-* | xargs -n 1 basename | sed 's/sub-//'))

# ----------------------------------------------------------
# Do some checks before submitting the job
# ----------------------------------------------------------
echo "Checking if the project directory exists..."
if [ ! -d "$PROJECT_PATH" ]; then
    echo "Project directory does not exist. Exiting..."
    exit 1
fi

echo "Checking if the script exists..."
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Script does not exist. Exiting..."
    exit 1
fi

echo "Checking if the job directory exists..."
if [ ! -d "$JOB_DIR" ]; then
    echo "Job directory does not exist. Creating it..."
    mkdir -p "$JOB_DIR"
fi

echo "Checking if the conda environment exists..."
if ! conda env list | grep -q "$CONDA_ENV"; then
    echo "The conda environment $CONDA_ENV does not exist. Exiting..."
    exit 1
fi

if [ ${#SUBJECTS[@]} -eq 0 ]; then
    echo "No subjects found. Exiting..."
    exit 1
fi

# ----------------------------------------------------------
# Submit jobs
# ----------------------------------------------------------
for sID in "${SUBJECTS[@]}"; do
    sbatch --job-name=roi_conv_"$sID" \
           --output="$JOB_DIR"/"$sID".out \
           --error="$JOB_DIR"/"$sID".err \
           --time=01:00:00 \
           --mem=4G \
           --cpus-per-task=1 \
           --wrap="source /etc/profile && conda activate $CONDA_ENV && python $SCRIPT_PATH $sID"
done
