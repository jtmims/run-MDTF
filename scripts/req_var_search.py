# script to make sure that required variables exist in data catalog

import json
import sys
import os
import intake 

# load catalog
cat = intake.open_esm_datastore(sys.argv[1])

# load req_variables
with open(sys.argv[2]+"req_var.json") as f:
    req_vars = json.load(f)

pod_passed = {}

print('searching catalog for POD requirements')
for p in req_vars['pods']:
    pod_passed[p] = True
    query = {}
    query['realm'] = req_vars['pods'][p]['realm']
    query['frequency'] = req_vars['pods'][p]['frequency']
    for v in req_vars['pods'][p]['vars']:
        query['variable_id'] = v
        result = cat.search(**query)
        if result.df.empty:
            pod_passed[p] = False
            print(f'WARNING: catalog is missing variable {v}; skipping POD {p}!')

with open(sys.argv[2]+"runnable_pods.txt", "w") as f:
    for p in pod_passed:
        if pod_passed[p] == True:
            f.write(p + "\n")
