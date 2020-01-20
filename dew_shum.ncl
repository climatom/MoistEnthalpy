; Calculates specific humidity from 

; Associate files with pointers
; note: ncl inFile=\"{$outFile}.tmp.nc\" outFile=\"{$outFile}.nc\" test.ncl

f = addfile(inFile,"r")

; Get vars from pointer
if (getfilevartypes (f,"t2m").eq."short") then
      temp  = short2flt( f->t2m )
      dew  = short2flt( f->d2m )
      sp  = short2flt( f->sp )
else
      dew = f->d2m
      temp = f->t2m
      sp = f->sp
end if

; Calculate the specific humidity   
shum  = mixhum_ptd(sp,dew,1)

; Separately compute the relhum and write this out
rh=relhum_ttd(temp,dew,1)
; limit to max = 1.0
rh = where(rh.gt.1.00, 1.00, rh)   

; Add meta data and decide outnames
copy_VarCoords(dew,shum)
copy_VarCoords(dew,rh)
outname = str_sub_str(inFile,"netcdf","shum")
outname2 = str_sub_str(outname,"shum","rh")

; delete pre-existing files -- if they exist
; ** SHUM
str = "rm -f " + outname
system(str)   ; remove any pre-existing file 
; ** RH
str = "rm -f " + outname2
system(str)   ; remove any pre-existing file 

; write out
; ** SHUM
ncdf = addfile(outname ,"c")  ; open output netCDF file
filedimdef(ncdf,"time",-1,True) ; time unlimited
ncdf->shum = shum ; coordinate info automatically copied across

; ** RH
ncdf = addfile(outname2 ,"c")  ; open output netCDF file
filedimdef(ncdf,"time",-1,True) ; time unlimited
ncdf->rh = rh ; coordinate info automatically copied across


