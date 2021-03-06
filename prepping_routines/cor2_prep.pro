pro cor2_prep,hdr,im,rotate_on=rotate_on,fill_mean=fill_mean, fill_value=fill_value, $
 smask_on=smask_on, calibrate_off=calibrate_off, color_on=color_on, date_on=date_on, $
 logo_on=logo_on, polariz_on=polariz_on, ROTINTERP_ON=ROTINTERP_ON, rotcubic_on=rotcubic_on, $
 silent=silent, NOWARP=nowarp, WARP_OFF=warp_off, _extra=ex, PRECOMMCORRECT_ON=precommcorrect_on
 
; Implements COR2_calibrate which has a background subtraction in it. (E. Carley 2012-Sep-18)   

;+
; $Id: cor_prep.pro,v 1.39 2008/10/28 22:03:28 nathan Exp $
;
; Project   : STEREO SECCHI
;                   
; Name      : cor_prep
;               
; Purpose   : Processes a STEREO COR1 or COR 2 image to level 1.0 
;               
; Explanation: The default calibration procedure involves; subtracting
;        the CCD bias, multiplying by the calibration factor and vignetting
;        function, and dividing by the exposure time. Any of these operations
;        can turned off using the keywords. 
;               
; Use       : IDL> cor_prep,hdr,im
;    
; Inputs    : im - level 0.5 image in DN (long)
;             hdr -image header, either fits or SECCHI structure
;
; Outputs   :  
;
; Keywords  : NOWARP - If set do not apply cor2_warp to COR2 images (only)
;   	      SMASK_ON - applied a smooth mask to the image
;             FILL_MEAN - if set then missing data and the mask are
;                         set to the mean of the images; the default
;                         is zero
;             FILL_VALUE - if set then missing data and the mask are
;                         set to the input value; the default
;                         is zero 
;             CALIBRATE_OFF - if set no photometeric calibration is
;                             applied; this keyword set if the
;                             trim_off keyword was set in SECCHI_PREP
;             UPDATE_HDR_OFF- if set, don't call SCC_UPDATE_HDR (saves time)
;             DATE_ON - Adds date-time stamp to bottom left of image
;             LOGO_ON - Adds SECCHI logo to bottom right of image  
;             COLOR_ON - loads instrument color table           
;             ROTATE_ON - rotates the image such that solar north is at
;                          the top of the image                           
;             ROTINTERP_ON - Use bilinear interpolation for the
;                            rotation (if ROTATE_ON is set). Default
;                            is nearest neighbor.
;             ROTCUBIC_ON - Use cubic convolution interpolation method
;                           for the rotation (if ROTATE_ON is set). Default
;                            is nearest neighbor.
;                            is nearest neighbor.
;             DSCRI_POBJ_ON - only for COR1: apply discri_pobj.pro after
;                             background subtraction.
;
; Calls     : SCC_FITSHDR2STRUCT, SCC_GET_MISSING, COR_CALIBRATE, 
;             COR1_CALIBRATE, SCC_UPDATE_HDR
;            
;               
; Category    : Calibration
;               
; Prev. Hist. : None.
;
; Written     : Robin C Colaninno NRL/GMU August 2006
;               
; $Log: cor_prep.pro,v $
; Revision 1.39  2008/10/28 22:03:28  nathan
; call cor2_point if doing warp and /PRECOMM not set
;
; Revision 1.38  2008/09/24 17:30:49  nathan
; use scc_roll_image to do roll correction and header update
;
; Revision 1.37  2008/07/14 18:27:13  nathan
; added /WARP_OFF
;
; Revision 1.36  2008/06/06 20:30:36  nathan
; put Log flag back in
;
; Revision 1.23  2007/04/04 15:27:26  colaninn
; reversed output parameters
;
; Revision 1.22  2007/04/03 15:58:44  thernis
; Add /pivot in the rot function call
;
; Revision 1.21  2007/04/02 14:12:28  colaninn
; removed update 1.17
;
; Revision 1.20  2007/03/30 22:11:35  thompson
; *** empty log message ***
;
; Revision 1.19  2007/03/30 22:02:50  thompson
; Add keyword update_hdr_off
;
; Revision 1.18  2007/03/30 20:30:40  colaninn
; add keyword to rot
;
; Revision 1.17  2007/03/27 13:56:53  colaninn
; add crval to rotate
;
; Revision 1.16  2007/03/12 19:46:01  thompson
; *** empty log message ***
;
; Revision 1.15  2007/02/26 19:10:37  colaninn
; corrected header
;
; Revision 1.14  2007/02/13 15:59:55  thernis
; Add ROTINTERP_ON keyword to allow bilinear interpolation when using the ROTATE_ON keyword
;
; Revision 1.13  2007/02/02 00:14:33  nathan
; do not call scc_update_hdr if polariz_on (to save time)
;
; Revision 1.12  2007/01/27 00:16:03  nathan
; skip get_missing, scc_update_hdr if calibration_off
;
; Revision 1.11  2007/01/22 19:46:45  colaninn
; add correct path to color files
;
; Revision 1.10  2007/01/19 19:32:25  colaninn
; change color table to restore command
;
; Revision 1.9  2007/01/17 15:31:30  colaninn
; added color table loading 
;
; Revision 1.8  2006/12/14 21:32:35  colaninn
; added rotate_on keyword
;
; Revision 1.7  2006/12/12 20:52:39  colaninn
; added rotate keyword
;
; Revision 1.6  2006/12/07 21:16:53  colaninn
; added get_smask
;
; Revision 1.5  2006/12/06 20:07:44  colaninn
; zero-ed out low levels in calimg
;
; Revision 1.4  2006/11/27 19:54:49  colaninn
; cor/cor_calibrate.pro
;
; Revision 1.3  2006/11/21 22:14:13  colaninn
; made updates for Beta 2
;
; Revision 1.2  2006/10/24 20:42:09  colaninn
; added calibrate_off keyword
;
; Revision 1.1  2006/10/03 15:29:44  nathan
; moved from dev/analysis/cor
;
;-
ON_ERROR,2
IF datatype(ex) EQ 'UND' THEN ex = create_struct('blank',-1)
IF keyword_set(silent) THEN ex = CREATE_STRUCT('silent',1,ex)

IF ~keyword_set(silent) THEN $          
print,'$Id: cor_prep.pro,v 1.39 2008/10/28 22:03:28 nathan Exp $'

;--Check Header-------------------------------------------------------
IF(datatype(hdr) NE 'STC') THEN hdr=SCC_FITSHDR2STRUCT(hdr)

IF ~strmatch(TAG_NAMES(hdr,/STRUCTURE_NAME),'SECCHI_HDR_STRUCT*') THEN $
MESSAGE, 'ONLY SECCHI HEADER STRUCTURE ALLOWED'

IF (hdr[0].DETECTOR NE 'COR1' AND hdr[0].DETECTOR NE 'COR2' ) THEN $ 
 message,'Calibration for DETECTOR not implemented' 
;----------------------------------------------------------------------

;--Cosmic Ray and Star Removal(OFF)
IF keyword_set(cosmic_on) THEN BEGIN
  im = discri_pobj(im)
  IF ~keyword_set(SILENT) THEN message,'DISCRI_POBJ applied',/info
ENDIF 

;--Find Missing Blocks(ON)
IF (hdr[0].MISSLIST NE '') AND ~keyword_set(calibrate_off) THEN BEGIN 
  missing = SCC_GET_MISSING(hdr)
ENDIF

;--Calibrate(ON)
IF ~keyword_set(calibrate_off) THEN BEGIN
    if hdr[0].detector eq 'COR1' then $
      im = COR1_CALIBRATE(im,hdr,discri_pobj_on=discri_pobj_on,_extra=ex) else $
      im = COR2_CALIBRATE(im,hdr,_extra=ex)
ENDIF

;--Missing Block Mask(ON) 
IF (hdr[0].MISSLIST NE '') AND ~keyword_set(calibrate_off) THEN BEGIN 
  CASE 1 OF
    keyword_set(fill_mean) : im[missing]=mean(im) 
    keyword_set(fill_value) : im[missing]=fill_value
    ELSE: im[missing]=0.0
  ENDCASE
ENDIF ELSE missing = 0

;--Warp(ON)
IF keyword_set(WARP_OFF) THEN nowarp=1
IF hdr.DETECTOR EQ 'COR2' and ~keyword_set(NOWARP) THEN BEGIN
    IF ~keyword_set(PRECOMMCORRECT_ON) THEN cor2_point,hdr, SILENT=silent, _extra=ex
    im = cor2_warp(temporary(im),hdr, INFO=histinfo, _EXTRA=ex)
    hdr.distcorr='T'
    hdr = SCC_UPDATE_HISTORY(hdr,histinfo[0])
    hdr = SCC_UPDATE_HISTORY(hdr,histinfo[1])
    IF ~keyword_set(SILENT) THEN message,histinfo[0],/info
ENDIF

;--Rotate Solar North Up (OFF)
IF keyword_set(rotate_on) THEN BEGIN

    scc_roll_image,hdr,im, missing=0, interp=keyword_set(rotinterp_on), $
    	    cubic=keyword_set(rotcubic_on),_extra=ex
    
    IF ~keyword_set(SILENT) THEN message,'Image rotated to Solar North Up',/info
ENDIF

;--Smooth Mask(OFF)
IF keyword_set(smask_on) AND ~keyword_set(calibrate_off) THEN BEGIN 
  mask = get_smask(hdr)
  m_dex = where(mask EQ 0)
    CASE 1 OF
      keyword_set(fill_mean) : im[m_dex]=mean(im) 
      keyword_set(fill_value) : im[m_dex]=fill_value
      ELSE: im = im*mask
    ENDCASE
    IF ~keyword_set(SILENT) THEN message,'Mask applied',/info
ENDIF

;--Load Telescope Color Table (OFF)   
IF keyword_set(color_on) THEN BEGIN    
  path = concat_dir(getenv('SSW'),'stereo')
  color_table = strtrim(string(hdr.DETECTOR),2)+'_color.dat'
  RESTORE, FILEPATH(color_table ,ROOT_DIR=path,$
            SUBDIRECTORY=['secchi','data','color'])
  tvlct, r,g,b
ENDIF

;--Update Header to Level 1 values (ON)
IF ~keyword_set(calibrate_off) AND ~keyword_set(polariz_on) AND $
  ~keyword_set(update_hdr_off) THEN $
  hdr = SCC_UPDATE_HDR(im,hdr,missing=missing,_extra=ex)

;--Correct for in-flight calbration Bug 232
IF hdr.DETECTOR EQ 'COR2' THEN BEGIN
  hdr.CDELT1 = 14.7*2^(hdr.SUMMED-1)
  hdr.CDELT2 = 14.7*2^(hdr.SUMMED-1)
ENDIF

;--Date and Logo Stamp (OFF)
IF keyword_set(date_on) AND ~keyword_set(polariz_on) THEN $
  im = scc_add_datetime(im,hdr)

IF keyword_set(logo_on) THEN im = scc_add_logo(im,hdr)
 
;-----------------------------------------------------------------------------

RETURN
END
