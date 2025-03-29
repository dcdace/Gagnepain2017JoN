% =========================================================================
% DCM Preparation: Create Concatenated Onset Files
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script creates concatenated onset files for DCM analysis by
%   combining onsets across all runs. It handles conditions of interest,
%   nuisance conditions, and border conditions (near session boundaries).
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - First-level analysis must be completed
%
% Outputs:
%   - MATLAB .mat files containing:
%     * names: Condition names
%     * onsets: Onset times (in seconds)
%     * durations: Event durations
%     * nscans: Number of scans per session
%     * TR: Repetition time
%
% Usage:
%   Run the script from the command line using:
%   matlab -nodisplay -nosplash -r "dcm01_create_onsets_uNT; exit;"
% =========================================================================


%% ========================================================
% SET THE PARAMETERS
% =========================================================

rootDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN';

% Output directory for onset files
param.outPath = fullfile(rootDir, 'data', 'derivatives', 'for-dcm');

% In which first-level results to look for the SPM.mat
param.stats       = 'model_01';

% Path to the first-level analysis results
param.statsPath = fullfile(rootDir, 'results', 'spm_first-level', 'native', param.stats);

% conditions of interest
param.conditions  = {'negNTi', 'negNTni', 'neutrNTi', 'neutrNTni', 'negT', 'neutrT'};

%% ========================================================
% Add paths to the required functions and toolboxes
% =========================================================
addpath(genpath(fullfile(rootDir, 'code')));
addpath('/imaging/local/software/spm_cbu_svn/releases/spm12_latest/')

% =========================================================
% CREATE ONSETS FOR EACH SUBJECT
% =========================================================

% Get the subject IDs
param.subjID = cellstr(spm_select('List', param.statsPath, 'dir', '^sub-'));
nsub = size(param.subjID,1);

for s = 1 : nsub
    disp(param.subjID{s})

    [names, onsets, durations] = deal([]);

    % Load SPM.mat file
    fspm = fullfile(param.statsPath, param.subjID{s}, 'SPM.mat');
    if ~exist(fspm, 'file')
        sprintf('SPM file does not exist! \n%s', fspm)
    else
        load(fspm)
    end

    nscans      = SPM.nscan;
    TR          = SPM.xY.RT;

    %% DETERMIN THE CONDITIONS

    % identify a session with the max number of conditions
    condPerSess = arrayfun(@(x) size(SPM.Sess(x).U,2), 1:length(SPM.Sess));
    maxSess     = find(condPerSess==max(condPerSess));

    % get the names of all conditions
    condNames    = [SPM.Sess(maxSess(1)).U.name];

    % create empty ons and dur arrays. It will be conditions of interest, and other
    % conditions other than defined in param.conditions
    otherConds  = setdiff(condNames, param.conditions);
    tmp.name    = ['u', 'NT', otherConds];

    nCond       = length(tmp.name);
    tmp.ons     = cell(1, nCond);
    tmp.dur     = cell(1, nCond);

    [borderOns, borderDur] = deal([]);
    for sess = 1 : size(nscans,2)
        %% remove conditions from the session borders and add to Nuisance
        thisRunLenght = nscans(sess) * TR;
        if sess == size(nscans, 2) % don't remove anything from the last run
            brd = 0; % 24 second cutoff
        else
            brd = 24; % 24 second cutoff
        end
        cutoff = thisRunLenght - brd;
        %% ========================
        %% u condition
        condNr = 1;
        ind = find(ismember([SPM.Sess(sess).U.name], param.conditions));
        for j = 1 : length(ind)
            thisOns = SPM.Sess(sess).U(ind(j)).ons(SPM.Sess(sess).U(ind(j)).ons < cutoff) + sum(nscans(1:sess-1))* TR;
            tmp.ons{condNr}  = [tmp.ons{condNr};  thisOns];
            tmp.dur{condNr}  = [tmp.dur{condNr};  SPM.Sess(sess).U(ind(j)).dur(SPM.Sess(sess).U(ind(j)).ons < cutoff)];
            % Border conditions
            borderOns   = [borderOns; SPM.Sess(sess).U(ind(j)).ons(SPM.Sess(sess).U(ind(j)).ons > cutoff)  + sum(nscans(1:sess-1))* TR];
            borderDur   = [borderDur; SPM.Sess(sess).U(ind(j)).dur(SPM.Sess(sess).U(ind(j)).ons > cutoff)];
        end

        %% NT condition
        condNr = 2;
        ind = find(ismember([SPM.Sess(sess).U.name], {'negNTi', 'negNTni', 'neutrNTi', 'neutrNTni'}));
        for j = 1 : length(ind)
            thisOns     = SPM.Sess(sess).U(ind(j)).ons(SPM.Sess(sess).U(ind(j)).ons < cutoff) + sum(nscans(1:sess-1))* TR;
            tmp.ons{condNr}  = [tmp.ons{condNr};  thisOns];
            tmp.dur{condNr}  = [tmp.dur{condNr};  SPM.Sess(sess).U(ind(j)).dur(SPM.Sess(sess).U(ind(j)).ons < cutoff)];
            % Border conditions
            borderOns   = [borderOns; SPM.Sess(sess).U(ind(j)).ons(SPM.Sess(sess).U(ind(j)).ons > cutoff)  + sum(nscans(1:sess-1))* TR];
            borderDur   = [borderDur; SPM.Sess(sess).U(ind(j)).dur(SPM.Sess(sess).U(ind(j)).ons > cutoff)];
        end

        %% other conditions
        for j = 1 : length(otherConds)
            condNr = condNr + 1;
            % check if this condition exists in this run
            ind = find(strcmp([SPM.Sess(sess).U.name], otherConds{j}));
            if ~isempty(ind)
                thisOns = SPM.Sess(sess).U(ind).ons(SPM.Sess(sess).U(ind).ons < cutoff) + sum(nscans(1:sess-1))* TR;
                tmp.ons{condNr} = [tmp.ons{condNr}; thisOns];
                tmp.dur{condNr} = [tmp.dur{condNr}; SPM.Sess(sess).U(ind).dur(SPM.Sess(sess).U(ind).ons < cutoff)];
                % Border conditions
                borderOns    = [borderOns; SPM.Sess(sess).U(ind).ons(SPM.Sess(sess).U(ind).ons > cutoff)  + sum(nscans(1:sess-1))* TR];
                borderDur    = [borderDur; SPM.Sess(sess).U(ind).dur(SPM.Sess(sess).U(ind).ons > cutoff)];
            end
        end
    end

    %% make results for the existing conditions
    k = 0;
    for cond = 1 : nCond
        if ~isempty(tmp.ons{1,cond})
            k = k + 1;
            names{k}        = tmp.name{cond};
            onsets{k}       = tmp.ons{cond};
            durations{k}    = tmp.dur{cond};
        end
    end
    % Border conditions
    if ~isempty(borderOns)
        names{k+1}        = 'atBorder';
        onsets{k+1}       = borderOns;
        durations{k+1}    = borderDur;
    end

    %% save
    % Create the output directory
    if ~exist(fullfile(param.outPath, param.subjID{s}), 'dir')
        mkdir(fullfile(param.outPath, param.subjID{s}));
    end
    fsave = fullfile(param.outPath, param.subjID{s}, [param.stats '_uNT_concatinated_onsets.mat']);
    save(fsave, 'names','onsets','durations','nscans','TR');
end


