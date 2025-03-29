# -------------------------------
# Dace Apsvalka, @CBU 2025
# -------------------------------
"""
This script converts ROIs defined in MNI space to native space for a given subject 
in a BIDS-compliant dataset. The transformation is applied using ANTsPy and the 
resulting ROIs are saved in the subject's native space.

Best used with dcm03_MNI_to_Native_ROIs.sh script to process multiple subjects using SLURM.

Usage:
    python convert_mni_to_native_ROIs.py <subject_id>

Arguments:
    <subject_id>: The subject ID (e.g., "01") for which the ROIs will be converted.

Outputs:
    - Converted ROIs in native space saved in the `out_dir` directory under the 
      subject-specific folder.
"""

import sys
import os
from bids.layout import BIDSLayout  # to query BIDS dataset
import nibabel as nib 
import ants

# ----------------------------------------
# Paths and setup
# ----------------------------------------
bids_dir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/data'
first_level_dir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/results/spm_first-level/native/model_01_uNTconcat/'
MNI_ROI_dir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/MNI_ROIs/'
out_dir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/data/derivatives/for-dcm'

rois = ['hc330_Right', 'withinConj_rDLPFC']

# ----------------------------------------
# Get subject ID from command-line argument
# ----------------------------------------
if len(sys.argv) != 2:
    print("Usage: python convert_mni_to_native_ROIs.py <subject_id>")
    sys.exit(1)

sID = sys.argv[1]

print('-' * 30 + f"\nProcessing sub-{sID}\n" + '-' * 30)

# ----------------------------------------
# Set up BIDSLayout
# ----------------------------------------
layout = BIDSLayout(bids_dir, derivatives=True)

# in which image space to warp the roi
space_file = os.path.join(first_level_dir, f'sub-{sID}', 'mask.nii')

if not os.path.exists(space_file):
    print(f"Space file {space_file} does not exist. Skipping sub-{sID}.")
    sys.exit(1)
else:
        print(f"Space file {space_file} exists. Proceeding with sub-{sID}.")

MNI_to_native_xfm_path = layout.get(
    subject=sID,
    datatype='anat',
    extension='h5',
    to='T1w',
    return_type='file'
)
if not MNI_to_native_xfm_path:
    print(f"Transform file for sub-{sID} does not exist. Skipping subject.")
    sys.exit(1)
else:
    print(f"Transform file for sub-{sID} exists. Proceeding with sub-{sID}.")

MNI_to_native_xfm_path = MNI_to_native_xfm_path[0]

# ----------------------------------------
# Loop through ROIs and transform them
# ----------------------------------------
for mni_roi in rois:
    print(f"\n--- Converting {mni_roi} for sub-{sID} ---")
    mni_roi_file = os.path.join(MNI_ROI_dir, f'{mni_roi}.nii')

    if not os.path.exists(mni_roi_file):
        print(f"ROI file {mni_roi_file} does not exist. Skipping {mni_roi}.")
        continue

    # Apply the transformation to the MNI-space ROI
    roi_native_space = ants.apply_transforms(
        fixed=ants.image_read(space_file), 
        moving=ants.image_read(mni_roi_file),
        transformlist=MNI_to_native_xfm_path, 
        interpolator='nearestNeighbor'
    )

    # Convert ants image to nibabel image
    roi_native_space = nib.Nifti1Image(roi_native_space.numpy(), nib.load(space_file).affine)
    
    # Binarize the ROI
    roi_native_space_data = roi_native_space.get_fdata()
    roi_native_space_data[roi_native_space_data > 0] = 1
    roi_native_space = nib.Nifti1Image(roi_native_space_data, roi_native_space.affine)

    # Save the ROI in native space
    subject_out_dir = os.path.join(out_dir, f'sub-{sID}', 'ROIs')
    os.makedirs(subject_out_dir, exist_ok=True)
    roi_native_space_file = os.path.join(subject_out_dir, f'sub-{sID}_desc-{mni_roi}_roi.nii')
    nib.save(roi_native_space, roi_native_space_file)
    print(f"Saved the ROI in native space: {roi_native_space_file}")
