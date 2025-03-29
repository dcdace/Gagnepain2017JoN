% =========================================================================
% SPM Group-Level ANOVA
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script performs a group-level ANOVA analysis in SPM using the
%   first-level results. It performs the following operations:
%   1. Sets up a flexible factorial design (within-subjects ANOVA)
%   2. Defines the model specification parameters
%   3. Estimates the model
%   4. Creates and computes contrasts of interest between conditions
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - First-level analysis must be completed for all subjects
%   - Subject directories must exist in the first-level results folder
%
% Usage:
%   Run the script from the command line using:
%   matlab -nodisplay -nosplash -r "step03_spm_group_anova; exit;"
% =========================================================================

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

% -------------------------------------------------------------------------
%% DEFINE PARAMETERS
% -------------------------------------------------------------------------

% first level location
param.model = 'model_01';
param.statPath = fullfile(rootDir, 'results', 'spm_first-level','MNI', param.model);

% Validate directory
if ~exist(param.statPath, 'dir')
    error('First-level statistics directory not found: %s', param.statPath);
end

% subject IDs
param.subjID = cellstr(spm_select('List', param.statPath, 'dir'));
if isempty(param.subjID)
    error('No subject directories found in: %s', param.statPath);
end
nsub = numel(param.subjID);
fprintf('Found %d subjects\n', nsub);

% where to save
param.savePath = fullfile(rootDir, 'results', 'spm_group-level', param.model);
if ~exist(param.savePath, 'dir')
    mkdir(param.savePath);
    fprintf('Created output directory: %s\n', param.savePath);
end

% conditions and contrasts
param.conditions = {'negNTi', 'negNTni', 'neutrNTi', 'neutrNTni', 'negT', 'neutrT'};
param.contrasts = {
    'Effects of interest', 0 0 0 0 0 0; % will be defined later
    'T > NT',   -1/4    -1/4    -1/4    -1/4     1/2     1/2    ;
    'NT > T',    1/4     1/4     1/4     1/4    -1/2    -1/2    ;
    'NI > I',   -1/2     1/2    -1/2     1/2      0       0     ;
    'I > NI',    1/2    -1/2     1/2    -1/2      0       0     ;
    'T > NI',     0     -1/2      0     -1/2     1/2     1/2    ;
    'NI > T',     0      1/2      0      1/2    -1/2    -1/2    ;
    'T > I',    -1/2      0     -1/2      0      1/2     1/2    ;
    'I > T',     1/2      0      1/2      0     -1/2    -1/2    ;
    };

fprintf('Starting group-level ANOVA analysis...\n');
fprintf('Using model: %s\n', param.model);
fprintf('Number of conditions: %d\n', numel(param.conditions));
fprintf('Number of contrasts: %d\n', size(param.contrasts, 1));

% -------------------------------------------------------------------------
% save parameters
save(fullfile(param.savePath, [param.model '_parameters.mat']), 'param'); 
fprintf('Saved parameter file: %s\n', fullfile(param.savePath, [param.model '_parameters.mat']));

%% DESIGN
% find which contrasts in the first-level these are
fprintf('Finding first-level contrast files...\n');
exampleSPM = load(fullfile(param.statPath, param.subjID{1}, 'SPM.mat'));
for c = 1:numel(param.conditions)
    thic = find(strcmp({exampleSPM.SPM.xCon.name}, param.conditions{c}));
    if isempty(thic)
        warning('Contrast "%s" not found in first-level SPM.mat', param.conditions{c});
        continue;
    end
    param.condfiles{1,c} = {['con_00' num2str(thic,'%02.f') '.nii']};
end

fprintf('Setting up ANOVA design...\n');
matlabbatch{1}.spm.stats.factorial_design.dir = {param.savePath};

for i = 1 : size(param.subjID, 1)
    for c = 1:numel(param.conditions)
        subjConFile = fullfile(param.statPath, param.subjID{i}, param.condfiles{1,c});
        if ~exist(char(subjConFile), 'file')
            warning('Contrast file not found: %s', char(subjConFile));
            continue;
        end
        matlabbatch{1}.spm.stats.factorial_design.des.anovaw.fsubject(i).scans(c,1) = subjConFile;
        matlabbatch{1}.spm.stats.factorial_design.des.anovaw.fsubject(i).conds(c,1) = c;
    end
end

matlabbatch{1}.spm.stats.factorial_design.des.anovaw.dept           = 1;
matlabbatch{1}.spm.stats.factorial_design.des.anovaw.variance       = 1;
matlabbatch{1}.spm.stats.factorial_design.des.anovaw.gmsca          = 0;
matlabbatch{1}.spm.stats.factorial_design.des.anovaw.ancova         = 0;
matlabbatch{1}.spm.stats.factorial_design.cov                       = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov                 = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none        = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im                = 1;
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit            = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no    = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm           = 1;

fprintf('Running design specification...\n');
spm_jobman('run', matlabbatch);
clear matlabbatch

%% ESTIMATE
fprintf('Setting up model estimation...\n');
matlabbatch{1}.spm.stats.fmri_est.spmmat            = {fullfile(param.savePath, 'SPM.mat')};
matlabbatch{1}.spm.stats.fmri_est.write_residuals   = 0;
matlabbatch{1}.spm.stats.fmri_est.method.Classical  = 1;

fprintf('Estimating model...\n');
spm_jobman('run', matlabbatch);
clear matlabbatch

%% CONTRASTS
fprintf('Setting up contrasts...\n');
matlabbatch{1}.spm.stats.con.spmmat = {fullfile(param.savePath, 'SPM.mat')};

% F contrast
fprintf('Creating F-contrast for effects of interest...\n');
matlabbatch{1}.spm.stats.con.consess{1}.fcon.name       = param.contrasts{1,1};
matlabbatch{1}.spm.stats.con.consess{1}.fcon.weights    = detrend(eye(numel(param.conditions)), 0);
matlabbatch{1}.spm.stats.con.consess{1}.fcon.sessrep    = 'repl';

% T contrasts
for contr = 2:size(param.contrasts,1)
    fprintf('Creating T-contrast: %s\n', param.contrasts{contr,1});
    matlabbatch{1}.spm.stats.con.consess{contr}.tcon.name       = param.contrasts{contr,1};
    matlabbatch{1}.spm.stats.con.consess{contr}.tcon.weights    = cell2mat(param.contrasts(contr,2:end));
    matlabbatch{1}.spm.stats.con.consess{contr}.tcon.sessrep    = 'repl';
end

matlabbatch{1}.spm.stats.con.delete = 0;

% Save contrast batch
timenow = fix(clock);
contrastBatchFile = fullfile(param.savePath, ['contrasts_batch_' date '_' num2str(timenow(4)) '_' num2str(timenow(5)) '.mat']);
save(contrastBatchFile, 'matlabbatch');
fprintf('Saved contrast batch file: %s\n', contrastBatchFile);

% Run contrasts
fprintf('Computing contrasts...\n');
spm_jobman('run', matlabbatch);

fprintf('Group-level ANOVA analysis completed successfully.\n');
