% -------------------------------
% Dace Apsvalka, @CBU 2025
% -------------------------------
% 
% This script uses prepared fmriprep and BIDS files for first-level analysis in SPM. 
% 1. Creates the SPM design matrix.
% 2. Estimates the model.
% 3. Defines contrasts - accounting for missing conditions.
%
% Run from VSCode:
% matlab -nodisplay -nosplash -r "step02_spm_first_level; exit;"
% =========================================================
function step02_spm_first_level

    rootDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';
    
    addpath(genpath('/imaging/correia/da05/students/mohith/Gagnepain2017JoN/code'))
    addpath('/imaging/local/software/spm_cbu_svn/releases/spm12_latest/')

    % Parameters
    param.BIDS = fullfile(rootDir, 'data');
    param.derivatives = fullfile(rootDir, 'data', 'derivatives', 'for-spm-firstlevel');
    param.saveDir   = fullfile(rootDir, 'results', 'spm_first-level', 'MNI', 'model01'); % where the results will be saved
    param.task = 'tnt';
    param.space = 'MNI152NLin6Asym_res-2';
    param.bold = 'bold_smoothed.nii'; % the end of the bold file name which to use
    param.hpf       = 128; % high path filtering. SPM default is 128

    % Number of workers for distributed computing
    numworkers = 12; % 12 is max at the CBU
    if numworkers
        try
            parpool(numworkers);
        catch ME
            warning('Could not start parallel pool with %d workers. Proceeding with single-threaded execution.', numworkers);
            numworkers = 0; % Fall back to serial processing
        end
    end

    % Get subject folder names from the prepared derivatives folder
    subs = cellstr(spm_select('List', param.derivatives, 'dir'));
    nsub = numel(subs);

    % Parallel loop for subjects
    parfor (s = 1:nsub, numworkers)
        try
            process_subject(subs{s}, param);
        catch ME
            warning('Error processing subject %s: %s', subs{s}, ME.message);
        end
    end
end

% =========================================================
% PROCESSING FUNCTION
% =========================================================

%- Process a single subject
function process_subject(subject, param)

    % where this subject's results will be saved
    glmDir      = fullfile(param.saveDir, subject);
    if ~exist(glmDir,'dir')
        mkdir(glmDir);
    end

    % Retrieve the metadata
    metadata = spm_BIDS(param.BIDS, 'metadata', 'sub', subject, 'run', '01', 'task', param.task, 'type', 'bold');

    % Get the parameters
    param.TR        = metadata.RepetitionTime;
    param.nslices   = numel(metadata.SliceTiming);

    [~, idx] = sortrows(metadata.SliceTiming); % get the slice acquisition order
    param.rslice = idx(floor(param.nslices/2)); % finds the middle slice in time


    %% DESIGN
    matlabbatch{1}.spm.stats.fmri_spec.timing.units     = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT        = param.TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t    = param.nslices;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0   = param.rslice;
    matlabbatch{1}.spm.stats.fmri_spec.fact             = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt             = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global           = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.mask             = {''};
    matlabbatch{1}.spm.stats.fmri_spec.cvi              = 'AR(1)';
    matlabbatch{1}.spm.stats.fmri_spec.dir              = {glmDir};

    % Get all files
    bold_files = cellstr(spm_select('FPList', fullfile(param.derivatives, subject, 'func'), sprintf('.*_task-%s_.*_space-%s_.*%s', param.task, param.space, param.bold)));
    event_files = cellstr(spm_select('FPList', fullfile(param.derivatives, subject, 'func'), sprintf('.*_task-%s_.*spmdef.mat', param.task)));
    confound_files = cellstr(spm_select('FPList', fullfile(param.derivatives, subject, 'func'), sprintf('.*_task-%s_.*confounds.mat', param.task)));

    % For each run 
    nruns = length(bold_files);
    for run = 1 : nruns 
        matlabbatch{1}.spm.stats.fmri_spec.sess(run).scans        = cellstr(spm_select('expand', bold_files(run)));
        matlabbatch{1}.spm.stats.fmri_spec.sess(run).multi        = event_files(run);
        matlabbatch{1}.spm.stats.fmri_spec.sess(run).multi_reg    = confound_files(run);
        matlabbatch{1}.spm.stats.fmri_spec.sess(run).hpf          = param.hpf;
    end

    %% ESTIMATE
    matlabbatch{2}.spm.stats.fmri_est.spmmat            = {fullfile(glmDir, 'SPM.mat')};
    matlabbatch{2}.spm.stats.fmri_est.write_residuals   = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical  = 1;

    %% SAVE AND RUN
    timenow = fix(clock);
    save(fullfile(glmDir, ['batch_design_' date '_' num2str(timenow(4)) '_' num2str(timenow(5)) '.mat']), 'matlabbatch');
    spm_jobman('run', matlabbatch);
    clear matlabbatch


    %% CONTRASTS

    % Define conditions and contrasts
    contrast_names = {
        'I', ...
        'NI', ...
        'T', ...
        'NT', ...
        'T  > NT', ...
        'NT > T', ...
        'I  > NI', ...
        'NI > I', ...
        'NI > T', ...
        'T  > NI', ...
        'T  > I', ...
        'I  > T'};

    % Define groups of conditions
    I_conditions = {'negNTi', 'neutrNTi'};
    NI_conditions = {'negNTni', 'neutrNTni'};
    T_conditions = {'negT', 'neutrT'};
    NT_conditions = {'negNTi', 'negNTni', 'neutrNTi', 'neutrNTni'};

    contrast_conditions = {
        {I_conditions, []}, ...          % 'I'
        {NI_conditions, []}, ...         % 'NI'
        {T_conditions, []}, ...          % 'T'
        {NT_conditions, []}, ...         % 'NT'
        {T_conditions, NT_conditions}, ... % 'T > NT'
        {NT_conditions, T_conditions}, ... % 'NT > T'
        {I_conditions, NI_conditions}, ... % 'I > NI'
        {NI_conditions, I_conditions}, ... % 'NI > I'
        {NI_conditions, T_conditions}, ... % 'NI > T'
        {T_conditions, NI_conditions}, ... % 'T > NI'
        {T_conditions, I_conditions}, ...  % 'T > I'
        {I_conditions, T_conditions}};     % 'I > T'


    % Load SPM design matrix
    load(fullfile(glmDir, 'SPM.mat'));
    design_matrix_names = SPM.xX.name; % Regressor names

    % Helper function to find indices of conditions
    find_condition_indices = @(conds) cell2mat(cellfun(@(c) find(contains(design_matrix_names, c)), conds, 'UniformOutput', false));

    % Define contrasts
    for i = 1:length(contrast_names)
        cname = contrast_names{i};
        condition_set = contrast_conditions{i};

        % Extract positive and negative condition sets
        pos_conditions = condition_set{1};
        neg_conditions = condition_set{2};

        % Initialize contrast vector
        contrast_vector = zeros(1, length(design_matrix_names));

        % Handle positive conditions
        if ~isempty(pos_conditions)
            pos_indices = find_condition_indices(pos_conditions);
            if ~isempty(pos_indices)
                contrast_vector(pos_indices) = 1 / numel(pos_indices); % Normalize positive weights
            end
        end

        % Handle negative conditions
        if ~isempty(neg_conditions)
            neg_indices = find_condition_indices(neg_conditions);
            if ~isempty(neg_indices)
                contrast_vector(neg_indices) = -1 / numel(neg_indices); % Normalize negative weights
            end
        end

    % add to matlabbatch
    matlabbatch{1}.spm.stats.con.consess{i}.tcon.name = cname;
    matlabbatch{1}.spm.stats.con.consess{i}.tcon.weights = contrast_vector(:);
    matlabbatch{1}.spm.stats.con.consess{i}.tcon.sessrep = 'none';
        
    end

    matlabbatch{1}.spm.stats.con.spmmat = {fullfile(glmDir, 'SPM.mat')};
    matlabbatch{1}.spm.stats.con.delete = 1;
    
    timenow = fix(clock);
    save(fullfile(glmDir, ['contrasts_batch_' date '_' num2str(timenow(4)) '_' num2str(timenow(5)) '.mat']), 'matlabbatch');
    spm_jobman('run', matlabbatch);
    
end
