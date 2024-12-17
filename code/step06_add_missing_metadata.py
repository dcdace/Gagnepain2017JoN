# From all func metadata files get PhaseEncodingSteps and calculate the TotalReadoutTime
# as TotalReadoutTime = AssumedEchoSpacing * (PhaseEncodingSteps - 1) where the AssumedEchoSpacing is 0.000525004
# Add to the medatada file the TotalReadoutTime and "EffectiveEchoSpacing": 0.000525004

# This is necessary for the fmriprep suseptibility distortion correction
# The assumed echo spacing is based on the average values from two other Siemens datasets with known echo spacing values

import json
from bids.layout import BIDSLayout

bida_data_dir = '/imaging/correia/da05/students/mohith/Gagnepain2017JoN/data'

# Define the AssumedEchoSpacing
AssumedEchoSpacing = 0.000525004

layout = BIDSLayout(bida_data_dir, validate=False)

# Get all the func file metadata
func_metadata = layout.get(suffix='bold', extension='json', return_type='file')

for metadata_file in func_metadata:
    with open(metadata_file, 'r') as f:
        metadata = json.load(f)
    
    # Calculate the TotalReadoutTime
    TotalReadoutTime = AssumedEchoSpacing * (metadata['PhaseEncodingSteps'] - 1)
    
    # Add the TotalReadoutTime and "EffectiveEchoSpacing": 0.000525004 to the metadata file
    metadata['TotalReadoutTime'] = TotalReadoutTime
    metadata['EffectiveEchoSpacing'] = 0.000525004
    
    with open(metadata_file, 'w') as f:
        json.dump(metadata, f, indent=4)
        
    print(f"Added TotalReadoutTime and EffectiveEchoSpacing to {metadata_file}")
    
print("Done!")


