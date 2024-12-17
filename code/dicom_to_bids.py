import os
import subprocess

# ------------------------------------------------------------
# Specify the paths
# ------------------------------------------------------------
DICOM_LINK_PATH = "/imaging/camcan/ccrescan/DICOMlinks"
OUTPUT_PATH =     "/imaging/camcan/ccrescan/BIDStest/data"
HEURISTIC_FILE =  "/imaging/camcan/ccrescan/BIDS/code/bids_heuristic_camcan.py"
JOB_OUTPUT_PATH = "/imaging/camcan/ccrescan/BIDStest/work/heudiconv_job_logs"
if not os.path.exists(JOB_OUTPUT_PATH):
    os.makedirs(JOB_OUTPUT_PATH)

# ------------------------------------------------------------
# Function to get subject codes for a specific session
# ------------------------------------------------------------
def get_unique_subject_codes(DICOM_PATH, ses):
    unique_subject_codes = set()
    for dir_name in os.listdir(DICOM_PATH):
        full_path = os.path.join(DICOM_PATH, dir_name)
        if os.path.isdir(full_path) and dir_name.startswith('CC') and f'_{ses}_' in dir_name:
            subject_code = dir_name.split('_')[0]
            unique_subject_codes.add(subject_code)
    return sorted(unique_subject_codes)

# ------------------------------------------------------------
# Function to submit HeuDiConv to sbatch
# ------------------------------------------------------------
def submit_heudiconv_job(DICOM_PATH, subject, ses):
    # Create a SLURM job script for the subject and session
    job_script = f"""#!/bin/bash
#SBATCH --job-name=heudiconv_{subject}_{ses}
#SBATCH --output={JOB_OUTPUT_PATH}/{subject}_{ses}_%j.out
#SBATCH --error={JOB_OUTPUT_PATH}/{subject}_{ses}_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4

conda activate heudiconv

# Run HeuDiConv
heudiconv -d "{DICOM_PATH}/{{subject}}*_{ses}_*/*" \\
          -o {OUTPUT_PATH} \\
          -s {subject} \\
          -ss {ses} \\
          --grouping all \\
          -f {HEURISTIC_FILE} \\
          -c dcm2niix \\
          -b \\
     """

#         --overwrite

    # Write the job script to a temporary file
    job_script_file = os.path.join(
        JOB_OUTPUT_PATH, f"heudiconv_{subject}_{ses}.sh")
    with open(job_script_file, "w") as f:
        f.write(job_script)

    # Submit the job script to SLURM using sbatch
    try:
        subprocess.run(["sbatch", job_script_file], check=True)
        print(f"Submitted job for subject {subject}, session {ses}")

        # After submission, delete the job script
        #os.remove(job_script_file)
        #print(f"Deleted job script: {job_script_file}")

    except subprocess.CalledProcessError as e:
        print(f"Error submitting job for subject {subject}, session {ses}: {e}")


# ------------------------------------------------------------
# Main loop through sessions and subjects
# ------------------------------------------------------------
sessions = ["P2", "P3", "P5"]
##sessions = ["P2", "P5"]
#sessions = ["P2"]

for ses in sessions:
    # Get unique subject codes for the session
    SUBJECT_IDs = get_unique_subject_codes(DICOM_LINK_PATH, ses)

    # Just Frail
    #SUBJECT_IDs = ['CC520076', 'CC520542', 'CC520589', 'CC520669', 'CC520712', 'CC521094', 'CC521167', 'CC612069', 'CC620017', 'CC620321', 'CC620485', 'CC620918', 'CC620967', 'CC621020', 'CC621283', 'CC720718']
    # extra subject
    #SUBJECT_IDs.append('CC220518')
    #subject = "CC520076"
    #subject = "CC220518"
    #subject = SUBJECT_IDs[89]
    #print(subject)
    #SUBJECT_IDs = ['CC120049']
    for subject in SUBJECT_IDs:
        # Submit HeuDiConv job to SLURM
        submit_heudiconv_job(DICOM_LINK_PATH, subject, ses)
