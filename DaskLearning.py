#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
This program experiments with X-Array and Dask
"""

import dask, os, xarray as xr, numpy as np
import dask.array as da


@dask.delayed
def mixRat(temp,press):
     
    """ 
    Computes the mixing ratio (kg/kg) from dewpoint and air pressure
    
    Input: 
        - temp (K): air temperature
        - press (Pa): air pressure 
    """
    # Sat vapor pressure; Pa -- from Bolton's formula
    if np.min(temp) >150:
        const=-273.15
    else: const=0.0
    vp=611.2*np.exp((17.67*(temp+const))/(temp+243.5+const))

    # Specific humidity
    q=vp*0.622/press
    
    # Mixing ratio
    mr=q/(1.0-q)
    
    return mr, q


@dask.delayed
def compQH(mr,t):
    
    """
    Computes sensible heat from the mixing ratio ( kg/kg; determines specific 
    heat capacity), and the air temperature (K)
    """
    
    qh = t * 1.0057 * (1.0 + 1.82 * mr)
    
    return qh

@dask.delayed
def compQL(t,q):
    
    """
    Computes latent heat from the specific humidity (kg/kg) and the temperature
    (K)
    """

    ql=1918.46*(t/(t-33.91))**2 * q
    
    return ql

@dask.delayed
def compQ(qh,ql):
    
    """
    Simply sums the latent and sensible heat. This is wrapper to enable dask
    delayed. 
    """

    q=qh+ql
    
    return q
#===========================================================#
# Options
#===========================================================#
# This is an era5 dataset with monthly means for temperature (t2m), surface
# pressure (sp), and dewpoint temperature (2tm)

# *** Change to file copied from OneDrive
f="/media/gytm3/WD12TB/WrongMeasure/Data/ECMWF/era5.nc"

# Output names 

# *** Change these
qlout="/media/gytm3/WD12TB/WrongMeasure/Data/Dask_Test_ql.nc"
qhout="/media/gytm3/WD12TB/WrongMeasure/Data/Dask_Test_qh.nc"
qout="/media/gytm3/WD12TB/WrongMeasure/Data/Dask_Test_q.nc"
#

# Set the chunk size (# no. consectutive features in time dimension)
chunk=10
# Read in the file & assign
f="/media/gytm3/WD12TB/WrongMeasure/Data/ECMWF/era5.nc"
d=xr.open_dataset(f,chunks={"time":chunk})
t=d.t2m
sp=d.sp
dew=d.d2m

# Compute the mixing ratio
results=mixRat(dew,sp)
out=dask.compute(results); mr=out[0][0]; q=out[0][1]

# Compute the sensible heat
results=compQH(mr,t)
qh=dask.compute(results)[0]
qh=qh.chunk(chunks={"time":chunk})
qh.name="QH"
qh.attrs={"units":"kJ/kg"}

# Compute the latent heat
results=compQL(t,q)
ql=dask.compute(results)[0]
ql=ql.chunk(chunks={"time":chunk})
ql.name="QL"
ql.attrs={"units":"kJ/kg"}

# Sum them for Q
results=compQ(ql,qh)
q=dask.compute(results)[0]
q=q.chunk(chunks={"time":chunk})
q.name="Q"
q.attrs={"units":"kJ/kg"}

# Write out (after deleting any old versions)
for i in [qlout,qhout,qout]: 
    if os.path.isfile(i): os.remove(i)

ql.to_netcdf(qlout,mode='w',format="NETCDF4")
qh.to_netcdf(qhout,mode='w',format="NETCDF4")
q.to_netcdf(qout,mode='w',format="NETCDF4")
