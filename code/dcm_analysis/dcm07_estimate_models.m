% =========================================================================
% DCM Model Estimation for All Subjects
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script estimates DCM models for all subjects in parallel.
%   It processes all non-estimated models and renames them after estimation.
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - DCM models must exist in the specified directory
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm07_estimate_models; exit;"
% =========================================================================

% Add SPM to path
spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found. Please check the path: %s', spmPath);
end
addpath(spmPath);

% Define paths for specified models
param.modelPath = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/results/DCM/rDLPFC01_rHC300_TNT_model_00_RolandsNeuronSpace_not_center';

% Check if model directory exists
if ~exist(param.modelPath, 'dir')
    error('Model directory not found: %s', param.modelPath);
end

fprintf('Starting DCM model estimation...\n');

% Configure parallel processing
numworkers = 12; % 12 is max at the CBU
fprintf('Attempting to start parallel pool with %d workers...\n', numworkers);

if numworkers
    try
        poolobj = gcp('nocreate'); % Get current parallel pool
        
        if isempty(poolobj)
            parpool(numworkers);
            fprintf('Parallel pool started with %d workers\n', numworkers);
        else
            fprintf('Using existing parallel pool with %d workers\n', poolobj.NumWorkers);
            numworkers = poolobj.NumWorkers;
        end
    catch ME
        warning('Could not start parallel pool: %s\nProceeding with single-threaded execution.', ME.message);
        numworkers = 0; % Fall back to serial processing
    end
end

% Get subject folder names from the model directory
subs = cellstr(spm_select('List', param.modelPath, 'dir', 'sub-'));
if isempty(subs)
    error('No subject directories found in: %s', param.modelPath);
end
nsub = numel(subs);
fprintf('Found %d subjects\n', nsub);

% Estimate models for all subjects in parallel
fprintf('Starting model estimation for %d subjects...\n', nsub);
startTime = tic;

parfor (s = 1:nsub, numworkers)
    dcm_estimate(param, subs{s});
end

totalTime = toc(startTime);
fprintf('Model estimation completed in %.2f minutes\n', totalTime/60);

% Clean up parallel pool if we created one
if numworkers && ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
    fprintf('Parallel pool closed\n');
end

fprintf('All DCM models have been estimated successfully!\n');

% ========================================================================
% Function to estimate DCM models for a single subject
% ========================================================================
function dcm_estimate(param, subject)
    % Get full path to subject's model directory
    modelDir = fullfile(param.modelPath, subject);
    
    % Get all DCM models
    dcm_models = cellstr(spm_select('FPList', modelDir, '^DCM_.*\.mat$'));
    
    % Exclude already estimated models
    dcm_estimated = cellstr(spm_select('FPList', modelDir, '^DCM_.*e\.mat$'));
    dcm_models = setdiff(dcm_models, dcm_estimated);
    
    % If no models to estimate, return early
    if isempty(dcm_models)
        fprintf('No models to estimate for subject %s\n', subject);
        return;
    end
    
    fprintf('Estimating %d models for subject %s\n', length(dcm_models), subject);
    
    % Estimate each model
    for i = 1:length(dcm_models)
        try
            % Display progress
            fprintf('  Estimating model %d/%d for %s\n', i, length(dcm_models), subject);
            
            % Estimate the model
            spm_dcm_estimate(dcm_models{i});
            
            % Rename to indicate the model has been estimated
            [d, name, ext] = fileparts(dcm_models{i});
            newname = [name 'e'];
            movefile(dcm_models{i}, fullfile(d, [newname ext]));
            
            fprintf('  Model %d/%d for %s estimated successfully\n', i, length(dcm_models), subject);
        catch ME
            warning('Error estimating model %s for subject %s: %s', dcm_models{i}, subject, ME.message);
        end
    end
    
    fprintf('Completed estimation for subject %s\n', subject);
end