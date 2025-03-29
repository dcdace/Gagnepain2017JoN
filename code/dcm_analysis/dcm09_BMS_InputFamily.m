% =========================================================================
% DCM Bayesian Model Selection (BMS) for Input Family Comparison
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script performs Bayesian Model Selection (BMS) to compare different 
%   families of DCM models based on their input configurations. It organizes
%   models into three families: HC, DLPFC, and Both.
%
% Outputs:
%   - BMS results saved in the specified directory
%   - BMS results printed as an image
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - Preprocessed DCM models must exist in the specified directory
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm09_BMS_InputFamily; exit;" 
% =========================================================================

% Add SPM to path if not already added
spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found. Please check the path: %s', spmPath);
end
addpath(spmPath);

% Define directories
modelDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/results/DCM/rDLPFC01_rHC300_TNT_model_00_RolandsNeuronSpace_not_center';
saveDir = fullfile(modelDir, 'InputFamily');

% Check if model directory exists
if ~exist(modelDir, 'dir')
    error('Model directory not found: %s', modelDir);
end

% Remove previous BMS results if they exist
if exist(fullfile(saveDir, 'BMS.mat'), 'file')
    fprintf('Removing existing BMS results...\n');
    delete(fullfile(saveDir, 'BMS.mat'));
end

% Create output directory if it doesn't exist
if ~exist(saveDir, 'dir')
    fprintf('Creating output directory: %s\n', saveDir);
    mkdir(saveDir);
end

% Get subject IDs from directories
subjID = cellstr(spm_select('List', modelDir, 'dir', '^sub-'));
if isempty(subjID)
    error('No subject directories found in: %s', modelDir);
end
fprintf('Found %d subjects\n', length(subjID));

% Initialize SPM batch
matlabbatch = {};
matlabbatch{1}.spm.dcm.bms.inference.dir = {saveDir};

% Add DCM models for each subject
fprintf('Loading DCM models for each subject...\n');
for s = 1:length(subjID)
    models = cellstr(spm_select('FPList', fullfile(modelDir, subjID{s}), ['^DCM_' subjID{s} '.*e\.mat$']));
    if isempty(models)
        warning('No DCM models found for subject: %s', subjID{s});
        continue;
    end
    matlabbatch{1}.spm.dcm.bms.inference.sess_dcm{s}.dcmmat = models;
    fprintf('  Subject %s: %d models\n', subjID{s}, length(models));
end

% Configure BMS settings
matlabbatch{1}.spm.dcm.bms.inference.model_sp = {''};
matlabbatch{1}.spm.dcm.bms.inference.load_f = {''};
matlabbatch{1}.spm.dcm.bms.inference.method = 'RFX';  % Random Effects Analysis

% Define model families
fprintf('Setting up model families...\n');

% Family 1: HC
matlabbatch{1}.spm.dcm.bms.inference.family_level.family(1).family_name = 'HC';
matlabbatch{1}.spm.dcm.bms.inference.family_level.family(1).family_models = (1:4)';

% Family 2: DLPFC
matlabbatch{1}.spm.dcm.bms.inference.family_level.family(2).family_name = 'DLPFC';
matlabbatch{1}.spm.dcm.bms.inference.family_level.family(2).family_models = (5:8)';

% Family 3: Both
matlabbatch{1}.spm.dcm.bms.inference.family_level.family(3).family_name = 'Both';
matlabbatch{1}.spm.dcm.bms.inference.family_level.family(3).family_models = (9:12)';

% Perform Bayesian Model Averaging on the winning family
matlabbatch{1}.spm.dcm.bms.inference.bma.bma_yes.bma_famwin = 'famwin';

% Run the SPM batch
fprintf('Running Bayesian Model Selection...\n');
try
    spm_jobman('run', matlabbatch);
    fprintf('BMS completed successfully\n');
    
    % Save results as an image
    cd(saveDir);
    spm_print('input_family', 2, 'jpg');
    fprintf('Results saved to: %s\n', saveDir);
catch ME
    fprintf('Error running BMS: %s\n', ME.message);
    rethrow(ME);
end

fprintf('Analysis complete!\n');