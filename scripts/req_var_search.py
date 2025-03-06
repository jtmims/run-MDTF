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
runnable_pods = {}
requested_pods=[]

# grab requested PODs from cli
if len(sys.argv) > 4:
    for i in range (4, len(sys.argv)):
        requested_pods.append(sys.argv[i])
if len(requested_pods) > 0:
    print(f"LOG: user requested PODs {requested_pods}")

#search catalog for required variables, if not there throw out POD
for p in req_vars:
    if len(requested_pods) > 0 and p not in requested_pods:
        continue
    pod_passed[p] = True
    query = {}
    query['realm'] = req_vars[p]['realm']
    query['frequency'] = req_vars[p]['frequency']
    for v in req_vars[p]['vars']:
        query['variable_id'] = v
        result = cat.search(**query)
        if result.df.empty:
            pod_passed[p] = False
            print(f'WARNING: catalog is missing variable {v}; skipping POD {p}!')
    if pod_passed[p] == True:
        del req_vars[p]['vars']
        runnable_pods[p] = req_vars[p]

# write out list of PODs to add to config files
with open(sys.argv[3]+"runnable_pods.json", "w") as f:
    f.write(json.dumps(runnable_pods, indent=2))
