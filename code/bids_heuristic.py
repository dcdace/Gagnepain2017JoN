# Heuristic for converting DICOMs to BIDS using heudiconv
# This file is used by heudiconv to convert DICOMs to BIDS format.
# It is called by heudiconv using the -f (or --heuristic) flag, e.g.:
# heudiconv -d /path/to/dicoms/{subject}/*/*/*.dcm -s 001 -f bids_heuristic.py -c dcm2niix -b -o /path/to/bids
# 
# see https://heudiconv.readthedocs.io/en/latest/heuristics.html

# --------------------------------------------------------------------------------------
# create_key: A common helper function used to create the conversion key in infotodict. 
# But it is not used directly by HeuDiConv.
# --------------------------------------------------------------------------------------
def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes
# --------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------
# infotodict: A function to assist in creating the dictionary, and to be used inside heudiconv.
# This is a required function for heudiconv to run.
#
# seqinfo is a record of DICOM's passed in by heudiconv. Each item in seqinfo contains DICOM metadata 
# that can be used to isolate the series, and assign it to a conversion key.

# --------------------------------------------------------------------------------------
def infotodict(seqinfo):

    # Specify the conversion template for each series following the BIDS format.
    # See https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/01-magnetic-resonance-imaging-data.html
    
    # The structural/anatomical scan
    anat = create_key('sub-{subject}/anat/sub-{subject}_T1w')
    
    # The fieldmap scans
    fmap_mag = create_key('sub-{subject}/fmap/sub-{subject}_acq-func_magnitude')
    fmap_phase = create_key('sub-{subject}/fmap/sub-{subject}_acq-func_phasediff')
    
    # The functional scans
    # You need to specify the task name in the filename. It must be a single string of letters WITHOUT spaces, underscores, or dashes!
    
    # func_task_practice = create_key('sub-{subject}/func/sub-{subject}_task-practicetnt_run-{item:02d}_bold') # Don't need this             
    # func_task_cueing = create_key('sub-{subject}/func/sub-{subject}_task-cueing_run-{item:02d}_bold') # uncomment if needed
    
    func_task_tnt = create_key('sub-{subject}/func/sub-{subject}_task-tnt_run-{item:02d}_bold')   
    
    # Create the dictionary that will be returned by this function.
    info = {
        anat: [], 
        fmap_mag: [], 
        fmap_phase: [],
        # func_task_practice: [],
        # func_task_cueing: [],
        func_task_tnt: []
        }

    # Loop through all the DICOM series and assign them to the appropriate conversion key.
    for s in seqinfo:
        # Uniquelly identify each series
        
        # Structural
        if "mprage" in s.series_id:
            info[anat].append(s.series_id)
            
        # Field map Magnitude (the fieldmap with the largest dim3 is the magnitude, the other is the phase)
        if 'field_mapping' in s.series_id and s.series_files == 62:
            info[fmap_mag].append(s.series_id)
            
        # Field map PhaseDiff
        if 'field_mapping' in s.series_id and s.series_files == 31:
            info[fmap_phase].append(s.series_id)

        # # Functional practice
        # if 'PractTNT' in s.series_id:
        #     info[func_task_practice].append(s.series_id)
            
        # # Functional Cueing
        # if 'Cueing' in s.series_id and s.dim4 > 100 and 'MoCo' not in s.series_description:
        #     info[func_task_cueing].append(s.series_id)
        
        # Functional TNT
        if '-TNT' in s.series_id and s.dim4 > 100 and 'MoCo' not in s.series_description:
            info[func_task_tnt].append(s.series_id)
        
            
    # Return the dictionary
    return info

# --------------------------------------------------------------------------------------
# Dictionary to specify options to populate the 'IntendedFor' field of the fmap jsons.
#
# See https://heudiconv.readthedocs.io/en/latest/heuristics.html#populate-intended-for-opts
#
# If POPULATE_INTENDED_FOR_OPTS is not present in the heuristic file, IntendedFor will not be populated automatically.
# --------------------------------------------------------------------------------------
POPULATE_INTENDED_FOR_OPTS = {
    'matching_parameters': ['ModalityAcquisitionLabel'],
    'criterion': 'Closest'
}
# 'ModalityAcquisitionLabel': it checks for what modality (anat, func, dwi) each fmap is 
# intended by checking the _acq- label in the fmap filename and finding corresponding 
# modalities (e.g. _acq-fmri, _acq-bold and _acq-func will be matched with the func modality)