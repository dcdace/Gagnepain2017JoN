% =========================================================================
% DCM Model Specification for All Subjects
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script specifies DCM models for all subjects based on a predefined
%   model space. It creates DCM models with different configurations of
%   intrinsic connections (A), modulatory effects (B), and driving inputs (C).
%
% Outputs:
%   - DCM models saved in the specified directory for each subject
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - ROI time series must exist for each subject
%   - Model space files (A.mat, B.mat, C.mat) must exist
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm06_specify_models; exit;"
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
param.ROIsub = 'model_01_uNTconcat_eoi_top20perc';

param.version = 'rDLPFC01_rHC300_TNT_model_00_RolandsNeuronSpace_not_center';

param.saveDir = fullfile(param.projectPath, 'results', 'DCM', param.version);
param.modelDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/DCM_model_spaces/DLPFC_HC_RolandsNeuronSpace';

param.center = 0; % Centering option for DCM

% Validate critical directories
if ~exist(param.dataPath, 'dir')
    error('Data directory not found: %s', param.dataPath);
end
if ~exist(param.modelDir, 'dir')
    error('Model space directory not found: %s', param.modelDir);
end
if ~exist(param.roiPath, 'dir')
    error('ROI directory not found: %s', param.roiPath);
end

% Create save directory if it doesn't exist
if ~exist(param.saveDir, 'dir')
    fprintf('Creating output directory: %s\n', param.saveDir);
    mkdir(param.saveDir);
end

% Define ROIs and conditions
% Note: The order of ROIs and Conditions must correspond to the specified model space!
param.rois = {'withinConj_rDLPFC', 'hc330_Right'};
param.cond = {'u', 'NT'};
param.ncond = size(param.cond, 2);
param.nrois = size(param.rois, 2);

fprintf('Model specification will use:\n');
fprintf('  ROIs: %s\n', strjoin(param.rois, ', '));
fprintf('  Conditions: %s\n', strjoin(param.cond, ', '));

% Get echo time from BIDS metadata
try
    metadata = spm_BIDS(param.dataPath, 'metadata', 'type', 'bold');
    param.TE = metadata{1}.EchoTime;
    fprintf('  Echo Time (TE): %.4f s\n', param.TE);
    clear metadata
catch ME
    warning('Could not extract TE from BIDS metadata: %s\nUsing default value.', ME.message);
    param.TE = 0.03; % Default value
end

% Load the model space
fprintf('Loading model space from: %s\n', param.modelDir);
try
    param.A = load(fullfile(param.modelDir, 'A.mat'));
    param.B = load(fullfile(param.modelDir, 'B.mat'));
    param.C = load(fullfile(param.modelDir, 'C.mat'));
    param.isD = 0; % Flag for nonlinear DCM
    if param.isD
        param.D = load(fullfile(param.modelDir, 'D.mat'));
    end
    fprintf('  Model space loaded successfully\n');
    fprintf('  Number of models: %d\n', size(param.B.B, 2));
catch ME
    error('Failed to load model space: %s', ME.message);
end

% Get all subject IDs
subs = cellstr(spm_select('List', param.dataPath, 'dir', 'sub-'));
if isempty(subs)
    error('No subject directories found in: %s', param.dataPath);
end
nsub = numel(subs);
fprintf('Found %d subjects\n', nsub);

% Specify models for each subject
fprintf('Starting model specification for each subject...\n');
for s = 1:nsub
    try
        dcm_specify(param, subs{s});
    catch ME
        warning('Error specifying models for subject %s: %s', subs{s}, ME.message);
    end
end

fprintf('Model specification complete!\n');

% ========================================================================
% Function to specify DCM models for a single subject
% ========================================================================
function dcm_specify(param, subject)
    fprintf('Specifying models for subject: %s\n', subject);
    
    % Load regions of interest    
    fprintf('  Loading ROIs for subject...\n');
    for r = 1:param.nrois
        froi = spm_select('FPList', fullfile(param.roiPath, subject, 'VOIs', param.ROIsub), ['.*' subject '_' param.rois{r} '.*\.mat$']);
        if exist(froi, 'file')
            load(froi);
            DCM.xY(r) = xY;
            fprintf('    Loaded ROI: %s\n', param.rois{r});
        else
            fprintf('    ROI not found: %s\n', param.rois{r});
            error('ROI %s does not exist for subject %s', param.rois{r}, subject);
        end
    end
    
    DCM.n = length(DCM.xY);      % number of regions
    DCM.v = length(DCM.xY(1).u); % number of time points
    
    % Load SPM.mat from first level analysis
    fGLM = fullfile(param.first_level_dir, param.stats, subject, 'SPM.mat');
    if exist(fGLM, 'file')
        fprintf('  Loading GLM from: %s\n', fGLM);
        load(fGLM);
    else
        error('No SPM.mat file found: %s', fGLM);
    end
    
    % Prepare time series data
    fprintf('  Preparing time series data...\n');
    DCM.Y.dt = SPM.xY.RT;
    DCM.Y.X0 = DCM.xY(1).X0;
    
    for i = 1:DCM.n
        DCM.Y.y(:,i) = DCM.xY(i).u;
        DCM.Y.name{i} = DCM.xY(i).name;
    end
    
    DCM.Y.Q = spm_Ce(ones(1,DCM.n)*DCM.v);
    
    % Prepare experimental inputs
    fprintf('  Preparing experimental inputs...\n');
    DCM.U.dt = SPM.Sess.U(1).dt;
    DCM.U.name = param.cond;
    
    DCM.U.u = [];
    for c = 1:param.ncond
        condIdx = strcmp([SPM.Sess.U.name], param.cond{c});
        if any(condIdx)
            % Adding experimental inputs for each condition, skipping first 32 scans
            DCM.U.u = [DCM.U.u SPM.Sess.U(condIdx).u(33:end,1)];
            fprintf('    Added condition: %s\n', param.cond{c});
        else
            error('Condition %s not found in SPM.mat', param.cond{c});
        end
    end
    
    % Set DCM parameters and options
    fprintf('  Setting DCM parameters and options...\n');
    DCM.delays = repmat(SPM.xY.RT/2, 1, DCM.n); % Slice timing for each region
    DCM.TE = param.TE;
    
    DCM.options.two_state = 0;
    DCM.options.stochastic = 0;
    DCM.options.centre = param.center;
    DCM.options.induced = 0;
    
    % Create and save all model variants
    fprintf('  Creating model variants...\n');
    saveDir = fullfile(param.saveDir, subject);
    if exist(saveDir, 'dir')
        fprintf('    Removing existing models in: %s\n', saveDir);
        rmdir(saveDir, 's');
    end
    mkdir(saveDir);
    
    for i = 1:size(param.B.B, 2)
        DCM.a = param.A.A(:,:,i);
        DCM.b = param.B.B{i};
        DCM.c = param.C.C(:,:,i);
        
        if param.isD && any(param.D.D{i}(:))
            DCM.d = param.D.D{i};
            DCM.options.nonlinear = 1;
        else
            DCM.options.nonlinear = 0;
            DCM.d = double.empty(4,4,0);
        end
        
        m = ['m' num2str(i, '%02.f')];
        modelFile = fullfile(saveDir, ['DCM_' subject '_' m]);
        save(modelFile, 'DCM');
        fprintf('    Saved model %d/%d: %s\n', i, size(param.B.B, 2), modelFile);
    end
    
    fprintf('  Completed model specification for subject: %s\n', subject);
end