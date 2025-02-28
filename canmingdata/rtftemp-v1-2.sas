%macro rtftemp / store;
    ODS PATH work.templat(update) sasuser.templat(read) sashelp.tmplmst(read);
proc template;
  define style styles.custom ;
    parent=styles.rtf;
    replace fonts /
				'TitleFont'          = ("times new roman", 10.5pt)
				'TitleFont2'         = ("times new roman", 10.5pt)
				'StrongFont'         = ("times new roman", 10.5pt)
				'EmphasisFont'       = ("times new roman", 10.5pt)
				'FixedEmphasisFont'  = ("times new roman", 10.5pt)
				'FixedStrongFont'    = ("times new roman", 10.5pt)
				'FixedHeadingFont'   = ("times new roman", 10.5pt)
				'BatchFixedFont'     = ("times new roman", 10.5pt)
				'headingEmphasisFont'= ("times new roman", 10.5pt)
				'headingFont'        = ("times new roman", 10.5pt)
				'FootFont'           = ("times new roman", 10.5pt)
				'FixedFont'          = ("times new roman", 10.5pt)
				'docFont'            = ("times new roman", 10.5pt)
	;

    replace header /
            background=white
			font_face="Times New Roman"
			 fontsize=10.5pt
            just=c 
            asis=on;

    replace Body from Document/  
            bottommargin=1.5cm 
            topmargin=1.5cm 
            rightmargin=1.5cm 
            leftmargin=1.5cm;
   
    style  table from table /
           width = 100%                                                         
           frame = hsides
           rules = groups     
           cellspacing = 0pt
           cellpadding = 0.5pt;
   end;
run;
goptions device=ACTIVEX;
options orientation=landscape NoDate nobyline NoNumber ;
ods results;
ods listing close;
ods escapechar="&escapechar";
ods rtf file = "&OutputFileName..rtf"  style=styles.custom;
ods rtf;
title j=l "&sponsor_name." j=r "{Page {\field{\fldinst{page}}} of {\field{\fldinst{numpages}}}}";
title2 j=l "&protocol_num."  j=r "Date of Generation: &crdate.";
%mend;