% =========================================================================
% DCM VOI (Volume of Interest) Extraction for All Subjects
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script extracts Volumes of Interest (VOIs) for DCM analysis from
%   predefined ROI masks for each subject. It processes multiple ROIs and
%   handles the extraction and file organization in parallel.
%
% Outputs:
%   - VOI files for each subject and ROI; saved in the specified output directory
%  
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - ROI mask files must exist for each subject
%   - First-level analysis must be completed
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm05_create_VOIs; exit;"
% =========================================================================

% Add SPM to path
spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found. Please check the path: %s', spmPath);
end
addpath(spmPath);

% Define paths and parameters
param.projectPath = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';
param.dataPath = fullfile(param.projectPath, 'data');
param.first_level_dir = fullfile(param.projectPath, 'results', 'spm_first-level', 'native');
param.stats = 'model_01_uNTconcat';
param.roiPath = fullfile(param.dataPath, 'derivatives', 'for-dcm');

param.ROIsub = 'model_01_uNTconcat_eoi_top10perc';
param.ROI = {'hc330_Right', 'withinConj_rDLPFC'};

% Validate critical directories
if ~exist(param.dataPath, 'dir')
    error('Data directory not found: %s', param.dataPath);
end
if ~exist(param.first_level_dir, 'dir')
    error('First level directory not found: %s', param.first_level_dir);
end

fprintf('Starting VOI extraction for DCM analysis...\n');
fprintf('ROIs to extract: %s\n', strjoin(param.ROI, ', '));

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

% Get all subject IDs
subs = cellstr(spm_select('List', param.dataPath, 'dir', 'sub-'));
if isempty(subs)
    error('No subject directories found in: %s', param.dataPath);
end
nsub = numel(subs);
fprintf('Found %d subjects\n', nsub);

% Process subjects in parallel
fprintf('Starting VOI extraction for all subjects...\n');
startTime = tic;

parfor (s = 1:nsub, numworkers)
    try
        getVOIs(param, subs{s});
    catch ME
        warning('Error processing subject %s: %s', subs{s}, ME.message);
    end
end

totalTime = toc(startTime);
fprintf('VOI extraction completed in %.2f minutes\n', totalTime/60);

% Clean up parallel pool if we created one
if numworkers && ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
    fprintf('Parallel pool closed\n');
end

fprintf('VOI extraction complete!\n');

% ========================================================================
% Function to extract VOIs for a single subject
% ========================================================================
function getVOIs(param, subject)
    fprintf('Extracting VOIs for subject: %s\n', subject);
    
    % Locate SPM.mat file
    modelDir = fullfile(param.first_level_dir, param.stats, subject);
    fspm = fullfile(modelDir, 'SPM.mat');
    
    if ~exist(fspm, 'file')
        error('SPM.mat not found for subject %s: %s', subject, fspm);
    end
    
    % Get mask file from first level analysis
    mask = spm_select('FPList', modelDir, '^mask.*\.nii$');
    if isempty(mask)
        error('Mask file not found for subject %s in %s', subject, modelDir);
    end
    
    % Create matlabbatch for each ROI
    nROIs = size(param.ROI, 2);
    matlabbatch = cell(1, nROIs);
    
    % Set up the extraction for each ROI
    for r = 1:nROIs
        % Locate the ROI file
        roiDir = fullfile(param.roiPath, subject, 'ROIs', param.ROIsub);
        froi = spm_select('FPList', roiDir, ['^' subject '_desc-' param.ROI{r} '.*\.nii$']);
        
        if isempty(froi)
            warning('ROI file not found for %s: %s', param.ROI{r}, roiDir);
            continue;
        end
        
        fprintf('  Setting up extraction for ROI: %s\n', param.ROI{r});
        
        % Configure the VOI extraction parameters
        matlabbatch{r}.spm.util.voi.spmmat = {fspm};
        matlabbatch{r}.spm.util.voi.adjust = 1; % First contrast
        matlabbatch{r}.spm.util.voi.session = 1;
        matlabbatch{r}.spm.util.voi.name = [subject '_' param.ROI{r}];
        matlabbatch{r}.spm.util.voi.roi{1}.mask.image = {froi};
        matlabbatch{r}.spm.util.voi.roi{1}.mask.threshold = 0.05;
        matlabbatch{r}.spm.util.voi.roi{2}.mask.image = {mask};
        matlabbatch{r}.spm.util.voi.roi{2}.mask.threshold = 0.05;
        matlabbatch{r}.spm.util.voi.expression = 'i1&i2';
    end
    
    % Run the extraction
    fprintf('  Running VOI extraction for subject: %s\n', subject);
    try
        spm_jobman('run', matlabbatch);
        fprintf('  VOI extraction completed for subject: %s\n', subject);
    catch ME
        warning('Error running VOI extraction for subject %s: %s', subject, ME.message);
        return;
    end
    
    % Move VOI files to their destination directory
    fprintf('  Moving VOI files for subject: %s\n', subject);
    for r = 1:nROIs
        % Locate the created VOIs
        movefiles = cellstr(spm_select('FPList', modelDir, ['^VOI_' subject '_' param.ROI{r}]));
        
        if isempty(movefiles)
            warning('No VOI files found to move for ROI %s', param.ROI{r});
            continue;
        end
        
        % Create destination directory if it doesn't exist
        newdir = fullfile(param.roiPath, subject, 'VOIs', param.ROIsub);
        if ~exist(newdir, 'dir')
            mkdir(newdir);
        end
        
        % Move each file
        for f = 1:size(movefiles, 1)
            [~, filename, ext] = fileparts(movefiles{f});
            fprintf('    Moving: %s%s\n', filename, ext);
            movefile(movefiles{f}, fullfile(newdir, [filename ext]));
        end
    end
    
    fprintf('Completed VOI extraction for subject: %s\n', subject);
end
