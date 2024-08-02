#!/usr/bin/env bash

# TODO: reference GFDL MDTF install
mdtf_dir=/home/oar.gfdl.mdtf/mdtf/MDTF-diagnostics
#mdtf_dir=/home/Jacob.Mims/mdtf/MDTF-diagnostics

# handle arguments
if [[ $# -eq 0 ]] ; then
    echo "USAGE: sh run-mdtf.sh /path/to/pp/dir/pp"
    exit 0
fi
if [ -d $1 ]; then
   ppdir=$1
else
   echo "ERROR: $1 is not a directory"
   echo "USAGE: sh run-mdtf.sh /path/to/pp/dir/pp"
   exit
fi

# check to see if catalog exists
#  ^..^
# /o  o\   
# oo--oo~~~
echo "looking for catalog in $ppdir"
cat=$(grep -s -H "esmcat_version" $ppdir/*.json  | cut -d: -f1)
if [[ "$cat" == "" ]]; then
   exit #TODO: fix catalog builder for given dir
   #generate catalog
   echo "catalog not found in $ppdir, building new one"
   config="- /path/to/pp/dir/pp"
   config_edit="- ${ppdir::-1}"
   sed -e "s|$config|$config_edit|ig" ./cat_build_config.yml > cat_config.yml
   config="output_dir:"
   config_edit="output_dir: ${ppdir::-1}"
   sed -i "s|$config|$config_edit|ig" ./cat_config.yml
   python3 "$mdtf_dir"/tools/catalog_builder/catalog_builder.py --config cat_config.yml
   cat="${ppdir}cat.json"
   echo "new catalog: $cat"
else
   echo "found catalog: $cat"
fi

# launch mdtf
config='"DATA_CATALOG": "",'
config_edit='"DATA_CATALOG": "'"${cat}"'",'
sed -e "s|$config|$config_edit|ig" ./amip_runtime.jsonc > config.jsonc
echo "edited DATA_CATALOG in config file"
echo "launching MDTF"

"$mdtf_dir"/mdtf -f config.jsonc
# move results to nbhome