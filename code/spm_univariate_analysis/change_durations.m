function change_durations()
% CHANGE_DURATIONS Load SPM onset files, set durations to 0, and save new files
%
% This script:
% 1. Finds all SPM definition files (*_spmdef.mat)
% 2. Sets all durations to 0
% 3. Saves new files with '_0s.mat' suffix

% Base directory containing subject folders
base_dir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/data/derivatives/for-spm-firstlevel';

% Find all subject directories
subjects = dir(fullfile(base_dir, 'sub-*'));

for i = 1:length(subjects)
    % Get subject folder path
    sub_dir = fullfile(base_dir, subjects(i).name, 'func');
    
    % Find all SPM definition files for this subject
    spm_files = dir(fullfile(sub_dir, '*_spmdef.mat'));
    
    for j = 1:length(spm_files)
        % Load the SPM definition file
        input_file = fullfile(sub_dir, spm_files(j).name);
        data = load(input_file);
        
        % Change all durations to 0
        for k = 1:length(data.durations)
            data.durations{k}(:) = 0;
        end
        
        % Create new filename with _0s suffix
        [path, name, ~] = fileparts(input_file);
        output_file = fullfile(path, [name '_0s.mat']);
        
        % Save modified data
        names = data.names;
        onsets = data.onsets;
        durations = data.durations;
        save(output_file, 'names', 'onsets', 'durations');
        
        fprintf('Processed: %s\n', spm_files(j).name);
    end
end

fprintf('Done! All files processed.\n');
end