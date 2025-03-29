function nuisancefileOutput = createNuisanceParameter_noConstant(nRuns, confounds, nscans, saveDir)


% confounds_per_run = struct with confound regressors (e.g., movement
% parameters) per run.
% nscans = vector of the nb of vol per session (e.g. [200, 250, ..., 220];

nTrends = 7; % number of trends
nConfounds = size(confounds(1).C, 2); % number of confounds (assumes equal for all runs)
nVolumes = sum(nscans); % number of total volumes across all runs

R = zeros(nVolumes,(nRuns*nTrends)+(nRuns*nConfounds));

col_idx = (1:nTrends:(nRuns*nTrends)+1);

row_idx = zeros(1, nRuns+1);
for i = 1:(nRuns+1)
    
    if i == 1
        row_idx(i) = 1;
    elseif i > 1
        row_idx(i) = (sum(nscans(1:i-1))+1);
    end
    
end

% add trend parameters
for s = 1:nRuns
    trendX = generateTrendModel(nscans(s),3,1,0);
    size(trendX)
    R (row_idx(s):row_idx(s+1)-1,col_idx(s):col_idx(s+1)-1) = trendX;
end

% add motion paramater
col_idx = (col_idx(end):nConfounds:((nRuns*nTrends)+(nRuns*nConfounds))+1);

for s = 1:nRuns
    R (row_idx(s):row_idx(s+1)-1,col_idx(s):col_idx(s+1)-1) = confounds(s).C;
end

nuisancefileOutput = fullfile(saveDir,'iRSAnuisanceparametersX.mat');
save(nuisancefileOutput,'R');

