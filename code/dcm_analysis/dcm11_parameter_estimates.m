% =========================================================================
% DCM Parameter Estimation for Bayesian Model Averaging (BMA)
% =========================================================================
% Author: Dace Apsvalka, @CBU 2025
%
% Description:
%   This script extracts and visualises parameter estimates from DCM 
%   Bayesian Model Averaging (BMA) results. It plots intrinsic connections
%   (A matrix), modulatory effects (B matrix), and driving inputs (C matrix)
%   with confidence intervals.
%
% Outputs:
%   - PNG file with parameter estimates and confidence intervals
%   - MAT file with parameter estimates for A, B, and C matrices
%
% Requirements:
%   - SPM12 must be added to the MATLAB path
%   - BMS.mat file must exist in the appropriate directory
%
% Usage:
%   Run the script from MATLAB or command line:
%   matlab -nodisplay -nosplash -r "dcm11_parameter_estimates; exit;"
% =========================================================================

% Clear workspace and close all figures
clearvars; close all

% Add SPM to path
spmPath = '/imaging/local/software/spm_cbu_svn/releases/spm12_latest/';
if ~exist(spmPath, 'dir')
    error('SPM12 directory not found. Please check the path: %s', spmPath);
end
addpath(spmPath);

% Configuration parameters
param.modelDir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/results/DCM/rDLPFC01_rHC300_TNT_model_00_RolandsNeuronSpace_not_center';
png_fsave = fullfile(param.modelDir, 'BMA_parameters.png');
mat_fsave = fullfile(param.modelDir, 'BMA_parameters.mat');

modCond = 2; % Looking at the 2nd condition only in the B matrix (NT)

% Set text interpreter to display underscores properly
set(0, 'DefaultTextInterpreter', 'none')

% Check if model directory exists
if ~exist(param.modelDir, 'dir')
    error('Model directory not found: %s', param.modelDir);
end

fprintf('Analyzing parameter estimates from BMA results...\n');

% Locate the BMS.mat and model space files
fbms = fullfile(param.modelDir, 'All', 'BMS.mat');
fspace = fullfile(param.modelDir, 'All', 'model_space.mat');

if ~exist(fbms, 'file')
    error('BMS.mat file not found: %s', fbms);
end
if ~exist(fspace, 'file')
    error('model_space.mat file not found: %s', fspace);
end

% Load the BMS and model space data
fprintf('Loading BMS and model space data...\n');
load(fbms);
load(fspace);

% Load one model specification file to get the names of parameters

if ~exist(subj(1).sess.model(1).fname, 'file')
    error('Model file not found: %s', subj(1).sess.model(1).fname);
end
load(subj(1).sess.model(1).fname, 'DCM');

% Get the sample size
N = size(BMS.DCM.rfx.bma.mEps, 2);
fprintf('Found %d subjects\n', N);

% Get the condition names
if ~isfield(DCM, 'U') || ~isfield(DCM.U, 'name')
    error('Condition names not found in DCM structure');
end
conditions = DCM.U.name;
fprintf('Conditions: %s\n', strjoin(conditions, ', '));

% Get the ROI names
ROIs = {'DLPFC', 'HC'}; % DCM.xY.name;
fprintf('ROIs: %s\n', strjoin(ROIs, ', '));

% Get all connections
fprintf('Preparing connection labels...\n');
[nodes1, nodes2] = meshgrid(ROIs, ROIs);
connections = arrayfun(@(x) [nodes1{x} '->' nodes2{x}], 1:numel(ROIs)^2, 'UniformOutput', false);
lablesCon = reordercats(categorical(connections), connections);

% Get all inputs
[cond, nodes] = meshgrid(conditions, ROIs);
inputs = arrayfun(@(x) [cond{x} '->' nodes{x}], 1:numel(conditions)*numel(ROIs), 'UniformOutput', false);
lablesInp = reordercats(categorical(inputs), inputs);

% Extract parameter values from all participants
fprintf('Extracting parameter values from all participants...\n');

% A matrix values (intrinsic connections)
fprintf('  Extracting A matrix values...\n');
dataA = zeros(N, numel(ROIs)^2);
for n = 1:N
    aMat = full(BMS.DCM.rfx.bma.mEps{1,n}.A);
    dataA(n, :) = reshape(aMat, 1, numel(aMat));
end

% B matrix values (modulatory effects)
fprintf('  Extracting B matrix values...\n');
dataB = zeros(N, numel(ROIs)^2);
for n = 1:N
    if length(DCM.U.name) > 1
        bMat = full(BMS.DCM.rfx.bma.mEps{1,n}.B(:,:,modCond));
    else
        bMat = full(BMS.DCM.rfx.bma.mEps{1,n}.B(:,:));
    end
    dataB(n, :) = reshape(bMat, 1, numel(bMat));
end

% C matrix values (driving inputs)
fprintf('  Extracting C matrix values...\n');
dataC = zeros(N, numel(ROIs)*numel(conditions));
for n = 1:N
    cMat = full(BMS.DCM.rfx.bma.mEps{1,n}.C);
    dataC(n, :) = reshape(cMat, 1, numel(cMat));
end

% Plot the parameter estimates
fprintf('Plotting parameter estimates...\n');
figure('Position', get(0, 'ScreenSize')); % Fullscreen
set(gcf, 'color', 'w');
suptitle('BMA of all models');

% Plot A matrix (intrinsic connections)
subplot(1, 3, 1);
plotmeans(dataA, lablesCon, 'Intrinsic (A)');

% Plot B matrix (modulatory effects)
subplot(1, 3, 2);
plotmeans(dataB, lablesCon, [conditions{modCond} ' modulation (B)']);

% Plot C matrix (driving inputs)
subplot(1, 3, 3);
plotmeans(dataC, lablesInp, 'Inputs (C)');

% Save figure
fprintf('Saving figure to: %s\n', png_fsave);
saveas(gcf, png_fsave);

fprintf('Analysis complete!\n');

% Save data to .mat file
save(mat_fsave, 'dataA', 'dataB', 'dataC');

% Helper function to plot means with error bars
function plotmeans(data, lables, titletxt)
    % Calculate mean and 95% confidence intervals
    M = mean(data);
    SEM = std(data)/sqrt(size(data, 1))*1.96; % 95% CI
    
    % Create bar plot
    b = bar(lables, M, 0.9, 'FaceColor', 'flat');
    
    % Color code the bars based on sign
    for k = 1:numel(M)
        if M(k) > 0
            b.CData(k, :) = [1 1 0];  % Yellow for positive values
        else
            b.CData(k, :) = [0 153/255 1];  % Blue for negative values
        end
    end
    
    title(titletxt);
    
    % Add error bars
    hold on;
    er = errorbar(lables, M, SEM);
    er.Color = [0 0 0];
    er.LineStyle = 'none';
    hold off;
end

