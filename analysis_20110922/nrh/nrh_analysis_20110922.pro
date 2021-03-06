pro nrh_analysis_20110922

!p.multi=[0,1,1]
cd,'/Users/eoincarley/Data/22sep2011_event/NRH'
tstart = anytim(file2time('20110922_104000'),/yoh,/trun,/time_only)
tend   = anytim(file2time('20110922_110000'),/yoh,/trun,/time_only)
read_nrh,'nrh2_1509_h70_20110922_081556c06_i.fts', nrh_hdr, nrh_data, hbeg=tstart, hend=tend
index2map, nrh_hdr, nrh_data, nrh_struc  
nrh_struc_hdr = nrh_hdr
nrh_times = nrh_hdr.date_obs

window,0,xs=500,ys=500

stationaryx_peak_max = fltarr(n_elements(nrh_times))

source_position = dblarr(2,n_elements(nrh_times))
source_peak_Tb = dblarr(2,n_elements(nrh_times))
FOR i=0, 	n_elements(nrh_times)-1 DO BEGIN
	index_nrh=i
	nrh_data_image = nrh_data[*,*,index_nrh]

	map_nrh = make_map(nrh_data_image)
	map_nrh.dx = 29.9410591125
	map_nrh.dy = 29.9410591125
	map_nrh.xc = 64 
	map_nrh.yc = 64  
	levels=(dindgen(7.0)*(max(nrh_data_image) - max(nrh_data_image)*0.5)/6.0)+max(nrh_data_image)*0.5
	loadct,3
	plot_map,map_nrh,/limb,title=nrh_times[index_nrh]
	plot_helio,file2time('20110922_104600'),/over,gstyle=1,gthick=1,gcolor=150,grid_spacing=10.0
	levels=(dindgen(7.0)*(max(nrh_data_image) - max(nrh_data_image)*0.3)/6.0)+max(nrh_data_image)*0.3
	set_line_color 
	plot_map,map_nrh,/overlay,/cont,levels=levels,c_color=5
	
    window,2,xs=800,ys=800
    loadct,3
    plot_image,nrh_data_image,title=nrh_times[index_nrh],charsize=2
	tvcircle, (nrh_struc_hdr[index_nrh].SOLAR_R), $
	64.0, 64.0, 254, /data,color=255,thick=1
    contour,nrh_data_image,levels = levels,/overplot
    
    print,'Please choose first two points'
    cursor,x1,y1,/data
    
    print,'Please choose second two points'
    wait,0.5
    cursor,x2,y2,/data
    a = [x1,x2]
    b = [y1,y2]
    ina = sort(a)
    inb = sort(b)
    x1 = a[ina[0]]
    x2 = a[ina[1]]
    y1 = b[inb[0]]
    y2 = b[inb[1]]
    plots,x1,y1,psym=1,color=255,symsize=3
    plots,x2,y2,psym=1,color=255,symsize=3
    
	data_section = nrh_data_image[x1:x2,y1:y2]
	;at this point data section should be handed to a 2d gauss fit routine
	
	dimen = size(data_section)
	x_len = dimen[1]
	y_len = dimen[2]
	junk_array = dblarr(x_len +50.0, y_len+50)
	junk_array[25:25+x_len-1, 25:25+y_len-1] = data_section
	;---------------------------------------
	;			  FIT 2D Gauss 
	result = gauss2dfit(junk_array,a,/tilt)
	;
	;---------------------------------------
	
	;---------------------------------------
	;Since gauss2dfit doens't give errors, use a as start values
	;for mpfit2dfun.
	;start_parms = a
	;parms = MPFIT2DFUN(MYFUNCT, X, Y, Z, ERR, start_parms)
	
	stop
	print,max(result)
	print,max(junk_array)
	IF finite(max(result)) eq 1 THEN BEGIN
		peak_result = where(result eq max(result))
		loc_result = array_indices(result,peak_result)
		loc_section = loc_result - 25.0
		peak_TB = max(result)
	ENDIF
	
	IF finite(max(result)) eq 0 THEN BEGIN
		print,'						 '
		print,'Not using Gaussian fit'
		print,'						 '
		save,data_section,filename = 'test_on_gauss_2d.sav'
		peak = max(data_section)
		peak_loc = where(data_section eq peak)
		loc_section = array_indices(data_section,peak_loc)
		peak_TB = peak
	ENDIF
	loc_whole = [loc_section[0] + x1, loc_section[1] + y1]
	set_line_color
	plots,loc_whole[0],loc_whole[1],psym=1,color=5,symsize=3
	
	source_position[0,i] = loc_whole[0]
	source_position[1,i] = loc_whole[1]
	source_peak_Tb[i] = peak_TB
	;window,4
	;;plot_image,data_section,charsize=3.0
	;plots,loc_section[0],loc_section[1],psym=1,color=255,symsize=3

	t1 = ATAN((loc_whole[0]-64.0),(loc_whole[1]-64.0))*!RADEG
	IF (t1 LT 0)   THEN t1=t1+360.
    IF (t1 GT 360)   THEN t1=t1-360.
    t1 = 360-t1		; convert to position angles
	
	pixrad = nrh_hdr.solar_r/nrh_hdr.cdelt1
	r1 = sqrt((loc_whole[0]-64.0)^2.0 + (loc_whole[1]-64.0)^2.0)
	
	rads = dindgen(101)*(r1)/100.0
	xs = COS((t1+90.0)*!DTOR) * rads + 64.0
    ys = SIN((t1+90.0)*!DTOR) * rads + 64.0
    plots,xs,ys,color=5
	print,'Angle: '+string(t1)
	wait,0.5
	
ENDFOR

save, source_position, nrh_times, source_peak_Tb, filename = 's_position_20110922.sav'
stop
END