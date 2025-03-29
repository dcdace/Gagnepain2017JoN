% =========================================================================
% fMRIprep to SPM Preprocessing
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script prepares the fmriprep-processed files for first-level 
%   analysis in SPM. It performs the following operations:
%   1. Unzips the preprocessed BOLD files
%   2. Applies spatial smoothing if selected
%   3. Loads the BIDS events files and creates SPM-compatible condition .mat files
%   4. Extracts relevant confound regressors from fmriprep outputs
%   The script is parallelized to process multiple subjects simultaneously.
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - BIDS-formatted dataset with fmriprep outputs
%   - Events files in BIDS format
%
% Usage:
%   Run the script from the command line using:
%   matlab -nodisplay -nosplash -r "step01_prepare_files; exit;"
% =========================================================================

% Convert from function to script by removing the function line
% and making all variables accessible in the global scope

rootDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';

% Check SPM path and add required paths
spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';

% Check paths existence
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found: %s', spmPath);
end

% Add paths
addpath(genpath(fullfile(rootDir, 'code')));
addpath(spmPath);

% Parameters
param.BIDS = fullfile(rootDir, 'data');
param.fmriprep = fullfile(param.BIDS, 'derivatives', 'fmriprep');
param.outpath = fullfile(param.BIDS, 'derivatives', 'for-spm-firstlevel');
param.modality = 'func';
param.task = 'tnt';
param.space = 'MNI152NLin6Asym_res-2'; % 'T1w' for native space
param.confounds_of_interest = {'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'};
param.smoothing = true; % false for native space, true for MNI space
param.smoothing_kernel = [8 8 8];

% Validate critical directories
if ~exist(param.BIDS, 'dir')
    error('BIDS directory not found: %s', param.BIDS);
end
if ~exist(param.fmriprep, 'dir')
    error('fmriprep directory not found: %s', param.fmriprep);
end

fprintf('Starting fMRIprep to SPM preparation...\n');
fprintf('Using smoothing kernel: [%d %d %d]\n', param.smoothing_kernel);

% Number of workers for distributed computing
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

% Get subject IDs from the BIDS dataset
subs = spm_BIDS(param.BIDS, 'subjects');
nsub = numel(subs);
fprintf('Found %d subjects\n', nsub);

% Parallel loop for subjects
fprintf('Starting preprocessing for all subjects...\n');
startTime = tic;

parfor (s = 1:nsub, numworkers)
    try
        process_subject(subs{s}, param);
    catch ME
        warning('Error processing subject %s: %s', subs{s}, ME.message);
    end
end

if numworkers
    delete(gcp('nocreate'));
end

fprintf('Preprocessing completed in %.2f minutes.\n', toc(startTime) / 60);

% =========================================================
% PROCESSING FUNCTIONS
% =========================================================

%- Process a single subject
function process_subject(subjectID, param)
    subject = sprintf('sub-%s', subjectID);
    outdir = fullfile(param.outpath, subject, param.modality);

    % Ensure output directory exists
    if ~exist(outdir, 'dir')
        spm_mkdir(outdir);
    end

    % Fetch functional files
    bold_files = spm_select('FPList', fullfile(param.fmriprep, subject, 'func'), ...
        sprintf('.*_task-%s_run-.*_space-%s_desc-preproc_bold.nii.gz', param.task, param.space));
    bold_file_paths = cellstr(bold_files);

    % Unzip files if needed
    unzipped_files = cellfun(@(file) fullfile(outdir, replace(spm_file(file, 'filename'), '.gz', '')), bold_file_paths, 'UniformOutput', false);
    for i = 1:numel(bold_file_paths)
        if ~spm_existfile(unzipped_files{i})
            disp(['Unzipping ' bold_file_paths{i}]);
            spm_copy(bold_file_paths{i}, outdir, 'gunzip', true);
        end
    end

    % Apply smoothing if needed
    if param.smoothing
        apply_smoothing(unzipped_files, param.smoothing_kernel);
    end

    % Fetch confound files
    confounds_files = spm_select('FPList', fullfile(param.fmriprep, subject, 'func'), ...
        sprintf('.*_task-%s_run-.*_desc-confounds_timeseries.tsv', param.task));
    confounds_file_paths = cellstr(confounds_files);

    % Process each run
    for run = 1:numel(bold_file_paths)
        process_run(subject, subjectID, run, outdir, bold_file_paths{run}, confounds_file_paths{run}, param);
    end
end

%- Process a single run
function process_run(subject, subjectID, run, outdir, bold_file, confounds_file, param)
    % Load events
    events = spm_load(char(spm_BIDS(param.BIDS, 'data', 'modality', 'func', ...
        'type', 'events', 'task', param.task, 'sub', subjectID, 'run', sprintf('%02d', run))));

    % Create conditions
    trialtypes = unique(events.trial_type); % can exclude some types here, for example, ratings
    conds.names = trialtypes';
    conds.durations = arrayfun(@(t) events.duration(strcmpi(events.trial_type, trialtypes{t})), 1:numel(trialtypes), 'UniformOutput', false); % can set duration to 0 if needed
    conds.onsets = arrayfun(@(t) events.onset(strcmpi(events.trial_type, trialtypes{t})), 1:numel(trialtypes), 'UniformOutput', false);

    % Save conditions
    save(fullfile(outdir, sprintf('%s_task-%s_run-%02d_spmdef.mat', subject, param.task, run)), '-struct', 'conds');

    % Load confounds and filter to include only the ones of interest
    confounds = readtable(confounds_file, 'FileType', 'text', 'Delimiter', '\t');
    if all(ismember(param.confounds_of_interest, confounds.Properties.VariableNames))
        filtered_confounds = confounds(:, param.confounds_of_interest);
        R = filtered_confounds{:,:};
        names = filtered_confounds.Properties.VariableNames;
        save(fullfile(outdir, sprintf('%s_task-%s_run-%02d_confounds.mat', subject, param.task, run)), 'R', 'names');
    else
        missing = setdiff(param.confounds_of_interest, confounds.Properties.VariableNames);
        warning('Missing confounds for subject %s, run %02d: %s', subjectID, run, strjoin(missing, ', '));
    end
end

%- Apply smoothing to the files
function apply_smoothing(unzipped_files, smoothing_kernel)
    smoothed_files = cellfun(@(file) replace(file, '.nii', '_smoothed.nii'), unzipped_files, 'UniformOutput', false);
    for i = 1:numel(unzipped_files)
        if ~spm_existfile(smoothed_files{i})
            disp(['Smoothing ' unzipped_files{i}]);
            spm_smooth(unzipped_files{i}, smoothed_files{i}, smoothing_kernel);
        end
    end
end
