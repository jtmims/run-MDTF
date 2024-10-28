#!/bin/bash -f
#SBATCH --job-name=run-MDTF.sh
#SBATCH --time=4:00:00
#set -x

# dir references
run_dir=/nbhome/Jacob.Mims/run-MDTF
mdtf_dir=/home/oar.gfdl.mdtf/mdtf/MDTF-diagnostics
#mdtf_dir=/home/Jacob.Mims/mdtf/MDTF-diagnostics for testing
genintakegfdl=/home/Jacob.Mims/CatalogBuilder/catalogbuilder/scripts/gen_intake_gfdl.py

#TEST: /archive/jpk/fre/FMS2024.02_OM5_20240819/CM4.5v01_om5b06_piC_noBLING_xrefine_test4/gfdl.ncrc5-intel23-prod-openmp/pp/

#TEST 2: /archive/djp/am5/am5f7b12r1/c96L65_am5f7b12r1_amip/gfdl.ncrc5-intel23-classic-prod-openmp/pp/

# handle arguments
if [[ $# -ne 4 ]] ; then
    echo "USAGE: sh run-mdtf.sh /path/to/pp/dir/pp out_dir/mdtf startyr endyr"
    exit 0
fi
if [ -d $1 ]; then
   ppdir=$1
else
   echo "ERROR: $1 is not a directory"
   echo "USAGE: sh run-mdtf.sh /path/to/pp/dir/pp out_dir/mdtf startyr endyr"
   exit
fi
if [ -d $2 ]; then
   outdir=$2
else
   mkdir -p $2
   outdir=$2
fi
startyr=$3
endyr=$4

# check to see if catalog exists
#  ^..^
# /o  o\   
# oo--oo~~~
echo "looking for catalog in $ppdir"
cat=$(grep -s -H "esmcat_version" $ppdir/*.json  | cut -d: -f1)
if [[ "$cat" == "" ]]; then
   activate=/home/oar.gfdl.mdtf/miniconda3/bin/activate
   env=/nbhome/Aparna.Radhakrishnan/conda/envs/catalogbuilder
   source $activate $env 
   python $genintakegfdl $ppdir $outdir/catalog
   cat=$outdir/catalog.json
   echo "new catalog generated: $cat"
else
   echo "found catalog: $cat"
fi

# handle atmos_cmip PODs
cp $run_dir/config/atmos_cmip_config.jsonc $outdir/atmos_cmip_config.jsonc
config='"DATA_CATALOG": "",'
config_edit='"DATA_CATALOG": "'"${cat}"'",'
sed -i "s|$config|$config_edit|ig" $outdir/atmos_cmip_config.jsonc
config='"WORK_DIR": "",'
config_edit='"WORK_DIR": "'"${outdir}"'",'
sed -i "s|$config|$config_edit|ig" $outdir/atmos_cmip_config.jsonc
config='"startdate": "",'
config_edit='"startdate": "'"${startyr}"'",'
sed -i "s|$config|$config_edit|ig" $outdir/atmos_cmip_config.jsonc
config='"enddate": ""'
config_edit='"enddate": "'"${endyr}"'"'
sed -i "s|$config|$config_edit|ig" $outdir/atmos_cmip_config.jsonc
echo "edited atmos_cmip config file"
echo "launching MDTF with atmos_cmip config file"
"$mdtf_dir"/mdtf -f $outdir/atmos_cmip_config.jsonc

exit 0
