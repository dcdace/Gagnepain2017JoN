% =========================================================================
% DCM ROI Creation: Select Top Active Voxels
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script creates refined ROIs for DCM analysis by selecting the top
%   percentage of active voxels within each anatomical ROI mask. This approach
%   ensures that only the most task-relevant voxels are included in the DCM
%   analysis, improving signal quality.
%
% Outputs:
%   - New ROI masks with only the top active voxels; Nifti files saved in the specified output directory
%
% Requirements:
%   - SPM12 and Marsbar must be added to the MATLAB path
%   - First-level analysis must be completed
%   - Anatomical ROI masks must exist
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm04_create_TopVoxels_ROI; exit;"
% =========================================================================

% Add required paths
spmPath = '/imaging/correia/da05/MATLAB/spm12';
marsbarPath = '/imaging/correia/da05/MATLAB/spm12/toolbox/marsbar';
marsbarSpm5Path = '/imaging/correia/da05/MATLAB/spm12/toolbox/marsbar/spm5';

% Check paths existence
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found: %s', spmPath);
end
if ~exist(marsbarPath, 'dir')
    error('Marsbar directory not found: %s', marsbarPath);
end

% Add paths
addpath(spmPath);
addpath(marsbarPath);
addpath(marsbarSpm5Path);

% Define paths and parameters
param.projectPath = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';
param.dataPath = fullfile(param.projectPath, 'data');
param.first_level_dir = fullfile(param.projectPath, 'results', 'spm_first-level', 'native');
param.stats = 'model_01_uNTconcat';
param.roiPath = fullfile(param.dataPath, 'derivatives', 'for-dcm');
param.ROI = {'hc330_Right', 'withinConj_rDLPFC'};
param.con = 'ess_0001.nii'; % Essential effects contrast
param.perc = 0.1; % Percentage of top voxels to include (0.2 = top 20%)

% Validate critical directories
if ~exist(param.dataPath, 'dir')
    error('Data directory not found: %s', param.dataPath);
end
if ~exist(param.first_level_dir, 'dir')
    error('First level directory not found: %s', param.first_level_dir);
end
if ~exist(param.roiPath, 'dir')
    error('ROI directory not found: %s', param.roiPath);
end

fprintf('Starting ROI creation with top %d%% active voxels...\n', param.perc * 100);
fprintf('ROIs to process: %s\n', strjoin(param.ROI, ', '));

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
fprintf('Starting top voxel selection for all subjects...\n');
startTime = tic;

parfor (s = 1:nsub, numworkers)
    try
        create_top_voxel_rois(param, subs{s});
    catch ME
        warning('Error processing subject %s: %s', subs{s}, ME.message);
    end
end

totalTime = toc(startTime);
fprintf('ROI creation completed in %.2f minutes\n', totalTime/60);

% Clean up parallel pool if we created one
if numworkers && ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
    fprintf('Parallel pool closed\n');
end

fprintf('ROI creation complete!\n');

% ========================================================================
% Function to create top-voxel ROIs for a single subject
% ========================================================================
function create_top_voxel_rois(param, subject)
    fprintf('Processing top-voxel ROIs for subject: %s\n', subject);
    
    % Get number of ROIs
    nROIs = length(param.ROI);
    
    % Initialize arrays to track voxel counts
    total_nVox = zeros(nROIs, 1);
    nVox = zeros(nROIs, 1);
    
    % Process each ROI
    for r = 1:nROIs
        % Create output directory for the subject's processed ROIs
        saveDir = fullfile(param.roiPath, subject, 'ROIs', [param.stats '_eoi_top' num2str(param.perc*100) 'perc']);
        if ~exist(saveDir, 'dir')
            mkdir(saveDir);
            fprintf('  Created directory: %s\n', saveDir);
        end
        
        % Locate the original ROI file
        froi = spm_select('FPList', fullfile(param.roiPath, subject, 'ROIs'), ['^' subject '_desc-' param.ROI{r} '.*\.nii$']);
        if isempty(froi)
            warning('  ROI file not found for %s', param.ROI{r});
            continue;
        end
        [~, roiname, ~] = fileparts(froi);
        
        % Locate contrast image
        fcon = fullfile(param.first_level_dir, param.stats, subject, param.con);
        if ~exist(fcon, 'file')
            warning('  Contrast file not found: %s', fcon);
            continue;
        end
        
        fprintf('  Processing ROI: %s\n', param.ROI{r});
        
        % Copy the ROI to the save directory
        copyfile(froi, saveDir);
        froi = spm_select('FPList', saveDir, ['^' subject '.*\.nii$']);
        
        % Reslice ROI to match contrast image space
        fprintf('  Reslicing ROI to match contrast space...\n');
        Vi = {fcon; froi}; % model space; space to change
        spm_reslice(Vi, struct('mean', false, 'which', 1, 'prefix', ''));
        
        % Binarize the ROI mask
        fprintf('  Binarizing ROI mask...\n');
        spm_imcalc(froi, froi, 'i1>0.05');
        
        % Read the ROI mask
        try
            original_ROI = spm_read_vols(spm_vol(froi));
        catch ME
            warning('  Error reading ROI volume: %s', ME.message);
            continue;
        end
        
        % Find voxels within the ROI mask
        roivoxels = find(original_ROI);
        if isempty(roivoxels)
            warning('  No voxels found in ROI mask');
            continue;
        end
        
        % Get 3D coordinates for each ROI voxel
        [x, y, z] = ind2sub(size(original_ROI), roivoxels);
        
        % Read the contrast map
        try
            contrast_map = spm_read_vols(spm_vol(fcon));
        catch ME
            warning('  Error reading contrast volume: %s', ME.message);
            continue;
        end
        
        % Get contrast values within the ROI
        con_values = contrast_map(roivoxels);
        
        % Combine contrast values with coordinates
        Values = [con_values, x, y, z];
        % Sort by contrast values (descending)
        Values_sorted = sortrows(Values, -1);
        
        % Remove NaN values
        Values_sorted(isnan(Values_sorted(:,1)), :) = [];
        
        % Calculate the number of voxels to include
        total_nVox(r) = size(Values_sorted, 1);
        fprintf('  Total voxels in ROI: %d\n', total_nVox(r));
        
        newsize = round(total_nVox(r) * param.perc);
        % If the percentage results in less than 1 voxel, use 1 voxel
        if newsize < 1
            nVox(r) = 1;
        else
            nVox(r) = newsize;
        end
        fprintf('  Selecting top %d voxels (%.1f%%)\n', nVox(r), param.perc * 100);
        
        % Create new ROI mask with only top voxels
        newRoi_mask = false(size(original_ROI));
        new_roi_index = sub2ind(size(newRoi_mask), ...
                              Values_sorted(1:nVox(r), 2), ...
                              Values_sorted(1:nVox(r), 3), ...
                              Values_sorted(1:nVox(r), 4));
        newRoi_mask(new_roi_index) = true;
        
        % Save the new ROI as a nifti file
        fprintf('  Saving new ROI mask...\n');
        newRoiVolfile = spm_vol(froi);
        newRoiVolfile.fname = fullfile(saveDir, [roiname '.nii']);
        try
            spm_write_vol(newRoiVolfile, newRoi_mask);
            fprintf('  Saved: %s\n', newRoiVolfile.fname);
        catch ME
            warning('  Error writing ROI volume: %s', ME.message);
        end
    end
    
    fprintf('Completed processing for subject: %s\n', subject);
end