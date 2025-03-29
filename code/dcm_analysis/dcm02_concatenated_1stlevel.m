% =========================================================================
% DCM Preparation: First-Level Concatenated Analysis
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script concatenates first-level design matrices and estimates 
%   concatenated models for DCM analysis. It processes multiple runs of data
%   into a single time series with appropriate nuisance regressors.
%   The script is parallelized to process multiple subjects simultaneously.
%
% Outputs:
%   - Concatenated first-level models for each subject
%   - F-contrast for effects of interest
%   - Model specification and contrast files saved in the output directory
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - First-level analysis must be completed
%   - createNuisanceParameter_noConstant.m must be available
%   - spm_fmri_concatenate.m must be available
%
% Outputs:
%   - Concatenated first-level models
%   - F-contrast for effects of interest
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm02_concatenated_1stlevel; exit;"
% =========================================================================

% Define paths and parameters
param.rootDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';
param.stats = 'model_01';
param.saveDir = fullfile(param.rootDir, 'results', 'spm_first-level', 'native', [param.stats '_uNTconcat']);

param.statsPath = fullfile(param.rootDir, 'results', 'spm_first-level', 'native', param.stats);
param.onsets = fullfile(param.rootDir, 'data', 'derivatives', 'for-dcm');

% Validate critical directories
if (~exist(param.statsPath, 'dir'))
    error('Statistics directory not found: %s', param.statsPath);
end
if (~exist(param.onsets, 'dir'))
    error('Onsets directory not found: %s', param.onsets);
end

% Add required paths
addpath(genpath(fullfile(param.rootDir, 'code')));

spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';
if (~exist(spmPath, 'dir'))
    error('SPM12 directory not found: %s', spmPath);
end
addpath(spmPath);

fprintf('Starting concatenated first-level analysis for DCM...\n');

% Get all subject IDs
subs = cellstr(spm_select('List', param.statsPath, 'dir', '^sub-'));
if (isempty(subs))
    error('No subject directories found in: %s', param.statsPath);
end
nsub = numel(subs);
fprintf('Found %d subjects\n', nsub);

% Configure parallel processing
numworkers = 12; % 12 is max at the CBU
fprintf('Attempting to start parallel pool with %d workers...\n', numworkers);

if (numworkers)
    try
        poolobj = gcp('nocreate'); % Get current parallel pool
        
        if (isempty(poolobj))
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

% Process subjects in parallel
fprintf('Starting analysis for %d subjects...\n', nsub);
startTime = tic;

parfor (s = 1:nsub, numworkers)
    try
        firstLevel(subs{s}, param);
    catch ME
        warning('Error processing subject %s: %s', subs{s}, ME.message);
    end
end

totalTime = toc(startTime);
fprintf('Analysis completed in %.2f minutes\n', totalTime/60);

% Clean up parallel pool if we created one
if (numworkers && ~isempty(gcp('nocreate')))
    delete(gcp('nocreate'));
    fprintf('Parallel pool closed\n');
end

fprintf('Concatenated first-level analysis complete! Saved in %s\n', param.saveDir);

% ========================================================================
% Function to perform first-level analysis for a single subject
% ========================================================================
function firstLevel(subject, param)
    fprintf('Processing subject: %s\n', subject);
    
    % Define output directory
    savemodel = fullfile(param.saveDir, subject);
    
    % Create output directory (remove if exists)
    if (exist(savemodel, 'dir'))
        fprintf('  Removing existing model directory: %s\n', savemodel);
        rmdir(savemodel, 's');    
    end
    mkdir(savemodel);
    
    % Load original SPM.mat to get parameters
    fspm = fullfile(param.statsPath, subject, 'SPM.mat');
    if (~exist(fspm, 'file'))
        error('SPM.mat file not found for subject %s: %s', subject, fspm);
    end
    
    fprintf('  Loading original SPM.mat from: %s\n', fspm);
    load(fspm);
    
    % Extract parameters from SPM
    param.TR = SPM.xY.RT;
    param.t = SPM.xBF.T;
    param.t0 = SPM.xBF.T0;
    
    % Prepare for concatenation
    nruns = length(SPM.Sess);
    nscans = SPM.nscan; % nVolumesPerRun
    allscans = cellstr(SPM.xY.P); % all functional volumes across all runs
    confounds = [SPM.Sess.C]; % confound regressors for each run
    
    fprintf('  Parameters: TR=%.2fs, %d runs, %d volumes per run\n', param.TR, nruns, nscans(1));
    
    % Clear SPM from memory
    clear SPM;
    
    % Create nuisance regressors for concatenated design
    fprintf('  Creating nuisance regressors...\n');
    nuisancefileOutput = createNuisanceParameter_noConstant(nruns, confounds, nscans, savemodel);
    
    % Prepare model specification
    onsetfile = fullfile(param.onsets, subject, [param.stats '_uNT_concatinated_onsets.mat']);
    if (~exist(onsetfile, 'file'))
        error('Concatenated onsets file not found: %s', onsetfile);
    end
    
    fprintf('  Specifying concatenated first-level model...\n');
    matlabbatch = {};
    
    % Configure model specification
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = param.TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = param.t;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = param.t0;
    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
    matlabbatch{1}.spm.stats.fmri_spec.cvi = ''; %'AR(1)';
    matlabbatch{1}.spm.stats.fmri_spec.dir = {savemodel};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).scans = allscans;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {}, 'orth', {});
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).multi = {onsetfile};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).regress = struct('name', {}, 'val', {});
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).multi_reg = {nuisancefileOutput};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).hpf = Inf;
    
    % Run the model specification
    fprintf('  Running model specification...\n');
    spm_jobman('run', matlabbatch);
    
    % Save the design batch
    timenow = fix(clock);
    designfile = fullfile(savemodel, ['design_' date '_' num2str(timenow(4)) '_' num2str(timenow(5)) '.mat']);
    save(designfile, 'matlabbatch');
    clear matlabbatch;
    
    % Concatenate the runs
    fprintf('  Concatenating runs...\n');
    spm_fmri_concatenate(fullfile(savemodel, 'SPM.mat'), nscans);
    
    % Estimate the model
    fprintf('  Estimating model...\n');
    matlabbatch = {};
    matlabbatch{1}.spm.stats.fmri_est.spmmat = {fullfile(savemodel, 'SPM.mat')};
    matlabbatch{1}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{1}.spm.stats.fmri_est.method.Classical = 1;
    spm_jobman('run', matlabbatch);
    clear matlabbatch;
    
    % Create contrast for effects of interest
    fprintf('  Creating F-contrast for effects of interest...\n');
    cond_of_int = 2; % u and NT
    matlabbatch = {};
    matlabbatch{1}.spm.stats.con.spmmat = {fullfile(savemodel, 'SPM.mat')};
    matlabbatch{1}.spm.stats.con.consess{1}.fcon.name = 'effects of interest';
    matlabbatch{1}.spm.stats.con.consess{1}.fcon.weights = eye(cond_of_int);
    matlabbatch{1}.spm.stats.con.consess{1}.fcon.sessrep = 'repl';
    matlabbatch{1}.spm.stats.con.delete = 1;
    
    % Run contrast
    timenow = fix(clock);
    contrastfile = fullfile(savemodel, ['contrasts_' date '_' num2str(timenow(4)) '_' num2str(timenow(5)) '.mat']);
    save(contrastfile, 'matlabbatch');
    spm_jobman('run', matlabbatch);
    
    fprintf('  Completed processing for subject: %s\n', subject);
end