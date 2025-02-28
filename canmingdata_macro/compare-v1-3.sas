/*************************************************************************************************
File name: compare-v1-3.sas

Study:

SAS version: 9.4

Purpose:  compare two dataset and output the compared result to assignned directory

Macros called:  

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 23OCT2023

Date completed: 22NOV2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 22NOV2023 Hao.Guo create
1.1 22NOV2023 Hao.Guo debug type=
1.3 22NOV2023 Hao.Guo change compare from Compare
*********************************** Prepared by Highthinkmed ************************************/

%MACRO COMPARE(dataset=,type=)/ store;
	options  papersize=A4 orientation=landscape number center date;
    %global _isCompare;
	ods results;
	%if %length(&dataset)^=0 %then %let dataset=%lowcase (&dataset);
	%else %do;
        %put ERR%str()OR: (&SYSMACRONAME) The datase must not be missing.;
        %let _isCompare = 0;
        %goto exit;
	%end;
	%if %length(&type)^=0 %then %let type=%lowcase (&type);
	%else %do;
        %put ERR%str()OR: (&SYSMACRONAME) The type must not be missing.;
        %let _isCompare = 0;
        %goto exit;
	%end;

    %if %upcase(&type) ^= ADAM and  %upcase(&type) ^= SDTM  and %upcase(&type) ^= TABLE %then %do;
        %put ERR%str()OR: (&SYSMACRONAME) The type must be ADAM or SDTM or TABLE.;
        %let _isCompare = 0;
        %goto exit;
    %end;

	proc printto print="&pgm_path.\compare_&dataset..txt"       LABEL="Validation of &dataset."  new;   run; 

	proc compare base=&TYPE..&dataset. compare=qc&TYPE..&dataset. method=absolute criterion=0.000001  LISTALL
		out=&dataset. outbase outcomp outnoequal outdif;
	run;

	proc printto  ;  run;

%exit:

%MEND COMPARE;

