% -------------------------------
% Dace Apsvalka, @CBU 2025
% -------------------------------
%
% This script prepares the fmriprep files for the first-level analysis in SPM.
% 1. unzips the preprocessed BOLD files.
% 2. applies smoothing if selected.
% 3. loads the events files and creates conditions .mat file.
% 4. loads the confounds files and creates confounds .mat file.
%
% The script is parallelised to process multiple subjects simultaneously.
%
%
% Run from VSCode:
% matlab -nodisplay -nosplash -r "step01_prepare_files; exit;"
% =========================================================
function step01_prepare_files

    rootDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';

    addpath(genpath(fullfile(rootDir, 'code')));
    addpath('/imaging/local/software/spm_cbu_svn/releases/spm12_latest/');

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

    % Number of workers for distributed computing
    numworkers = 12; % 12 is max at the CBU
    if numworkers
        try
            parpool(numworkers);
        catch
            warning('Could not start parallel pool with %d workers. Proceeding with single-threaded execution.', numworkers);
            numworkers = 0; % Fall back to serial processing
        end
    end

    % Get subject IDs from the BIDS dataset
    subs = spm_BIDS(param.BIDS, 'subjects');
    nsub = numel(subs);

    % Parallel loop for subjects
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

    exit; % Ensure MATLAB exits properly
    
end

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
