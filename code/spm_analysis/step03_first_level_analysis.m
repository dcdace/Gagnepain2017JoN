% ======================================================================
% dace.apsvalka@mrc-cbu.cam.ac.uk (2023)
% Based on https://www.frontiersin.org/articles/10.3389/fnins.2019.00300/full
%
% Preprocessing fMRI data. Assumes that data is in BIDS standard. 
%
% =========================================================

% Add path to SPM12 and preprocessing scripts
addpath('/imaging/local/software/spm_cbu_svn/releases/spm12_latest/')
addpath('/imaging/correia/da05/students/mohith/Gagnepain2017JoN/code/spm_analysis')

% =========================================================
% DEFINE DATAPATHS PARAMETERS
% =========================================================

% Location of the BIDS dataset
param.BIDS = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/data';
% Location of the preprocessed data
param.datadir = fullfile(param.BIDS, 'derivatives', 'SPM12');
% Where to save the results
param.outpth = fullfile('/imaging/correia/da05/students/mohith/Gagnepain2017JoN/', 'results', 'SPM12', 'first_level', 'model01');

% Which functional task
param.task = 'tnt';

% =========================================================
% DEFINE FIRST-LEVEL MODEL PARAMETERS
% =========================================================

subs = cellstr(spm_select('List', param.datadir, 'dir','^sub-'));

% Retrieve metadata
metadata = spm_BIDS(param.BIDS,'metadata', 'sub', subs{1}, 'run', '01', 'task', param.task, 'type', 'bold');

% Define parameters
param.TR         = metadata.RepetitionTime;
param.hpf        = 128;
param.hrf_derivs = [1 1]; % time and dispersion	derivatives
param.nDummy     = 0;

% If Slice-time correction was performed at preprocessing, need to specify
% the number of sclices and the reference slice.
% Reference slice was a slice that was acquired at the middle of TR
param.nslices   = length(metadata.SliceTiming);
[~, idx] = sortrows(metadata.SliceTiming); % get the slice acquisition order
param.ref_slice = idx(floor(param.nslices/2)); % finds the middle slice in time

% =========================================================
% DEFINE CONTRAST PARAMETERS
% =========================================================
param.conditions = {'negT', 'negNTi', 'negNTni', 'neutrT', 'neutrNTi', 'neutrNTni'};

param.contrast_names = {
    'negT' ...
    'negNTi' ...
    'negNTni' ...
    'neutrT' ...
    'neutrNTi' ...
    'neutrNTni'
    };

% Because we are adding time and dipersion derivatives, each condition
% has 2 extra regressors; and we are also adding 6 movement parameters.

param.contrasts = {
    [1 0 0  0 0 0   0 0 0   0 0 0   0 0 0   0 0 0   0 0 0 0 0 0] ... % negT
    [0 0 0  1 0 0   0 0 0   0 0 0   0 0 0   0 0 0   0 0 0 0 0 0] ... % negNTi
    [0 0 0  0 0 0   1 0 0   0 0 0   0 0 0   0 0 0   0 0 0 0 0 0] ... % negNTni
    [0 0 0  0 0 0   0 0 0   1 0 0   0 0 0   0 0 0   0 0 0 0 0 0] ... % neutrT
    [0 0 0  0 0 0   0 0 0   0 0 0   1 0 0   0 0 0   0 0 0 0 0 0] ... % neutrNTi
    [0 0 0  0 0 0   0 0 0   0 0 0   0 0 0   1 0 0   0 0 0 0 0 0] ... % neutrNTni
    };

% param.eof_contrast = [
%     1 0 0  0 0 0   0 0 0   0 0 0   0 0 0   0 0 0   0 0 0 0 0 0
%     0 0 0  1 0 0   0 0 0   0 0 0   0 0 0   0 0 0   0 0 0 0 0 0
%     0 0 0  0 0 0   1 0 0   0 0 0   0 0 0   0 0 0   0 0 0 0 0 0
%     0 0 0  0 0 0   0 0 0   1 0 0   0 0 0   0 0 0   0 0 0 0 0 0
%     0 0 0  0 0 0   0 0 0   0 0 0   1 0 0   0 0 0   0 0 0 0 0 0
%     0 0 0  0 0 0   0 0 0   0 0 0   0 0 0   1 0 0   0 0 0 0 0 0
% ];

% =========================================================
% Number of workers for distributed computing (
numworkers = 0; % 12 is max at the CBU
if numworkers
    parpool(numworkers);
end

% =========================================================
% FIRST-LEVEL ANALYSIS FOR ALL SUBJECTS
% =========================================================
% Get all subject IDs
subs = cellstr(spm_select('List',param.datadir, 'dir','^sub-'));
nsub = numel(subs);

% Loop through subjects
%parfor (s = 1:nsub, numworkers)
for s=1
    
    sub = subs{s};
    
    do_first_level(param, sub);
    
end

