% =========================================================================
% DCM Bayesian Model Selection (BMS) for All Models
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script performs Bayesian Model Selection (BMS) on all DCM models. It runs a random effects analysis
%   and performs Bayesian Model Averaging across all models.
%
% Outputs:
%   - BMS results saved in the specified directory
%   - BMS results as an image
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - Preprocessed DCM models must exist in the specified directory
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm08_BMS; exit;"
% =========================================================================

% Add SPM to path
spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found. Please check the path: %s', spmPath);
end
addpath(spmPath);

% Define directories
modelDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/results/DCM/rDLPFC01_rHC300_TNT_model_00_RolandsNeuronSpace_not_center';
saveDir = fullfile(modelDir, 'All');

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
matlabbatch{1}.spm.dcm.bms.inference.bma.bma_yes.bma_all = 'famwin';
matlabbatch{1}.spm.dcm.bms.inference.verify_id = 1;

% Run the SPM batch
fprintf('Running Bayesian Model Selection...\n');
try
    spm_jobman('run', matlabbatch);
    fprintf('BMS completed successfully\n');
    
    % Save results as an image
    cd(saveDir);
    spm_print('models', 1, 'jpg');
    fprintf('Results saved to: %s\n', saveDir);
catch ME
    fprintf('Error running BMS: %s\n', ME.message);
    rethrow(ME);
end

fprintf('Analysis complete!\n');