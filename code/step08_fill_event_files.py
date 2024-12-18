from pathlib import Path
import pandas as pd
from bids import BIDSLayout

# Define paths
bids_dataset_path = Path('/imaging/correia/da05/students/mohith/Gagnepain2017JoN/data')
source_events_path = Path("/imaging/anderson/archive/users/pg02/Exp1/onset_files")

# Initialize the BIDS layout
layout = BIDSLayout(bids_dataset_path)

# Get all BIDS events files
events_files = layout.get(suffix='events', extension='tsv', return_type='file')

# Conditions and filters
conditions = {
    'negT': {'condition_img': 'ENEG', 'trial_type': 'r', 'intrusion': 1},
    'negNTi': {'condition_img': 'ENEG', 'trial_type': 's', 'intrusion': 1},
    'negNTni': {'condition_img': 'ENEG', 'trial_type': 's', 'intrusion': 0},
    'neutrT': {'condition_img': 'ENEU', 'trial_type': 'r', 'intrusion': 1},
    'neutrNTi': {'condition_img': 'ENEU', 'trial_type': 's', 'intrusion': 1},
    'neutrNTni': {'condition_img': 'ENEU', 'trial_type': 's', 'intrusion': 0}
}

# Header for the source event file and the new output file
source_header = ['trial', 'cue_img', 'condition_img', 'trial_type', 'intrusion_rating', 
                 'intrusion', 'RT', 'onset', 'duration', 'run']

new_header = ['onset', 'duration', 'trial_type', 'response_time', 'stim_file']

# Process each BIDS events file
for events_file_path in events_files:
    # Extract subject and run from BIDS file name
    entities = layout.parse_file_entities(events_file_path)
    subj = entities.get('subject', 'unknown')
    run = entities.get('run', 1)  # Default to run 1 if run is not present

    print(f"\nProcessing subject {subj} - run {run} - file: {events_file_path}")

    # Locate the matching source Excel file
    try:
        source_event_file = next(source_events_path.glob(f"{subj}*.xls"))
    except StopIteration:
        print(f"No source Excel file found for subject {subj} in {source_events_path}")
        continue
    
    # Load the event file from source
    try:
        events = pd.read_excel(source_event_file, header=None)
        events.columns = source_header
    except Exception as e:
        print(f"Error reading Excel file for subject {subj}: {e}")
        continue
    
    # Filter for the specific run using the BIDS file run number
    events_for_run = events[events['run'] == run]
    if events_for_run.empty:
        print(f"No events found for subject {subj}, run {run} in {source_event_file}")
        continue
    
    # Create a DataFrame to store new events
    new_events = pd.DataFrame({
        'onset': pd.Series(dtype='float64'),
        'duration': pd.Series(dtype='float64'),
        'trial_type': pd.Series(dtype='object'),
        'response_time': pd.Series(dtype='float64'),
        'stim_file': pd.Series(dtype='object')
    })

    # Process each condition
    for condition_name, condition_criteria in conditions.items():
        # Filter data for the current run and condition
        filtered_events = events_for_run[
            (events_for_run['condition_img'].str.contains(condition_criteria['condition_img'], na=False)) & 
            (events_for_run['trial_type'].str.contains(condition_criteria['trial_type'], na=False)) & 
            (events_for_run['intrusion'] == condition_criteria['intrusion'])
        ]

        if not filtered_events.empty:
            # Construct DataFrame for this condition
            new_data = pd.DataFrame({
                'onset': filtered_events['onset'] / 1000,  # convert ms to seconds
                'duration': 0, #filtered_events['duration'], # set duration to 0
                'trial_type': condition_name,
                'response_time': filtered_events['RT'],
                'stim_file': filtered_events['condition_img']
            })
            
            # Concatenate with the main DataFrame
            new_data = new_data.reindex(columns=new_events.columns)  # Align columns
            if not new_data.empty and not new_data.isna().all(axis=None):
                new_events = pd.concat([new_events, new_data], ignore_index=True)
    
    # Sort the events by onset time
    new_events = new_events.sort_values(by='onset')
    
    # Save the resulting file in the same location, replacing the original
    try:
        new_events.to_csv(events_file_path, sep='\t', index=False)
        print(f"Replaced events file for subject {subj}, run {run} at {events_file_path}")
    except Exception as e:
        print(f"Error saving file for subject {subj}, run {run}: {e}")
