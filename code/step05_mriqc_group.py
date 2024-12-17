import os
import sys
import subprocess
import time

#------------------------------------------------------------
# Specify the paths
#------------------------------------------------------------
PROJECT_PATH = "/imaging/correia/da05/students/mohith/Gagnepain2017JoN"

BIDS_PATH = os.path.join(PROJECT_PATH, "data")
OUTPUT_PATH = os.path.join(PROJECT_PATH, "data/derivatives/mriqc")
WORK_PATH = os.path.join(PROJECT_PATH, "scratch/mriqc")

if not os.path.exists(OUTPUT_PATH):
    os.makedirs(OUTPUT_PATH)
if not os.path.exists(WORK_PATH):
    os.makedirs(WORK_PATH)

#------------------------------------------------------------
# Function to submit mriqc to sbatch
#------------------------------------------------------------
def submit_mriqc_group_job(BIDS_PATH, OUTPUT_PATH, WORK_PATH):
    # Create a SLURM job script for the subject
    job_script = f"""#!/bin/bash
#SBATCH --job-name=mriqc_group
#SBATCH --output={WORK_PATH}/mriqc_group_%j.out
#SBATCH --error={WORK_PATH}/mriqc_group_%j.err
#SBATCH --time=7-00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

start=$(date +%s)
date

# Source the module initialization script for bash/zsh 
if [ -f /etc/profile.d/modules.sh ]; then
  . /etc/profile.d/modules.sh
else
  echo "Modules initialization script not found."
  exit 1
fi

# Load the apptainer module
module load apptainer

# Run mriqc
apptainer run \\
    -B {BIDS_PATH}:/data:ro \\
    -B {OUTPUT_PATH}:/out \\
    -B {WORK_PATH}:/work \\
    /imaging/local/software/singularity_images/mriqc/mriqc-22.0.1.simg \\
    /data /out group \\
    --work-dir /work \\
    --float32 \\
    --n_procs 16 --mem_gb 24 --ants-nthreads 16 \\
    --modalities T1w bold \\
    --no-sub

# Unload the apptainer module    
module unload apptainer

# processing end time
end=$(date +%s)
date
echo Time elapsed: "$(TZ=UTC0 printf '%(%H:%M:%S)T\n' $((end - start)))"

    """

    # Write the job script to a temporary file
    job_script_file = os.path.join(
        WORK_PATH, f"mriqc_group.sh")
    with open(job_script_file, "w") as f:
        f.write(job_script)
    
    # Submit the job script to SLURM using sbatch
    try:
        subprocess.run(["sbatch", job_script_file], check=True)

        # After submission, delete the job script
        os.remove(job_script_file)
        print(f"Deleted job script: {job_script_file}")

    except subprocess.CalledProcessError as e:
        print(f"Error submitting")
        

# Submit mriqc job to SLURM
submit_mriqc_group_job(BIDS_PATH, OUTPUT_PATH, WORK_PATH)
    