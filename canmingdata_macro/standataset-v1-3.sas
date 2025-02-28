/*************************************************************************************************
File name: standataset-v1-3.sas

Study:

SAS version: 9.4

Purpose: standataset sdtm and adam dataset

Macros called:  

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 13JUL2023

Date completed: 17JUL2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 17JUL2023 Ruifeng.Wen create
1.1 28AUG2024 guohao		1.defleat the specpath 2.Domain_Name="SUPP%upcase(&domain.)"
 							3.add inds= 4.debug= 5.compress= 6.delete seq code
1.2 07SEP2023 GUOHAO		 add dslabel
1.3 19SEP2023 GUOHAO		 add dslabel of ADaM
*********************************** Prepared by Highthinkmed ************************************/
%macro standataset(specpath=,datatype=,domain=,inds=,compress= ,debug=);
	%** resort input dataset;
	data _ds_inds;
		set &inds;
	run;

	%** remove variable format, informat;
	proc datasets nodetails nolist;
		modify _ds_inds;
		informat _all_;

		%if %upcase(&datatype.) ne ADAM %then
			%do;
				format _all_;
			%end;
	quit;

	%if %symexist(_sdtmspec_path_excel) and %length(&specpath.)=0 %then
		%let specpath=&_sdtmspec_path_excel.;

	%if "%upcase(&compress.)" eq "Y" or "%upcase(&compress.)" eq "1" %then
		%let _compress=Y;
	%else %let _compress=N;

	%if %upcase(&datatype.)=SDTM %then
		%do;

			data ds_meta;
				set sdtmspec.sdtmspec_&domain.;
			run;
			data content;
				set sdtmspec.sdtmspec_content;
				where upcase(SASDatasetName)= upcase("&domain.");
				call symputx('keyvars',strip(KeySequenceVar),'G');
				call symputx('dslabel',strip(Description),'G');
			run;

		%end;
	%else %if %upcase(&datatype.)=ADAM %then
		%do;

			data ds_meta;
				set adamspec.adamspec_&domain.;
			run;
			data content;
				set adamspec.adamspec_content;
				where upcase(SASDatasetName)= upcase("&domain.");
				call symputx('keyvars',strip(KeySequenceVar),'G');
				call symputx('dslabel',strip(Description),'G');
			run;

		%end;

	proc contents data=ds_meta out=cont(keep=name ) noprint;
	run;

	proc sql noprint;
		select 0 into: cont1 from cont where ^find(lowcase(name),"include");
		select 1 into: cont1 from cont where find(lowcase(name),"include");
		select 0 into: cont2 from cont where ^find(lowcase(name),"keysequence");
		select 1 into: cont2 from cont where find(lowcase(name),"keysequence");
		select 0 into: cont3 from cont where ^find(lowcase(name),"displayformat");
		select 1 into: cont3 from cont where find(lowcase(name),"displayformat");
	quit;

	%put &cont1;

	%if &cont1.=0 or &cont2.=0 or &cont3.=0 %then
		%do;
			%put "warning:未采用新版spec";
		%end;
	%else
		%do;
			/*get the dataset attribution */
			data ds_meta01;
				length attrib_ modify_ $200;
				set ds_meta(where =( upcase(include)='Y')) end=eof;

				if upcase(TYPEODM) = "TEXT" then
					do;
						attrib_ = strip(VARNAME)||" label = '"||strip(VARLABEL)||"'";
						modify_ = strip(VARNAME)||" char("||compress(DISPFMT,,'kd')||")";
					end;

				if upcase(TYPEODM) = "INTEGER" then
					do;
						attrib_ = strip(VARNAME)||" label = '"||strip(VARLABEL)||"'";;
					end;

				num=strip(vvalue(_n_));
				call symputx('varname'||num, strip(upcase(VARNAME)));
				call symputx('varlabel'||num, strip(VARLABEL));
				call symputx('vartype'||num, strip(upcase(TYPEODM)));

				if eof then
					call symputx('nvars', num);
				keep VARNAME attrib_ modify_ DisplayFormat KeySequence TYPEODM;
			run;

			proc sql noprint;
				select VARNAME into : varlist separated by " " from ds_meta01;
				select VARNAME into : keyvar separated by " " from ds_meta01 where not missing(KeySequence) order by KeySequence;
				select attrib_ into : attrib_ separated by " " from ds_meta01;
				select modify_ into : modify_ separated by "," from ds_meta01 where ^missing(modify_);
				select catx(" ",VARNAME,DisplayFormat) into :formatlst separated  by " "  from ds_meta01(where=(^missing(DisplayFormat) and upcase(TYPEODM)="INTEGER"));
			quit;

			%put &=varlist. &=keyvar. &=attrib_.;
			*modify length of the variable;
			proc sql noprint;
				alter table _ds_inds modify &MODIFY_.;
			quit;

			%if "&_compress"="Y" %then
				%do;

					proc sql undo_policy=none noprint;
						select distinct %if &vartype1 eq TEXT %then

							%do;
								max(length(&varname1))
							%end;
			%else
				%do;
					8
				%end;

			%do vi=2 %to &nvars.;
				%if &&vartype&vi eq TEXT %then
					%do;
						,max(length(&&varname&vi))
					%end;
				%else
					%do;
						,8
					%end;
			%end;

	into:
			pvarlen1

				%do vi=2 %to &nvars.;
					,:pvarlen&vi
				%end;

			from _ds_inds
			;
					quit;

					data _null_;
						%do vi=1 %to &nvars.;
							call symput("varlen&vi",compress(put(&&pvarlen&vi,best.)));
						%end;
					run;

					proc sql undo_policy=none;
						alter table _ds_inds
							%do vi=1 %to &nvars;

						%if &&vartype&vi eq TEXT %then
							%do;
								modify &&varname&vi char(&&varlen&vi)
							%end;
				%end;
			;
					quit;

		%end;

	%if %length(&keyvars.)>0 %then %do;
		proc sort data = _ds_inds;
			by  &keyvars.;
		run;
	%end;
	/*SUPP*/
	%if %upcase(&datatype.)=SDTM %then
		%do;

			data ds_meta_supp;
				set sdtmspec.sdtmspec_vlm(where=(Domain_Name="SUPP%upcase(&domain.)"));
			run;

			%if %nobs(ds_meta_supp)>0 %then
				%do;

					proc sql noprint;
						select count(distinct SASFieldName ) into :sum    separated by ""  from ds_meta_supp;
						select SASFieldName                 into :var1 -:var&sum.   from ds_meta_supp;
						select Var_Description            into :label1 -:label&sum. from ds_meta_supp;
					quit;

					data supp_ds_inds;
						length STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL $200;
						set _ds_inds;
						RDOMAIN=DOMAIN;
						QORIG="CRF";
						QEVAL='';

%macro supp_domain;
	%do i=1 %to &sum.;
		%if %upcase(&domain.)=DM %then
			%do;
				if &&var&i. ne '' then
					do;
						IDVAR="";
						IDVARVAL="";
						QNAM="&&var&i.";
						QLABEL="&&label&i.";
						QVAL=&&var&i.;
						output;
					end;
			%end;
		%else
			%do;
				if &&var&i. ne '' then
					do;
						IDVAR="%upcase(&domain.)SEQ";
						IDVARVAL=strip(put(&domain.seq,best.));
						QNAM="&&var&i.";
						QLABEL="&&label&i.";
						QVAL=&&var&i.;
						output;
					end;
			%end;
	%end;
%mend;

%supp_domain;
keep  STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

data &datatype..supp&domain.;
	set supp_ds_inds;
	retain STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
	label STUDYID="研究标识符"
		RDOMAIN="关联域名缩写" 
		USUBJID="受试者唯一标识符"
		IDVAR="标识变量"
		IDVARVAL="标识变量值"
		QNAM="修饰语变量名称"
		QLABEL='修饰语变量标签'
		QVAL="数据值"
		QORIG="来源"
		QEVAL="评估者";
run;

%end;
%end;

%if %upcase(&datatype.)=ADAM %then
	%do;

		data &datatype..&domain.  (label = "&dslabel");
			attrib &attrib_.;
			set  _ds_inds;
			keep &varlist.;
			retain  &varlist.;
			format _all_;
			informat _all_;
			format &formatlst.;
		run;

	%end;
%else %if %upcase(&datatype.)=SDTM %then
	%do;

		data &datatype..&domain. (label = "&dslabel");
			attrib &attrib_.;
			set  _ds_inds;
			keep &varlist.;
			retain  &varlist.;
			format _all_;
			informat _all_;
		run;

	%end;
%end;

%if &Debug<=0 %then
	%do;

		proc datasets nolist nodetails NoWarn lib=work;
			delete cont ds_meta01 _ds_inds ds_meta supp_ds_inds ds_meta_supp content/memtype=data;
		quit;

	%end;
%mend;