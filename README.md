# Gagnepain et al. (2017) Reanalysis

Starting sripts for reanalysing [Gagnepain et al. (2017)](https://doi.org/10.1523/JNEUROSCI.2732-16.2017).

## Project Structure

- `code/`: Contains all analysis scripts
  - `preprocessing/`: BIDS conversion, MRIQC and fMRIPrep
  - `spm_univariate_analysis/`: SPM first-level and group-level analysis
  - `dcm_analysis/`: Dynamic Causal Modeling analysis example
- `data/`: BIDS-formatted neuroimaging data and their derivatives
- `results/`: Analysis results
- `reports/`: Jupyter notebooks documenting analyses and results
- `scratch/`: Temporary files and logs

## Requirements

- MATLAB with `SPM12` and `MarsBar` toolbox.
- Python with `pybids`, `nibabel`, `nilearn`, and `antspyx` packages.
- Apptainer for containerised analysis.
- High-performance computing environment with SLURM.

## Analysis Pipeline

### 1. Preprocessing

1. **Convert raw DICOM data to BIDS format**
   - Find what DICOM series need to be converted: `code/preprocessing/step01_dicom_discover.sh`
   - Prepare the conversion heuristic in `code/preprocessing/bids_heuristic.py`
   - Convert the data: `code/preprocessing/step02_dicom_to_bids_multiple_subjects.py` (calls `code/preprocessing/heudiconv_script.sh`)

2. **Add missing metadata**
   - Add "TotalReadoutTime" and "EffectiveEchoSpacing" metadata values required for preprocessing but not present in DICOMs: `code/preprocessing/step04_add_missing_metadata.py`

3. **Create the event files**
   - From the source Excel files, fill the BIDS events files: `code/preprocessing/step05_fill_event_files.py`

4. **Inspect data quality**
    - Create subject data quality reports using MRIQC: `code/preprocessing/step06_mriqc.py`
    - Get the group report: `code/preprocessing/step07_mriqc_group.py`

5. **fMRIPrep preprocessing**
   - Perform standard fMRIPrep preprocessing pipeline: `code/preprocessing/step08_fmriprep.py`

### 2. Univariate analysis in SPM
DCM needs subject-level analysis done in SPM, therefore I use SPM here. 

1. **Prepare preprocessed files**
   - Prepares fMRIPrep outputs for SPM analysis: `code/spm_univariate_analysis/step01_prepare_files.m`. The script does the following:
      - Prepares either MNI-space or native-space files; defined by `param.space` parameter. 
      - Unzips the pre-processed BOLD files.
      - Applies spatial smoothing if selected (needed for MNI-space analysis, but not needed for native-space analysis used later in DCM).
      - Loads the BIDS events files and creates SPM-compatible condition .mat files.
      - Creates confounds .mat file from fmriprep confounds .tsv files.

2. **Subject-level analysis**
   - Do the subject-level analysis in either MNI-space or native-space, accounting for missing conditions when creating contrasts: `code/spm_univariate_analysis/step02_spm_first_level.m`. 
   - Native-space analysis is needed for DCM. 
      - Change the `param.saveDir` to save in `native` subfolder
      - `param.space = 'T1w';`
      - `param.bold = 'preproc_bold.nii';`

3. **Group-level analysis**
    - Perform SPM Flexible Factorial ANOVA: `code/spm_univariate_analysis/step03_spm_group_anova.m`
    - Addionally, perform the group-level analysis using Nilearn with non-parametric permutation tests and visualises the results: `reports/Group-Level-Analysis_on_SPM_first-level.ipynb`

### 3. Dynamic Causal Modeling (DCM)
Performs an example DCM analysis. The example uses a model space from [Benoit et al. (2012)](https://doi.org/10.1016/j.neuron.2012.07.025) paper. It looks at rDLPFC-HC coupling modulated by No-Think condition. It has 12 models in the model space. The models are grouped in Input and Modulation families. 

1. **Concatenate multiple functional runs into a single run for DCM model**

    In DCM, we need a continuous time-series data of the whole experiment. Therefore we need to concatenate all individual runs into a single run. This requires creating new onset files and performing new subject-level analysis on this 'single-run' data. This requires the subject-level analysis results in native-space performed in the step 2.2. above. 

    - Create new onset files concatenated across runs: `code/dcm_analysis/dcm01_create_onsets_uNT.m`
      - Removes all conditions with onsets that are less than 24s before the end of each run, apart from the last run. The removed conditions will be added to Nuisance condition. 
      - Combines all **inputs** into a single condition **'u'** and leave the **modulatory condition** separate. For example, instead of the original conditions T, NT, there will be these conditions instead: u, NT, where u contains both T and NT.

    - Subject-level analysis on concatenated runs: `code/dcm_analysis/dcm02_concatenated_1stlevel.m`
      - Uses the onset file created in the previous step.
      - Concatenates first-level design matrices. 
      - Because SPM is set up to deal with each run as a continuous timeseries, but when sesions are concatenated that is not the case anymore, the following is done:
        - Auto correlation is turned off
        - High-pass filtering is turned off
        - As an alternative filtering, sines and cosines of up to three cycles per run, to capture low-frequency drifts, are added as regressors : `code/dcm_analysis/functions/createNuisanceParameter_noConstant.m`
      - The step also includes `spm_fmri_concatenate` function which adds constant regressors for each original session and correct temporal non-sphericity calculations to account for the original session lengths.
      - F-contrast for effects of interest is created as well. 

2. **Create VOIs for DCM**

    Volumes of Interest (VOIs) represent brain regions or clusters of voxels that serve as nodes in the DCM. VOIs are typically identified based on activation peaks from previous univariate analyses or defined using anatomical landmarks. Time-series data extracted from these VOIs serve as inputs for DCM analyses. To obtain these time-series, we first need to define our regions of interest (ROIs), select voxels within those ROIs, and then create the VOIs. 
    In this example, In this example, I am using two ROIs defined in MNI space:  
    - **Right DLPFC**, previously used in [Apšvalka et al. (2022)](https://www.nature.com/articles/s41467-021-27926-w);  
    - **Right hippocampus**, defined from hand-traced hippocampi of 330 subjects from 10 TNT studies ("mega-TNT").  

    Because the DCM analysis is performed in the subject's native space, the MNI-space ROIs must first be warped into each subject's native space. From these transformed ROIs, I am selecting the top 10% of voxels most involved in the experiment, based on the Effects-of-Interest (EOI) contrast computed during the subject-level analysis in the previous step. However, this is just one possible strategy for voxel selection; other approaches include defining contiguous "growing ROIs," selecting voxels based on alternative contrasts, or creating spherical VOIs around peak activations. Some thresholding, based on contrasts, can be done also in the next, VOI-timeseries-extraction, step. In this step, the created subject ROIs and the concatenated subject-level results are used to get eigenvalues. 
    The three steps then are:

      - Warp MNI ROIs into subject's native space: `code/dcm_analysis/dcm03_MNI_to_Native_ROIs.sh` (calling `code/dcm_analysis/convert_mni_to_native_ROIs.py`).
      - Select top 10% of voxels based on EOF contrast: `code/dcm_analysis/dcm04_create_TopVoxels_ROI.m`
      - Extract timeseries from VOIs for DCM analysis from the ROI masks for each subject: `code/dcm_analysis/dcm05_create_VOIs.m`

3. **Create DCM model space**

    For this example, I have already created the model space with 12 models - `resources/DCM_model_spaces/DLPFC_HC_RolandsNeuronSpace`.  
    It contains a configurations of intrinsic connections (A), modulatory effects (B), and driving inputs (C).
    The order of ROIs and Conditions is important! In the example model space it is assumed to be:  

      - ROIs: rDLPFC, Hippocampus  
      - Conditions: u, NT

4. **DCM model specification and estimation**

      - Specify the models: `code/dcm_analysis/dcm06_specify_models.m`
      - Estimate the models: `code/dcm_analysis/dcm07_estimate_models.m` (Once the model has been estimated, a letter 'e' will be added to the file name.)

5. **Bayesian Model Selection and parameter estimates**

    - Bayesian Model Selection (BMS) on all DCM models: `code/dcm_analysis/dcm08_BMS.m`. It runs a random effects analysis and performs Bayesian Model Averaging (BMA) across all models returning exceedance probability for each model.
    - BMS on Input families: `code/dcm_analysis/dcm09_BMS_InputFamily.m`
    - BMS on Modulation families: `code/dcm_analysis/dcm10_ModulationFamily.m`
    - Parameter estimates of BMA: `code/dcm_analysis/dcm11_parameter_estimates.m`

