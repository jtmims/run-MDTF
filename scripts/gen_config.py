# script to make the MDTF runtime configs for each realm/freq to run requested PODs
import sys
import os
import json

# load pod information
with open(sys.argv[2]+'runnable_pods.json') as f:
    pods = json.load(f)

# load template config information
with open(sys.argv[1]+'template_config.jsonc') as f:
    template_config = json.load(f)    

# get list of requested config file names and create dict objects for each
config_names = set([f"{pods[p]['realm']}_{pods[p]['frequency']}_config" for p in pods])
config_files = {}
for c in config_names:
    config_files[c] = template_config    

# add pods to cooresponding config file
for p in pods:
    config_file = f"{pods[p]['realm']}_{pods[p]['frequency']}_config"    
    config_files[config_file]['pod_list'].append(p) 

for c in config_files:
    with open(sys.argv[2]+f"{c}.jsonc", "w") as f:
        f.write(json.dumps(config_files[c], indent=2))     
