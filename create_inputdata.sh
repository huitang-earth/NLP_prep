#!/bin/bash

#SBATCH --account=nn2806k 
#SBATCH --job-name=mkmapdata
#SBATCH --mem-per-cpu=256G --partition=bigmem
#SBATCH --ntasks=1
#SBATCH --time=07:00:00

date="200927"         # Need to be the same as the running date
input_dir="/cluster/shared/noresm/inputdata_fates_platform" # home folder for storing the inputdata for each site. 
input_raw="/cluster/shared/noresm/inputdata"                # home folder for storing the raw date required by surface data file

######### SeedClim Sites
#plotlat=(61.0243 60.8231 60.8328 60.9335 60.8203 60.8760 61.0866 60.5445 61.0355 60.8803 60.6652 60.6901)
#plotlon=(8.12343 7.27596 7.17561 6.41504 8.70466 7.17666 6.63028 6.51468 9.07876 7.16982 6.33738 5.96487)
#plotname=(ALP1 ALP2 ALP3 ALP4 SUB1 SUB2 SUB3 SUB4 BOR1 BOR2 BOR3 BOR4)

######### Landpress Sites
#plotlat=(60.70084 65.83677 64.779 65.79602)
#plotlon=(5.092566 12.224506 11.2193 12.219299)
#plotname=(LYG BUO HAV SKO)

######### Three-D Sites
#plotlat=(60.88019 60.86183 60.85994)
#plotlon=(7.16990 7.16800 7.19504)
#plotname=(VIKE JOAS LIAH)

######### Finnmark Site
plotlat=(69.341088)
plotlon=(25.293524)
plotname=(FINN)

creat_script="T"               # T or F, switch for creating script grid or not
creat_domain="T"               # T or F, switch for creating domain file
creat_mapping="F"              # T or F, switch for creating mapping file
creat_surfdat="F"              # T or F, switch for creating surface data file
creat_aero="F"                 # T or F, switch for creating aerosol depostion file for each site. If "F", model will use global data as input.               
creat_topo="F"                 # T or F, switch for creating topography file for each site. If "F", model will use global data as input. 
creat_urb="F"                  # T or F, switch for creating urban data file for each site. If "F", model will use global data as input. 
tar_input="F"                  # T or F, switch for tar all the input data required for each site.
run_case="F"                   # T or F, switch for running many clm experiments automatically. "T" can only be used when all the inputdata are ready!!!!  
run_case_first="F"             # T or F, swtich for creating, building and submitting short test runs
run_case_second="F"            # T or F, swtich for running long experiments

#0 1 2 3 4 5 6 7 8 9 10 11
for i in 0
do
 
######## Make script grids:
if [ ${creat_script} == "T" ]
then

   module purge
   module load NCL/6.6.2-intel-2019b
   cd ~/ctsm/tools/mkmapdata
   mkdir -p ${input_dir}/share/scripgrids/${plotname[i]}

   echo $i
   echo ${plotlat[$i]} ${plotlon[$i]}
   ./mknoocnmap.pl -centerpoint ${plotlat[i]},${plotlon[i]} -name ${plotname[i]} -dx 0.01 -dy 0.01
   mv ~/ctsm/tools/mkmapgrids/*${plotname[i]}*.nc ${input_dir}/share/scripgrids/${plotname[i]}/

fi

######## Make domain file:
if [ ${creat_domain} == "T" ]
then
   module purge
   cd ~/ctsm/cime/tools/mapping/gen_domain_files
   mkdir -p ${input_dir}/share/domains/${plotname[i]}

   #### Compile (Only need to be run at the first time, better to run separately)
   #cd src/
   #../../../configure --macros-format Makefile --mpilib mpi-serial --machine saga
   #. ./.env_mach_specific.sh ; gmake

   #### Run
   . ./src/.env_mach_specific.sh
   ./gen_domain -m ${input_dir}/share/scripgrids/${plotname[i]}/map_${plotname[i]}_noocean_to_${plotname[i]}_nomask_aave_da_${date}.nc -o ${plotname[i]} -l ${plotname[i]}

   mv domain.lnd.${plotname[i]}_${plotname[i]}.${date}.nc domain.lnd.${plotname[i]}.${date}.nc
   mv domain*${plotname[i]}*.nc ${input_dir}/share/domains/${plotname[i]}/

fi

######## Make mapping file:
if [ ${creat_mapping} == "T" ]
then

   module purge
   cd ~/ctsm/tools/mkmapdata
   mkdir -p ${input_dir}/lnd/clm2/mappingdata/maps/${plotname[i]}/
   #### Modify regridbatch.sh. This has been done in "fates_emerald_api".
   #### Run regridbatch.sh
   ./regridbatch.sh 1x1_${plotname[i]} ${input_dir}/share/scripgrids/${plotname[i]}/SCRIPgrid_${plotname[i]}_nomask_c${date}.nc 
   mv map*${plotname[i]}*.nc ${input_dir}/lnd/clm2/mappingdata/maps/${plotname[i]}/

fi

######## Make surface data file:
if [ ${creat_surfdat} == "T" ]
then

   module purge
   module load netCDF-Fortran/4.5.2-iimpi-2019b
   ulimit -s unlimited
   cd ~/ctsm/tools/mksurfdata_map
   mkdir -p ${input_dir}/lnd/clm2/surfdata_map/${plotname[i]}

   #### Compile (Only need to be run at the first time, better to run separately)
   #module load netCDF-Fortran/4.5.2-iimpi-2019b
   #Modify Makefile.common. This has been done in "fates_emerald_api".
   #gmake clean
   #gmake

   #### Run
   ./mksurfdata.pl -no-crop -res usrspec -usr_gname 1x1_${plotname[i]} -usr_gdate ${date} -usr_mapdir ${input_dir}/lnd/clm2/mappingdata/maps/${plotname[i]} -dinlc ${input_raw} -hirespft -years "2005" -allownofile
   mv surfdata_1x1_${plotname[i]}_hist_16pfts_Irrig_CMIP6_simyr2005_c${date}.nc surfdata_${plotname[i]}_simyr2000.nc
   mv surfdata*${plotname[i]}* ${input_dir}/lnd/clm2/surfdata_map/${plotname[i]}

fi

######## Creating aerosol depostion file for each site               
            
tar_input="F"  
if [ ${creat_aero} == "T" ]
then
   module purge
   module load NCL/6.6.2-intel-2019b
   cd ~/ctsm/tools/emerald_sites_tools
   mkdir -p ${input_dir}/lnd/clm2/mappingdata/maps/${plotname[i]}/
   #### You need to modify the settings in "aerdep_site_clm5.ncl" before doing the following command. See detailed instructions in the file.  
   ncl aerdep_site_clm5.ncl
fi

######## Creating topography file for each site
if [ ${creat_topo} == "T" ]
then
   module purge
   module load NCL/6.6.2-intel-2019b
   cd ~/ctsm/tools/emerald_sites_tools
   mkdir -p ${input_dir}/lnd/clm2/mappingdata/maps/${plotname[i]}/
   #### You need to modify the settings in "topo_site_clm5.ncl" before doing the following command. See detailed instructions in the file.  
   ncl topo_site_clm5.ncl
fi

######## Creating urban data file for each site
if [ ${creat_urb} == "T" ]
then
   module purge
   module load NCL/6.6.2-intel-2019b
   cd ~/ctsm/tools/emerald_sites_tools
   mkdir -p ${input_dir}/lnd/clm2/mappingdata/maps/${plotname[i]}/
   #### You need to modify the settings in "urbandata_site_clm5.ncl" before doing the following command. See detailed instructions in the file.  
   ncl urbandata_site_clm5.ncl
fi

######## Wrap-up all the input data required for each site, for better use in GALAXY. 
if [ ${tar_input} == "T" ]
then
   #### You need to modify the settings in "tar_model_input_site.sh" before doing the following command. See detailed instructions in the file.  
   ./tar_model_input_site.sh
fi

######## Create a case
if [ ${run_case} == "T" ]
then
  
  module purge
  if [ ${run_case_first} == "T" ]
  then
    cd ~/ctsm/cime/scripts
    ./create_newcase --case ../../../ctsm_cases/2000FATES_${plotname[i]} --compset 2000_DATM%1PTGSWP3_CLM50%FATES_SICE_SOCN_MOSART_SGLC_SWAV --res 1x1_${plotname[i]} --machine saga --run-unsupported --project nn2806k

######## Build the case and run the test
    cd ~/ctsm_cases/2000FATES_${plotname[i]}
    ./case.setup
    ./case.build
    ./case.submit
  fi

######## Run the case for longer time
  if [ ${run_case_second} == "T" ]
  then
    cd ~/ctsm_cases/2000FATES_seedclim_${plotname[i]}
    ./xmlchange --file env_run.xml --id STOP_OPTION --val nyears                 # set up the time unit (e.g., nyears, nmonths, ndays).
    ./xmlchange --file env_run.xml --id STOP_N --val 200                         # set up the length of the simulation.
    #./xmlchange --file env_run.xml --id CONTINUE_RUN --val TRUE                 # if you want to continue your simulation from the restart file, set it to TRUE.
    ./xmlchange --file env_run.xml --id RESUBMIT --val 9                         # set up how many times you want to resubmit your simulation.
    ./xmlchange --file env_workflow.xml --id JOB_WALLCLOCK_TIME --val 08:00:00   # set up longer queue time for runing the simulation. 
    ./xmlchange --file env_workflow.xml --id JOB_QUEUE --val bigmem              # set up which queue to be used. Both "normal" and "bigmem" can be used depending on their availability.   
    ./case.submit
  fi

fi

done

