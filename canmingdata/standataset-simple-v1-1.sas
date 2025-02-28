/*************************************************************************************************
File name: standataset_simple-v1-1.sas

Study:

SAS version: 9.4

Purpose: standataset sdtm and adam dataset

Macros called:  

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 13JUL2023

Date completed: 17JUL2023

Mod Date Name DSLABEL
--- ----------- ------------ -----------------------------------------------
1.0 12NOV2024 GUOHAO create
1.1 03JAN2025 GUOHAO ADD where ^missing(dsname);
*********************************** Prepared by Highthinkmed ************************************/
%macro standataset_simple(domain=,inds= ,debug=,role=) / store;
	data _ds_inds;
		set &inds;
		informat _all_;format _all_;
	run;
			data ds_meta;
				set adamspec.adamspec_&domain. end=eof;
				where ^missing(dsname);
				call symputx('varname'||strip(put(_n_,best.)),varname);
				call symputx('varlabel'||strip(put(_n_,best.)),varlabel);
				if eof then call symputx('nvar',strip(put(_n_,best.)));
			run;
			data content;
				set adamspec.adamspec_content;
				where upcase(DSNAME)= upcase("&domain.");
				call symputx('keyvars',strip(KeyS),'G');
				call symputx('dslabel',strip(DSLABEL),'G');
			run;
proc sql undo_policy=none noprint  ;
          select varname into:varname_list separated by " ,"
          from ds_meta as a 
;
quit;
%put &varname_list.;
%put &keyvars.;
proc sql;
    create table &ROLE.ADAM.&domain. as
    select &varname_list.
    from _ds_inds
	order by &keyvars.
	;
quit;
%if &Debug<=0 %then
	%do;

		proc datasets nolist nodetails NoWarn lib=work;
			delete cont ds_meta01 _ds_inds ds_meta supp_ds_inds ds_meta_supp content/memtype=data;
		quit;

	%end;
%mend;

