#!/bin/bash -f
#SBATCH --job-name=run-MDTF.sh
#SBATCH --time=4:00:00
#set -x

# dir references
run_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
mdtf_dir=/home/oar.gfdl.mdtf/mdtf/MDTF-diagnostics
#mdtf_dir=/home/Jacob.Mims/mdtf/MDTF-diagnostics
activate=/home/oar.gfdl.mdtf/miniconda3/bin/activate

#TEST: /archive/jpk/fre/FMS2024.02_OM5_20240819/CM4.5v01_om5b06_piC_noBLING_xrefine_test4/gfdl.ncrc5-intel23-prod-openmp/pp/ starts 0001

#TEST 2: /archive/djp/am5/am5f7b12r1/c96L65_am5f7b12r1_amip/gfdl.ncrc5-intel23-classic-prod-openmp/pp/ starts 1990

usage() {
   echo "USAGE: run-mdtf.sh -i /path/to/pp/dir/pp -o out_dir/mdtf -s startyr -e endyr"
   echo "the -p option can be used to select which PODs to run instead of all"   
}

# handle arguments
declare -a pods=()
while getopts "hi:o:s:e:p:" arg; do
   case "${arg}" in
      h) 
         usage
	 exit 
         ;;
      i) 
         if [ -d $OPTARG ]; then
            ppdir="${OPTARG}"
         else
            echo "ERROR: $1 is not a directory"
            usage
            exit
         fi
         ;;
      o)
         if [ -d "${OPTARG}" ]; then
            outdir="${OPTARG}"
         else
            mdkir -p "${OPTARG}"
            outdir="${OPTARG}"
         fi
         ;;      
      s)
        startyr="${OPTARG}"
        ;;
      e)
        endyr="${OPTARG}"
        ;;
      p)
        pods+=("$OPTARG")
        ;;
   esac
done
shift $((OPTIND-1))
if ! [ -d $outdir/config ]; then
   mkdir -p $outdir/config
fi

# check to see if catalog exists
#  ^..^
# /o  o\   
# oo--oo~~~
echo "looking for catalog in $ppdir"
cat=$(grep -s -H "esmcat_version" $ppdir/*.json  | cut -d: -f1)
if [[ "$cat" == "" ]]; then
   env=/nbhome/fms/conda/envs/fre-2025.01
   source $activate $env
   fre catalog builder --overwrite $ppdir $outdir/catalog 
   #python $run_dir/scripts/cat_builder.py $catbuilddir $ppdir $outdir/catalog
   cat=$outdir/catalog.json
   echo "new catalog generated: $cat"
else
   echo "found catalog: $cat"
fi

# search catalog for pod requirements
env=/home/oar.gfdl.mdtf/miniconda3/envs/_MDTF_base
source $activate $env
python $run_dir/scripts/req_var_search.py $cat $run_dir/data/ $outdir/ "${pods[@]}"

# edit template config file
cp $run_dir/config/template_config.jsonc $outdir
f=$outdir/template_config.jsonc
if [ ! -f $f ]; then
   echo "ERROR: failed to find $f; error with req_var_search.py"
   exit 0
fi
config='"DATA_CATALOG": "",'
config_edit='"DATA_CATALOG": "'"${cat}"'",'
sed -i "s|$config|$config_edit|ig" $f
config='"WORK_DIR": "",'
config_edit='"WORK_DIR": "'"${outdir}"'",'
sed -i "s|$config|$config_edit|ig" $f
config='"startdate": "",'
config_edit='"startdate": "'"${startyr}"'",'
sed -i "s|$config|$config_edit|ig" $f
config='"enddate": ""'
config_edit='"enddate": "'"${endyr}"'"'
sed -i "s|$config|$config_edit|ig" $f
echo "edited file $f"

#generate config files
python $run_dir/scripts/gen_config.py $outdir/

# launch the mdtf with the config files
for f in $(ls ${outdir}/config) ; do
   echo "launching MDTF with $f"
   "$mdtf_dir"/mdtf -f $outdir/config/$f
done

# consolidate into a single output folder
mapfile -t pods < $run_dir/data/pods.txt
for od in "$outdir"/"MDTF_output.v"*; do
   for pd in $od/*; do
      if [ -d $pd ]; then
         pod=$(basename "$pd")
         for name in ${pods[@]}; do
            if [[ "$pod" == "$name" ]]; then
              mv $pd "$outdir"/"MDTF_output"
            fi
         done
      fi
   done
   if [ -f "$od"/"index.html" ]; then
      cat "$od"/"index.html" >> "$outdir"/"MDTF_output"/"index.html"
   fi
   rm -rf $od
done

exit 0
