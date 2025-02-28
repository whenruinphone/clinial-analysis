/*************************************************************************************************
File name: setlib-v1-1.sas

Study:

SAS version: 9.4

Purpose:   initialize the path and library of project

Macros called:  

Notes:

Parameters: EDCdate: If there are clips under the path, then &EDCdate is the clip name 

Sample: 

Date started: 20FEB2024

Date completed: 20FEB2024

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 20FEB2024 Hao.Guo create
1.1 08MAR2024 Hao.Guo add macro variable _raw
1.1 24OCT2024 Hao.Guo auto find the max fodername, and then define EDCdate
*********************************** Prepared by Highthinkmed ************************************/
%macro setlib(EDCdate) / store;
	libname _all_ clear;
	%global _RAW;

	%if %length(&EDCdate)=0 %then %do;
		data _null_;
			a="&pgm_path";
			b=find(a,'\04-SAS_programming');
			c=cats(substr(a,1,b),'02-raw_dataset\02-crfdata');
			call symputx('folder',strip(c));/* folder path */
		run;
		%put the macro folder is &=folder; 
		data filenames;
		  length filename $200.; /* folder name max length */
		  filename = "&folder." || catt('/', filename);
		  rc = filename("fileref", filename);
		  did = dopen("fileref");
		  if did > 0 then do;
		    n = dnum(did);
		    do i = 1 to n;
		      f = dread(did, i);
		      output; /* output folder name */
		    end;
		    rc = dclose(did);
		  end;
		  rc = filename("fileref"); /* clear */
		run;
		data _null_;
			set filenames end=eof;
			if eof then call symputx('EDCdate',strip(f));
		run;
		%put the macro EDCdate is &=EDCdate;
		proc delete data=filenames;quit; 
	%end;

	%**_role=qc;
	%if %index(%upcase(&pgm_path) , 05-QC) %then
		%do;
			%global _role;
			%let _role=qc;

			%if %index(%upcase(&pgm_path) , 04-ANALYSIS) %then
				%do;
					%if %index(&pgm_path , 02-prod) %then
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;
					%else
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;

					libname sdtm "..\..\..\02-SDTM\outdata"   access=readonly;
					libname qcsdtm "..\..\02-SDTM\outdata";
					libname adam "..\..\..\03-ADaM\outdata"  access=readonly;
					libname qcadam "..\..\03-ADaM\outdata";
					libname table "..\..\..\04-ANALYSIS\Outdata";
					libname qctable "..\Outdata";
				%end;
			%else %if %index(%upcase(&pgm_path) , 03-ADAM) %then
				%do;
					%if %index(&pgm_path , 02-prod) %then
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;
					%else
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;

					libname sdtm "..\..\02-SDTM\outdata"   access=readonly;
					libname qcsdtm "..\02-SDTM\outdata";
					libname adam "..\..\03-ADaM\outdata"   access=readonly;
					libname qcadam "outdata";
				%end;
			%else %if %index(%upcase(&pgm_path) , 02-SDTM) %then
				%do;
					%if %index(&pgm_path , 02-prod) %then
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;
					%else
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;

					libname sdtm "..\..\02-SDTM\outdata"   access=readonly;
					libname qcsdtm "outdata";
				%end;
		%end;

	%**_role=primary;
	%else
		%do;
			%global _role;
			%let _role=primary;

			%if %index(%upcase(&pgm_path) , 04-ANALYSIS) %then
				%do;
					%if %index(&pgm_path , 02-prod) %then
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;
					%else
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;

					libname sdtm "..\..\02-SDTM\outdata";
					libname qcsdtm "..\..\05-QC\02-SDTM\outdata"  access=readonly;
					libname adam "..\..\03-ADaM\outdata";
					libname qcadam "..\..\05-QC\03-ADaM\outdata"  access=readonly;
					libname table "..\Outdata";
					libname qctable "..\..\05-QC\04-analysis\Outdata";
				%end;
			%else %if %index(%upcase(&pgm_path) , 03-ADAM) %then
				%do;
					%if %index(&pgm_path , 02-prod) %then
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;
					%else
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;

					libname sdtm "..\02-SDTM\outdata";
					libname qcsdtm "..\05-QC\02-SDTM\outdata"  access=readonly;
					libname adam "outdata";
					libname qcsdtm "..\05-QC\03-ADaM\outdata"  access=readonly;
				%end;
			%else %if %index(%upcase(&pgm_path) , 02-SDTM) %then
				%do;
					%if %index(&pgm_path , 02-prod) %then
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;
					%else
						%do;
							%if	%length(&EDCdate) = 0 %then
								%do;
									%let _RAW=..\..\..\02-raw_dataset\02-crfdata;
									libname raw  "&_RAW"  access=readonly;
								%end;
							%else
								%do;
									%let _RAW=..\..\..\02-raw_dataset\02-crfdata\&EDCdate;
									libname raw  "&_RAW"  access=readonly;
								%end;
						%end;

					libname sdtm "outdata";
					libname qcsdtm "..\05-QC\02-SDTM\outdata"  access=readonly;
				%end;
		%end;
%mend;