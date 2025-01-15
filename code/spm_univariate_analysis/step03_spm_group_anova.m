% -------------------------------
% Dace Apsvalka, @CBU 2025
% -------------------------------
% 
% This script uses the first-level results to perform a group-level ANOVA in SPM.
%
% Run from VSCode:
% matlab -nodisplay -nosplash -r "step03_spm_group_anova; exit;"
% =========================================================

if ispc
    rootDir = '\\cbsu\data\imaging_new\correia\da05\students\mohith\Gagnepain2017JoN';
else
    rootDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';

    addpath(genpath('/imaging/correia/da05/students/mohith/Gagnepain2017JoN/code'))
    addpath('/imaging/local/software/spm_cbu_svn/releases/spm12_latest/')
end

% -------------------------------------------------------------------------
%% DEFINE PARAMETERS
% -------------------------------------------------------------------------

% first level location
param.model = 'model01';
param.statPath = fullfile(rootDir, 'results', 'spm_first-level','MNI', param.model);

% subject IDs
param.subjID = cellstr(spm_select('List', param.statPath, 'dir'));

% where to save
param.savePath = fullfile(rootDir, 'results', 'spm_group-level', param.model);
if ~exist(param.savePath, 'dir')
    mkdir(param.savePath);
end

% conditions and contrasts
param.conditions = {'T', 'NI', 'I'};
param.contrasts = {
    'Effects of interest', 0 0 0; % will be defined later
    'T > NT',   1   -0.5   -0.5;
    'NT > T',  -1   0.5     0.5;
    'NI > I',   0    1      -1;
    'I > NI',   0   -1       1;
    'T > NI',   1   -1       0;
    'NI > T',   -1   1       0;
    'T > I',    1    0      -1;
    'I > T',   -1    0       1
    };

% -------------------------------------------------------------------------
% save parameters
save(fullfile(param.savePath, [param.model '_parameters.mat']), 'param'); 

%% DESIGN
% find which contrasts in the first-level these are
exampleSPM = load(fullfile(param.statPath, param.subjID{1}, 'SPM.mat'));
for c = 1:numel(param.conditions)
    thic = find(strcmp({exampleSPM.SPM.xCon.name}, param.conditions{c}));
    param.condfiles{1,c} = {['con_00' num2str(thic,'%02.f') '.nii']};
end

matlabbatch{1}.spm.stats.factorial_design.dir = {param.savePath};

for i = 1 : size(param.subjID, 1)
    for c = 1:numel(param.conditions)
        matlabbatch{1}.spm.stats.factorial_design.des.anovaw.fsubject(i).scans(c,1) = fullfile(param.statPath, param.subjID{i}, param.condfiles{1,c});
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

spm_jobman('run', matlabbatch);
clear matlabbatch

%% ESTIMATE
matlabbatch{1}.spm.stats.fmri_est.spmmat            = {fullfile(param.savePath, 'SPM.mat')};
matlabbatch{1}.spm.stats.fmri_est.write_residuals   = 0;
matlabbatch{1}.spm.stats.fmri_est.method.Classical  = 1;

spm_jobman('run', matlabbatch);
clear matlabbatch

%% CONTRASTS
matlabbatch{1}.spm.stats.con.spmmat = {fullfile(param.savePath, 'SPM.mat')};

% F contrast
matlabbatch{1}.spm.stats.con.consess{1}.fcon.name       = param.contrasts{1,1};
matlabbatch{1}.spm.stats.con.consess{1}.fcon.weights    = detrend(eye(numel(param.conditions)), 0);
matlabbatch{1}.spm.stats.con.consess{1}.fcon.sessrep    = 'repl';

% T contrasts
for contr = 2:size(param.contrasts,1)    
    matlabbatch{1}.spm.stats.con.consess{contr}.tcon.name       = param.contrasts{contr,1};
    matlabbatch{1}.spm.stats.con.consess{contr}.tcon.weights    = cell2mat(param.contrasts(contr,2:end));
    matlabbatch{1}.spm.stats.con.consess{contr}.tcon.sessrep    = 'repl';
end

matlabbatch{1}.spm.stats.con.delete = 0;
spm_jobman('run', matlabbatch);
