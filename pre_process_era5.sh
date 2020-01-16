#!/bin/bash
set -e

# This script is a pre-processor.

# Note: 
# 1. Compute the mixing ratio from the spechum:
#	r = q/(1-q)
# 2. Compute the specific heat capacity from mixing ratio (r):
#	cp = 1005.7 J/kg × (1 + 1.82 × r) (J/kg)
# 3. Compute the latent heat of vaporization from:
# 	L =  1.91846x10^6*{T/(T - 33.91)}^2 (J/kg)
#	L =  1918460 * {T/(T-33)}^2 (J/kg)

# Options/params
di="/media/gytm3/WD12TB/WrongMeasure/Data/ECMWF/" # Directory in
fi="${di}era5.nc" # File in
pre_process="no" # Do we need to (pre)process?
compute_coefs_and_energy="no" # Do we need to compute Cp, Lv and energy components?
analyse="yes" # Do we need to compute trends and LTMs?

if [ "${process_all}" == "yes" ]; then
	
	echo "Processing months>>>"

        # Process
	for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
                o="era5_mon_${m}_netcdf.nc"
		cmd="cdo -O -s -f nc selmon,${m} -selyear,1979/2018 ${fi} ${di}${o}"
		${cmd}
		ncl -Q dew_shum.ncl inFile=\"${di}${o}\"  
		# Note that here we chop out T only 
		cmd="cdo -O -s -f nc selmon,${m} -selvar,t2m ${fi} ${di}${o/netcdf/temp}"
		${cmd}
		echo "Processed month ${m}"            
	done
fi

if [ "${compute_coefs_and_energy}" == "yes" ]; then
	
	echo "Processing months>>>"

        # Process
	for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
		# Compute variable Cp and Lv
		# Cp
		fi_shum="${di}era5_mon_${m}_shum.nc"
                cmd="cdo -s -O --no_warnings expr,\"r=shum/(1.0-shum)\" ${fi_shum} ${fi_shum/shum/r}" ; echo "calling > $cmd"; $cmd
                cmd="cdo -s -O --no_warnings expr,\"Cp=1.0057*(1+1.82*r)\" ${fi_shum/shum/r} ${fi_shum/shum/cp}" ; echo "calling > $cmd" ; $cmd
		# Lv
		fi_t="${di}era5_mon_${m}_temp.nc"
		cmd="cdo -s -O --no_warnings expr,\"Lv=1918.460*(t2m/(t2m-33.91))^2\" ${fi_t} ${fi_t/temp/Lv}" ; echo "calling > $cmd"; $cmd
		# QH
		cmd="cdo -s -O -b 32 mul ${fi_t} ${fi_shum/shum/cp} ${fi_shum/shum/QH} " ; echo "calling > $cmd"; $cmd
		# QL
		cmd="cdo -s -O -b 32 mul ${fi_shum} ${fi_t/temp/Lv} ${fi_t/temp/QL} " ; echo "calling > $cmd"; $cmd
		echo "Processed month ${m}"            
	done
fi


# Now compute long-term means, yearly series, and, then, trends
if [ "${analyse}" == "yes" ]; then
	
	echo "Merging Temp, RH, QH, QL, L, and Cp (also computing Teq)>>>"
	cmd="cdo -s -O mergetime ${di}*temp.nc ${di}era5_temp_merged.nc"; echo "calling > $cmd" ; $cmd
	cmd="cdo -s -O mergetime ${di}*rh.nc ${di}era5_rh_merged.nc"; echo "calling > $cmd" ; $cmd 
	cmd="cdo -s -O mergetime ${di}*QH.nc ${di}era5_QH_merged.nc"; echo "calling > $cmd" ; $cmd 
	cmd="cdo -s -O mergetime ${di}*QL.nc ${di}era5_QL_merged.nc"; echo "calling > $cmd" ; $cmd 
	cmd="cdo -s -O mergetime ${di}*Lv.nc ${di}era5_Lv_merged.nc"; echo "calling > $cmd" ; $cmd 	
	cmd="cdo -s -O mergetime ${di}*cp.nc ${di}era5_cp_merged.nc"; echo "calling > $cmd" ; $cmd 
	cmd="cdo -s -O div -add ${di}era5_QL_merged.nc ${di}era5_QH_merged.nc ${di}era5_cp_merged.nc ${di}era5_Teq_merged.nc"; echo "calling > $cmd" ; $cmd 	
	echo "<<<Done"; echo ""; echo ""

	echo "Calculating ann trends (and ratios) for QH, QL>>>"
	cmd="cdo -s -O regres -yearmean ${di}era5_QH_merged.nc ${di}era5_QH_trend.nc"; echo "calling > $cmd" ; $cmd	
	cmd="cdo -s -O regres -yearmean ${di}era5_QL_merged.nc ${di}era5_QL_trend.nc"; echo "calling > $cmd" ; $cmd
	cmd="cdo -s -O div ${di}era5_QL_trend.nc ${di}era5_QH_trend.nc ${di}era5_QLQH_trend_ratio.nc"; echo "calling > $cmd" ; $cmd
	
	echo "<<<Done"; echo "";

	echo "Computing climatologies for Temp, RH, Teq, Lv and Cp>>>"
	cmd="cdo -s -O timmean ${di}era5_temp_merged.nc ${di}era5_temp_clim.nc"; echo "calling > $cmd" ; $cmd
	cmd="cdo -s -O timmean ${di}era5_rh_merged.nc ${di}era5_rh_clim.nc"; echo "calling > $cmd" ; $cmd
	cmd="cdo -s -O timmean ${di}era5_Lv_merged.nc ${di}era5_Lv_clim.nc"; echo "calling > $cmd" ; $cmd
	cmd="cdo -s -O timmean ${di}era5_cp_merged.nc ${di}era5_cp_clim.nc"; echo "calling > $cmd" ; $cmd	
	cmd="cdo -s -O timmean ${di}era5_Teq_merged.nc ${di}era5_Teq_clim.nc"; echo "calling > $cmd" ; $cmd
	echo "<<<Done"; echo ""; 

	

fi


