/*************************************************************************************************
File name: catdesc-v1-11.sas

Study:

SAS version: 9.4

Purpose: Create qualitative table

Macros called:  %Nobs, %M_var_exist

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 13JUL2023

Date completed: 17JUL2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 17JUL2023 Hao.Guo create
1.1 25AUG2023 Hao.Guo add ods exclude none before MEND because if proc report
1.2 19DEC2023 Hao.Guo add 100 Percent display and add prec=
1.3 29MAR2024 Hao.Guo add _rtffmt=EN for total and add fullgroup
1.4 29MAY2024 Hao.Guo Row 735 add 2 blank for totname
1.5 09JUL2024 Hao.Guo left join change to right join 
1.6 04SEP2024 Hao.Guo 	1.if ksubstr(strip(_Vlabel_),1,1)="[" then do
						2.else if ^missing(_Vlabel_) then _text1= _Vlabel_ 
						3._ngc99=tranwrd(_ngc99,'100.0','100');
1.7 17OCT2024 Hao.Guo 	1.length _ngc99 $200
1.8 29NOV2024 Hao.Guo 	1.add ___Conddsq_allGroup(where=(^missing(&Casevar )
1.9 18DEC2024 Hao.Guo 	1.ADD ctgroup= 2.pvalue 3.add pvalue_04 dataset step for calulated p value when group number lt 2
1.10 24DEC2024 Hao.Guo 	1.pvalue format
1.11 15JAN2025 Hao.Guo 	add pvalue when useing by
1.12 26JAN2025 Hao.Guo 	update s value when le 0.001 format

*********************************** Prepared by Highthinkmed ************************************/

%macro Catdesc(
DataSet=
,Cond=
,Popn=
,Casevar= USUBJID

,Group= 
,Groupn=
,Fullgroup=
,Varlist=
,By=
,Prec=
,Missing= 1
,NoperVval=
,EndLine= 1
,Debug= 0

,OutDs=) / store;
	%put Running Macro (&SYSMACRONAME.);

	proc datasets nolist nodetails NoWarn lib=work;
		delete ___:  /memtype=data;
	quit;

	%symdel OUTTOTAL / NOWARN;
	%GLOBAL _rtffmt Trtname OUTTOTAL Totname;

********************************************************************************************************************************
Step1.define moren macro
Step2.key code
Step3.delete mid dataset
********************************************************************************************************************************;
*******************************************************************
Step1.define moren macro
check needly
base options
popN:meno dataset and cond
Varlist:route output cat
By var list:cat seq and control var of by of merge
*******************************************************************;
** check needly *;
	%if %length(&Dataset.)=0 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Parameters Dataset= cant is miss ,Please checking!;
		%goto exit;
	%end;
	%if %sysfunc(exist(&Dataset.))=0 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Dataset &Dataset. are not exist , Please check Parameters Dataset=!;
		%goto exit;
	%end;

	%if %length(&Varlist.)=0 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Parameters Varlist= cant is miss ,Please checking!;
		%goto exit;
	%end;

	%if %m_var_exist(&DataSet.,&Group.)=0 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Parameters are Group=&Group. , dataset not have &Group. , Please checking!;
		%goto exit;
	%end;

	%if %m_var_exist(&DataSet.,&Groupn.)=0 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Parameters are Groupn=&Groupn. , dataset not have &Groupn. , Please checking!;
		%goto exit;
	%end;

** base options *;
	%if %length(&Casevar.)=0 	%then %let Casevar=usubjid;
	%if %length(&Group.)=0 		%then %let Group=trt01p;
	%if %length(&Missing.)=0 	%then %let Missing=1;
	%if %length(&EndLine.)=0 	%then %let EndLine=1;
	%if %length(&Debug.)=0 		%then %let Debug=0;
	%if %length(&OutDs.)=0 		%then %let OutDs=_table_rtf;
    %if %length(&Prec.)=0 and %symexist(_prec)      %then %let Prec=&_prec;
	%else %if  %length(&Prec.)=0 %then %let Prec=1;

    %if %upcase("&_Rtffmt.")="EN" %then %do; %let Totname=Total; %end;
	%if %upcase("&_Rtffmt.")="CH" %then %do;
		data _null_;
			Totname= byte(186)||byte(207)||byte(188)||byte(198);
			call symputx("Totname",strip(Totname),"l");
		run;
	%end;

	%if %length(&NoperVval.)>0 %then %do;
		%let NoperVval=%qsysfunc(tranwrd(%qcmpres(%upcase(&NoperVval.)),%str( ),%nrbquote(" ")));
		%let NoperVval=%nrbquote("&NoperVval.");
	%end;
	%else %if %length(&NoperVval.)=0 %then %do;
		%let NoperVval = "";
	%end;

** popN *;
	%if %length(&popN)>0 %then %do;
		%let _pop_Cond=%sysfunc(scan(&Popn,2,|));
		%let _pop_data=%sysfunc(scan(&Popn,1,|));
	%end;
	%else %if %sysfunc(exist(adam.adsl)) %then %do;
		%let _pop_cond=1;
		%let _pop_data=adam.adsl;
	%end;
	%else %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Parameters popn= cant is miss ,Please checking!;
		%goto exit;
	%end;
	%if %length(&_pop_cond.)=0 %then %let _pop_cond=1;

	%if %sysfunc(exist(&_pop_data.))=0 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) Dataset &_pop_data. not exist , Please check Parameters popn=!;
		%goto exit;
	%end;

** Varlist *;
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%/),%nrbquote(*$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%|),%nrbquote(*$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%\),%nrbquote(*$$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%=),%nrbquote(*$$$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%[),%nrbquote(*$$$$$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%]),%nrbquote(*$$$$$$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(//),%nrbquote(/ /)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(//),%nrbquote(/ /)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(/\),%nrbquote(/ \)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(\=),%nrbquote(\ =)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(\\),%nrbquote(\ \)));

	%local nvar LABELVAR SQLBY;
	%let i = 1;
	%do %while (%qscan(%nrbquote(&Varlist.),&i.,|) ne %str( ));
		%symdel varvlmd&i. varnamesort&i.   varname&i. varsort&i. varlabel&i. varoutn&i. / NOWARN;
		%local varvlmd&i. varnamesort&i.   varname&i. varsort&i. varlabel&i.  varoutn&i.;
		%let varvlmd&i. = %qscan(%nrbquote(&Varlist.),&i.,|);
		%let varnamesort&i. = %qscan(%nrbquote(&&varvlmd&i..),1,/);
		%let varname&i. = %upcase(%qscan(%nrbquote(&&varnamesort&i..),1,-));
		%let varsort&i. = %qscan(%nrbquote(&&varnamesort&i..),2,-);
		%let varlabel&i. = %qscan(%qscan(%nrbquote(&&varvlmd&i..),2,/),1,\);
		%let varoutn&i. = %qscan(%nrbquote(&&varvlmd&i..),3,/);
		%let varmethod&i. = %qscan(%nrbquote(&&varvlmd&i..),6,/);

		%if %length(%qcmpres(&&varoutn&i..))=0 %then %let varoutn&i.=0;
		%if %length(%qcmpres(&&varmethod&i..))=0 %then %let varmethod&i.=0;

		%if %index(%nrbquote(&&varlabel&i.),[) %then %do;
			%let varlabel&i=%sysfunc(tranwrd(%scan(%nrbquote(&&varlabel&i.),1,]),[,%str( )));
			%if %length(&Labelvar.) = 0 %then %do;
				%let labelvar = %qcmpres(&&varlabel&i..);
				%if %m_var_exist(&DataSet.,&Labelvar.)=0 %then %do;
				%put ER%STR(ROR): (&SYSMACRONAME.) Dataset not have &Labelvar. , Please checking!;
				%goto exit;
				%end;
				%if %sysfunc(indexw(%upcase(&By.),%upcase(&Labelvar.)))=0 %then %do;
					%put ER%STR(ROR): (&SYSMACRONAME.) variable &Labelvar. need write in Parametersby= , Please checking!;
					%goto exit;
				%end;
			%end;
			%else %if "&Labelvar." ^= "&&varlabel&i.." %then %do;
				%put ERR%str(OR): &Labelvar. ^= &&varlabel&i.., Parametersvarlist= are have 2 label , need the same , Please checking!!!;
				%goto exit;
			%end;
		%end;

	%let i = %eval(&i. + 1);
	%end;
	%let nvar=%eval(&i. - 1);

** By var list *;
	%let Sqlby=;
	%if %length(&by.)>0 %then %do;
		%let i = 1;
		%do %while(%qscan(%nrbquote(%qcmpres(&By.)),&i.,%str( ) ) ne %str( ));
			%global by&i.;
			%let by&i. = %sysfunc(scan(%nrbquote(&By.),&i.,%str( )));
			%if %m_var_exist(&DataSet.,&&by&i..)=0 %then %do;
				%put ER%STR(ROR): (&SYSMACRONAME.)  Parametersby= of &&by&i.. not in Dataset , Please checking!;
				%goto exit;
			%end;
			%if %length(&Sqlby.)=0 %then %let Sqlby=%qcmpres(&&by&i..);
			%else %let Sqlby = &Sqlby. ,%qcmpres(&&by&i..);
			proc sql undo_policy=none;
				create table ___Bycycle&i. as
				select distinct &Sqlby.
				from &Dataset. %if %length(&Cond.) > 0 %then where &Cond.;
			;
			quit;
			%if &i.=1 %then %let Lstbyvar=&by1.;
			%else %if &i.>1 and %length(%qcmpres(&&by&i..))>0 %then %do;
				%let ii=%eval(&i.-1);
				%if %nobs(___Bycycle&i.)^=%nobs(___Bycycle&ii.) %then %do;
					%let Lstbyvar=&&by&i..;
				%end;
			%end;
		%let i = %eval(&i. + 1);
		%end;
	%let nby=%eval(&i. - 1);
	%end;
	%else %do;
		%let by=_NOBYVARS_;
		%let by1=_NOBYVARS_;
		%let nby=1;
		%let Sqlby=_NOBYVARS_;
		%let Lstbyvar=_NOBYVARS_;
	%end;
*******************************************************************
*******************************************************************;
	ods exclude all;
** ___inds *;
	data ___inds;
		set &DataSet.; %if %length(&Cond.) > 0 %then %do; where &Cond. %end; ;_NOBYVARS_='';
		format _all_;
	run;
/*	%if %length(&FullGroup.)=0 and %nobs(___inds)=0 %then FullGroup=a;*/
** ___header *;
	data ___header;
		set &_pop_data.;
			where &_pop_Cond.;
			_Sortvar1_=1;
		_old&casevar._=&casevar.;
		keep _old&casevar._ &casevar &Group &Groupn ;
	run;
****************************************************************
add version 1.3
****************************************************************;
%let Sortvar=&Groupn.;
	proc sort data = ___header;
		by &Sortvar.;
	run;

	data ___header;
		set ___header;
		by &Sortvar.;
		retain _CustomSortvar_ 0;

		if first.&Sortvar. then
			_CustomSortvar_=_CustomSortvar_+1;
		_orgGroupvar_=&Sortvar.;
		&Groupn.=_CustomSortvar_;
		drop _CustomSortvar_;
	run;
	data ___header_allGroup;
		set ___header /*___header_trttotal ___header_total*/;
	run;

	proc sql undo_policy=none;
		create table ___header_out as
			select distinct &Group.,&Groupn.,count(distinct _old&casevar._) as _grpsum_, _orgGroupvar_
				from ___header_allGroup
					Group by &Groupn.
						order by &Groupn.
		;
	quit;
** ___inds_header *;
	proc sql undo_policy=none;
	    create table ___inds_header0 as
	        select distinct *
	        from ___header as a
	        left join ___inds(rename=(&casevar=&casevar._ind &Group=&Group._ind &Groupn=&Groupn._ind)) as b
	        on a._old&casevar._=b.&casevar._ind
	;
	quit;
	%if %length(&by) >0 and &by ^=_NOBYVARS_ %then %do;
		proc sort data=___inds(keep=&by) out=___inds_u1 nodupkey;
			by &by.;
		quit;
		%put **aa** &sqlby;
		%put _user_;
	proc sql undo_policy=none;
	    create table ___header_inds_u1 as
	        select distinct a.*,&Sqlby 
	        from ___header as a
	        left join ___inds_u1 as b
	        on a._old&casevar._
	;
	quit;
	proc sql undo_policy=none;
	    create table ___inds_header as
	        select distinct *
	        from ___header_inds_u1 as a
	        left join ___inds(rename=(&casevar=&casevar._ind &Group=&Group._ind &Groupn=&Groupn._ind
				%do i=1 %to &nby;  &&by&i..=&&by&i.._ind %end;)) as b
	        on a._old&casevar._=b.&casevar._ind 
				%do i=1 %to &nby; and a.&&by&i..=b.&&by&i.._ind %end;
	;
	quit;
/*		proc sql undo_policy=none;*/
/*		     create table ___inds_u2  as*/
/*		          select distinct a.*,b.**/
/*		          from ___inds_u1 as a */
/*		          left join ___inds_header0(where=(&casevar._ind='')) as b */
/*		          on b.&casevar._ind=''*/
/*		;*/
/*		quit;*/
/*		data ___inds_header;*/
/*			set ___inds_header0(where=(&casevar._ind^='')) ___inds_u2;*/
/*		run;*/
	%end;
	%else %do;
		data ___inds_header;
			set ___inds_header0;
		run;
	%end;
	%if %length(&FullGroup.)>0 %then
		%do;
			%let i = 1;

			%do %while(%qscan(&FullGroup.,&i.,|) ^= %str( ));
				%local fullGroup&i.;
				%let fullGroup&i.=%sysfunc(scan(&FullGroup.,&i.,|));
				%let i = %eval(&i. + 1);
			%end;

			%let nfullGroup = %eval(&i. - 1);

			data ___FullGroup;
				length &Group. $200.;

				%do i=1 %to &nfullGroup.;
					&Group. = "&&FullGroup&i.";
					&Groupn. = &i.;
					output;
				%end;

				&Group. = "&Trtname.";
				&Groupn. = 98;
				output;
				&Group. = "&Totname.";
				&Groupn. = 99;
				output;
			run;

		%end;

	** Add fullGroup *;
	%if %sysfunc(exist(___FullGroup)) %then
		%do;

			proc sql undo_policy=none;
				create table ___header_out as
					select distinct a.*,coalesce(b._grpsum_,0) as _grpsum_,b._orgGroupvar_
						from ___FullGroup as a
							left join ___header_out as b
								on a.&Group.=b.&Group.
							order by a.&Groupn.
				;
			quit;

		%end;

** ___Ltop01 *;
		data ___Ltop01;
		length _Vname_ _Vvalue_ $200;
		_Varlist_="&Varlist.";
		do i=1 to count(_Varlist_,'|');
			_Varvlmd_=strip(scan(_Varlist_,i,'|'));
			_Varn_=i;
			_Voutn_=input(strip(scan(_Varvlmd_,3,'/')),??best.);
			_Vname_=upcase(strip(scan(scan(_Varvlmd_,1,'/'),1,'-')));
			_Vlabel_=trim(scan(scan(_Varvlmd_,2,'/'),1,'\'));
			_Voutn_=input(strip(scan(_Varvlmd_,3,'/')),??best.);
			_Vmethod_=input(strip(scan(_Varvlmd_,6,'/')),??best.);
		** List all the specified value *;
			do j=1 to count(_Varvlmd_,'=');
				_Vvaluelabeln_=j;
				_Vvaluelabellist_=strip(scan(scan(_Varvlmd_,2,'/'),j+1,'\'));
				if substr(strip(_Vvaluelabellist_),1,1)^='=' then _Vvalue_=trim(scan(_Vvaluelabellist_,1,'='));
				_Vvaluelabel_=trim(scan(" "||_Vvaluelabellist_,2,'='));
				output;
				call missing(_Vvaluelabeln_,_Vvaluelabellist_,_Vvalue_,_Vvaluelabel_);
			end;
			if j<=_Vvaluelabeln_ or (missing(_Vvaluelabeln_) and j=1) then output;
		end;
		run;
		data ___Ltop01;
			set ___Ltop01;
			array a(*) _Vlabel_ _Vvalue_ _Vvaluelabel_;
			do i=1 to dim(a);
				a(i)=trim(tranwrd(a(i),"*$$$$*","="));
				a(i)=trim(tranwrd(a(i),"*$$$*","\"));
				a(i)=trim(tranwrd(a(i),"*$$*","|"));
				a(i)=trim(tranwrd(a(i),"*$*","/"));
				a(i)=tranwrd(a(i),"%'","'");
				a(i)=tranwrd(a(i),'%"','"');
				a(i)=trim(tranwrd(a(i),"*$$$$$*","%"));
				a(i)=trim(tranwrd(a(i),"*$$$$$$*","["));
				a(i)=trim(tranwrd(a(i),"*$$$$$$$*","]"));
			end;
		run;
** ___Conddsq *;
	data _null_;
		set ___header_out(where=(&Groupn. not in (98 99))) end=eof;
		&Groupn.=_n_;
		if eof then call symputx("all_trtn",strip(put(_n_,best.)));
	run;

	data ___header_out;
		set ___header_out;
		%if "&Outtotal."="0" %then
			%do;
				if &Groupn. in (98 99) then
					delete;
			%end;

		%if "&Outtotal."="1" %then
			%do;
				if &ntrtGroup. <= 1 or &ntrtGroup.=&neachGroup. then
					do;
						if &Groupn. in (98) then
							delete;
					end;

				if &neachGroup. <= 1 then
					do;
						if &Groupn. in (99) then
							delete;
					end;
			%end;

		%if "&Outtotal."="2" %then
			%do;
				if &Groupn. in (99) then
					delete;

				if &ntrtGroup. <= 1 then
					do;
						if &Groupn. in (98) then
							delete;
					end;
			%end;

		%if "&Outtotal."="3" %then
			%do;
				if &Groupn. in (98) then
					delete;

				if &neachGroup. <= 1 then
					do;
						if &Groupn. in (99) then
							delete;
					end;
			%end;
		_old&Group._=&Group.;
		_old&Group.n_=&Groupn.;
	run;

	data ___Conddsq_oldgrpn;
		set ___inds_header;
		_old&Group._=&Group.;
		_old&Group.n_=&Groupn.;
	run;
	
	** Recreate &Groupn. to Sort *;
	proc sql undo_policy=none;
		create table ___Conddsq_newgrp as
		select distinct a.*,b.&Groupn.
		from ___Conddsq_oldgrpn(drop=&Groupn.) as a
		right join ___header_out as b on a.&Group. = b.&Group.
		;
	quit;

	data ___Conddsq_raw;
		length _Vvalue_ _Vname_ $200;
		set ___Conddsq_newgrp;
		%do i=1 %to &nvar.;
			_Vvalue_ = &&varname&i..;
			_tablesGroupn_=&Groupn.;
			_Varn_ = &i.;
			_Vname_ = "%upcase(&&varname&i..)";
			_Voutn_ = &&varoutn&i..;
			_Vmethod_ = &&varmethod&i..;
			output;
		%end;
	run;
	data ___Conddsq_total;
		set ___Conddsq_raw;
		&Groupn. = 99;
			&Group. = "&Totname";
		_tablesGroupn_=&Groupn.;
	run;
	data ___Conddsq;
		set ___Conddsq_raw  ___Conddsq_total;
	run;

** ___Ltop_model_d *;
	** Get key variables *;
	proc sql undo_policy=none;
		create table ___Ltop01_dis as
		select distinct _Varn_, _Vname_, _Vlabel_,_Voutn_,_Vmethod_
		from ___Ltop01
		;
	** Go and get the unique tag again *;
	data ___Ltop_model;
		set ___Ltop01;
	run;
	%if %length(&by.)>0 %then %do;
		** Add by cycle *;
		proc sql undo_policy=none;
			create table ___Conddsq_key_by as
			select distinct &Sqlby.
			from ___inds
			order by &Sqlby.
			;
		quit;
		** Join by variables *;
		data ___Conddsq_key_by;
			set ___Conddsq_key_by;
			j=_n_;
		run;
		** Derived a data set of &By. * %nobs(___Ltop_model)*;
		data ___Ltop_model_c;
		set ___Ltop_model;
			do i=1 to %nobs(___Conddsq_key_by);
			output;
			end;
		run;
		** ___Ltop_model_d *;
		proc sql undo_policy=none;
			create table ___Ltop_model_d(drop=i j) as
			select *
			from ___Ltop_model_c as a
			left join ___Conddsq_key_by as b on a.i = b.j
			;
		quit;
	%end;
	%else %do;
		data ___Ltop_model_d;
			set ___Ltop_model;
		run;
	%end;
** ___report_out_05 *;
	proc sort data=___Conddsq out=___Conddsq_allGroup(where=(^missing(&Casevar ))) ;
		by &By. &Groupn. &Group. _Varn_ _Vname_;
	quit;

	proc freq data=___Conddsq_allGroup noprint;
		by &By. &Groupn. &Group.  _Varn_ _Vname_ ;
		tables _Vvalue_*_tablesGroupn_ /
		%if "&Missing."="1" %then %do; missing %end; %else %do; missprint  %end;  nowarn
		out= ___report_out_01 ;
	run;

	** Add Total number of subject per each by *;
	proc sql undo_policy=none;
		create table ___report_out_02 as
			select distinct *, sum(COUNT) as TOT
			from ___report_out_01(where=(^missing(_Vvalue_)))
			group by  %if %length(&by.)>0 %then %do;&sqlby.,%end;&Groupn. ,_Varn_, _Vname_
	;
	quit;
	** Transpose *;
	proc sort data = ___report_out_02;by &By.  _Varn_ _Vname_ _Vvalue_ &Groupn.; run;
	proc transpose data = ___report_out_02 out = ___report_out_02_n suffix=n  prefix=_;
		by &By.  _Varn_ _Vname_ _Vvalue_;
		id &Groupn.;
		idlabel &Group.;
		var count;
	run;

	proc transpose data = ___report_out_02 out = ___report_out_02_percent suffix=percent prefix=_;
		by &By.  _Varn_ _Vname_ _Vvalue_;
		id &Groupn.;
		idlabel &Group.;
		var percent;
	run;

	proc sql undo_policy=none;
		create table ___report_out_02_totpre as
		select distinct %if %length(&by.)>0 %then %do;&sqlby.,%end;_Varn_, _Vname_,&Groupn., &Group., tot
		from ___report_out_02
		order by %if %length(&by.)>0 %then %do;&sqlby.,%end;_Varn_, _Vname_
	;
	quit;

	proc transpose data = ___report_out_02_totpre out = ___report_out_02_tot suffix=tot prefix=_;
		by &By.  _Varn_ _Vname_;
		id &Groupn.;
		idlabel &Group.;
		var TOT;
	run;

	data ___report_out_03(drop = _name_ _label_);
		merge ___report_out_02_n
		___report_out_02_percent;
		by &By.  _Varn_ _Vname_ _Vvalue_;
	run;

	** Join _Ltop model and value *;
	proc sort data = ___Ltop_model_d; by &By. _Varn_ _Vvalue_;run;
	proc sort data = ___report_out_02_tot ;by &By. _Varn_ ;run;
	data ___report_out_04;
		merge ___Ltop_model_d ___report_out_03 ;
		by &By. _Varn_ _Vvalue_;
	run;
	data ___report_out_05;
		merge ___report_out_04 ___report_out_02_tot;
		by &By. _Varn_ ;
	run;

** only output route cat *;
	** ___table_rtf_varlabel cat main line dataset *;
	data ___table_rtf_varlabel;
		length _text1  $200;
		set ___report_out_05;
		
		%do i=1 %to &nvar.;
			%if %length(&Labelvar.)>0 %then %do;
				if ksubstr(strip(_Vlabel_),1,1)="[" then do;
					if _varn_=&i. then _text1= &Labelvar. ;
				end;
				else if ^missing(_Vlabel_) then _text1= _Vlabel_ ;
			%end;
			%else %do;
/*				if _varn_=&i. then _text1="&&varlabel&i";*/
				if _varn_=&i. then _text1=_Vlabel_;
			%end;
		%end;
		_Vvaluelabeln_=0;
		keep _text1 &By.  _Varn_ _Vname_ _Vvaluelabeln_ ;
	run;
	data ___table_rtf_varlabel_gh;
		set ___table_rtf_varlabel;
	run;
	proc sort data=___table_rtf_varlabel  ;
		by &By. _Varn_ descending _text1;
	quit;
	proc sort data=___table_rtf_varlabel  nodupkey;
		by &By. _Varn_;
	quit;
	** ___table_rtf_cat cat son of line dataset *;
	proc sort data=___report_out_05 ;
		by &By.  _Varn_  _Vvaluelabeln_;
	quit;

	data ___table_rtf_cat;
		length _text1 _text2 %do trt_n=1 %to &all_trtn ; _ngc&trt_n. %end; _ngc99 $200;
		set ___report_out_05;
		where ^missing(_Varlist_);
		by &By.  _Varn_  _Vvaluelabeln_;
		%do i=1 %to &nvar.;
			if _varn_=&i. then _text1=coalescec(_Vvaluelabel_);
		%end;
		%do trt_n=1 %to &all_trtn ;
			_ngc&trt_n.= strip(put(coalesce(_&trt_n.n,0),best.))
			||"("
			||coalescec(strip(put(_&trt_n.percent,12.&Prec.)),'0')
			||")"
			;
			if _ngc&trt_n.='0 (0)' or _ngc&trt_n.='0(0)' then _ngc&trt_n.='0';
			%if &Prec. = 1 %then %do; _ngc&trt_n.=tranwrd(_ngc&trt_n.,'100.0','100'); %end;
			%else %if &Prec. =2 %then %do; _ngc&trt_n.=tranwrd(_ngc&trt_n.,'100.00','100'); %end;
		%end;
			_ngc99= strip(put(coalesce(_99n,0),best.))
			||"("
			||coalescec(strip(put(_99percent,12.&Prec.)),'0')
			||")"
			;
			if _ngc99='0 (0)' or _ngc99='0(0)' then _ngc99='0';
			%if &Prec. =1 %then %do;  _ngc99=tranwrd(_ngc99,'100.0','100'); %end;
			%else %if &Prec. =2 %then %do;  _ngc99=tranwrd(_ngc99,'100.00','100'); %end;
		if strip(_Vname_) in (%unquote(&NoperVval.)) then do;
		%do trt_n=1 %to &all_trtn ;
			_ngc&trt_n.= strip(put(coalesce(_&trt_n.n,0),best.));
		%end;
			_ngc99= strip(put(coalesce(_99n,0),best.));
		end;
		_text2='n(%)';
		keep _text1 _text2 
				%do trt_n=1 %to &all_trtn ; _ngc&trt_n. %end; _ngc99
				 &By.  _Varn_ _Vname_ _Vvaluelabeln_;
	run;
	** ___table_rtf_tot 
	*;
	** calculate every group total number *;
	data ___Conddsq_newgrp_total;
		set ___Conddsq_newgrp;
		&Groupn. = 99;
		%if %upcase("&_rtffmt.") = "EN" %then %DO ;&Group. = "Total";;%end;
		%else %DO ;&Group. = "&Totname";;%end;
	run;
	data ___Conddsq_newgrp0;
		set ___Conddsq_newgrp  ___Conddsq_newgrp_total;
	run;

	proc sql undo_policy=none;
		create table ___Conddsq_newgrp1 as
		select distinct &Casevar.,&Groupn.,&Group.
		from ___Conddsq_newgrp0 as a
		;
	quit;
	proc sql undo_policy=none;
	    create table ___Conddsq_newgrp2 as
	        select distinct &Groupn.,&Group.,count(&Casevar.) as _grp
	        from ___Conddsq_newgrp1 
			group by  &Groupn.,&Group.
			order by  &Groupn.,&Group.
	;
	quit;
	data _null_;
		set ___Conddsq_newgrp2;
		call symputx('_GRP_'||strip(put(&Groupn.,best.)),strip(put(_grp,best.)),'G');
	run;

	data ___table_rtf_tot;
		length _text1  _text2 $200;
		set ___report_out_05;
		%do i=1 %to &nvar.;
			%if &&varoutn&i = 0 %then %do;
				if _varn_=&i. then do;_text1="";_Vvaluelabeln_=.;
				%do trt_n=1 %to &all_trtn ;
					_ngc&trt_n.=""; 
				%end;
				end;
				_ngc99=""; 
			%end;
			%else  %do;
				if _varn_=&i. then do; %if %upcase("&_rtffmt.") = "EN" %then %do;_text1="    Total";%end;%else %do;_text1="    &Totname";;%end;
				%do trt_n=1 %to &all_trtn ; 	
					_ngc&trt_n.= strip(put(coalesce(_&trt_n.tot,0),best.))
						||"("
						||strip(put(coalesce(&&_GRP_&trt_n.,0)-coalesce(_&trt_n.tot,0),best.))
						||")";
				 %end;
					_ngc99= strip(put(coalesce(_99tot,0),best.))
						||"("
						||strip(put(coalesce(&&_GRP_99,0)-coalesce(_99tot,0),best.))
						||")";
				%if &&varoutn&i = 1 %then %do;_Vvaluelabeln_=99;%end;
				%else %if &&varoutn&i = 2 %then %do;_Vvaluelabeln_=0.5;%end;
				end;
			%end;
		%end;
		_text2='n(miss)';
		keep _text1 _text2 &By.  _Varn_ _Vname_ _Vvaluelabeln_  %do trt_n=1 %to &all_trtn ; _ngc&trt_n. %end; _ngc99 ;
	run;
	proc sort data=___table_rtf_tot nodupkey;
		by &By. _Varn_;
	quit;

	data ___table_rtf_set;
		set ___table_rtf_varlabel(where=(^missing(_text1))) ___table_rtf_cat(where=(_Vvaluelabeln_^=.))
			 ___table_rtf_tot(where=(^missing(_text1)));
	run;
*******************************************************************
Step3.delete mid dataset and output
*******************************************************************;
	proc sort data=___table_rtf_set out=&Outds._sort;
		by &By.  _Varn_ _Vname_ _Vvaluelabeln_;
	quit;
*******************************************************************
Step4.p_value output
*******************************************************************;

	%local ctgroup;

	proc sql noprint;
		select distinct max(&groupn.) into :maxnumgroupn from ___HEADER_OUT;
		select distinct min(&groupn.) into :minnumgroupn from ___HEADER_OUT;

		%** Get the new groupn for the ctgroup *;
		%if %length(&ctgroup.)>0 %then
			%do;
				select distinct &Groupn. into: CTGroupn from ___HEADER_OUT where &Group.=&ctgroup.;
			%end;
	quit;

	%if %length(&ctgroup.)=0 %then
		%do;
			%let CTGroupn=&minnumgroupn.;
		%end;

					data ___Pvalue_01;
						set ___Conddsq_allGroup;
						where _Vmethod_>0 and ^missing(_Vvalue_);
						if &Groupn. in (98 99) then delete;
						_NOBYVARS_="";
					run;

					%if %nobs(___Pvalue_01)>0 %then
						%do;

									data ___Pvalue_02;
										set ___Pvalue_01;
										_pvalue_ID_=&maxnumgroupn.;
									run;


							proc sql undo_policy=none;
								create table ___Pvalue_03 as
									select *, count(distinct _Vvalue_) as nvaluespervar
										from ___Pvalue_02
											Group by _pvalue_ID_, &Sqlby., _Varn_
												having nvaluespervar>1
													order by _pvalue_ID_, &Sqlby., _Varn_, _Vmethod_
								;
							quit;

							%if %nobs(___Pvalue_03)>0 %then
								%do;
									ods exclude all;

									proc freq data=___Pvalue_03 noprint;
										by _pvalue_ID_ &By. _Varn_ _Vmethod_;

										table _Vvalue_*&Groupn./alpha=0.05 sparse fisher chisq nowarn;
											output out=___Pvalue_04(keep= &By. _Varn_ _pvalue_ID_ _Vmethod_ _PCHI_ P_PCHI XP2_FISH) ChiSq Fisher;
									quit;
								%if %nobs(___Pvalue_04)=0 %then
									%do;
									data ___Pvalue_04;
										set ___Pvalue_04;
										array tt(*) %if &By.^=_NOBYVARS_ %then &By.; _Varn_ _pvalue_ID_ _Vmethod_ _PCHI_ P_PCHI XP2_FISH;
										array ttc(*) $200 %if &By.=_NOBYVARS_ %then &By.;;
									run;

									%end;

									ods exclude none;

									** Method=4, Select statistical method *;
									ods exclude all;

									proc Freq data=___Pvalue_03 noprint;
										by _pvalue_ID_ &By. _Varn_;
										tables _Vvalue_*&Group./alpha=0.05 expected outexpect nowarn out=___Pvalue_03_EXPECTED_01;
									run;

									ods exclude none;
									data ___Pvalue_03_EXPECTED_01;
										set ___Pvalue_03_EXPECTED_01;_NOBYVARS_='';
									run;
									proc sql undo_policy=none;
										create table ___Pvalue_03_EXPECTED_02 as
											select distinct _pvalue_ID_, &Sqlby., _Varn_, int(min(EXPECTED)) as INTMINEXPECTED
												from ___Pvalue_03_EXPECTED_01
													Group by _pvalue_ID_, &Sqlby., _Varn_
														order by _pvalue_ID_, &Sqlby., _Varn_
										;
									quit;

									** Add condition: simple size >= 40 *;
									proc sql undo_policy=none;
										create table ___Pvalue_03_SimpleSize as
											select distinct _pvalue_ID_, &Sqlby., _Varn_, count(*) as SimpleSize
												from ___Pvalue_03
													Group by _pvalue_ID_, &Sqlby., _Varn_
														order by _pvalue_ID_, &Sqlby., _Varn_
										;
									quit;

									proc sort data = ___Pvalue_04;
										by _pvalue_ID_ &By. _Varn_;
									run;

									data ___Pvalue_05;
										merge
											___Pvalue_04
											___Pvalue_03_EXPECTED_02(keep=_pvalue_ID_ &By. _Varn_ INTMINEXPECTED)
											___Pvalue_03_SimpleSize(keep=_pvalue_ID_ &By. _Varn_ SimpleSize);
										by _pvalue_ID_ &By. _Varn_;
									run;

									data ___Pvalue_06;
										set ___Pvalue_05;
										length _Chisquare_ _Fishers_ P S $200.;

                %** P-value(ChiSq) *;
				if P_PCHI>.999 then _Chisquare_='>0.999'||" 卡方检验";
				else if .<P_PCHI<.001 then _Chisquare_='<0.001'||" 卡方检验";
                else if ^missing(P_PCHI) then _Chisquare_=compress(put(P_PCHI,pvalue6.3))||" 卡方检验";
                %** P-value(Fisher) *;
				if XP2_FISH>.999 then _Fishers_='>0.999'||" Fisher精确概率";
				else if .<XP2_FISH<.001 then _Fishers_='<0.001'||" Fisher精确概率";
                else if ^missing(XP2_FISH) then _Fishers_=compress(put(XP2_FISH,pvalue6.3))||" Fisher精确概率";

										 if ^missing(_PCHI_) then
											_ChisquareStat_=compress(put(_PCHI_,32.3));


										if _Vmethod_=1 then
											P=_Fishers_;
										else if _Vmethod_=2 then
											P=_Chisquare_;
										else if _Vmethod_=4 then
											do;
												if SimpleSize>=40 and INTMINEXPECTED>=5 then
													P=_Chisquare_;
												else P=_Fishers_;
											end;

										___Flag="P";
										output;

										if _Vmethod_=2 or (_Vmethod_=4 and SimpleSize>=40 and INTMINEXPECTED>=5 ) then
											S=_ChisquareStat_;
										else S="-";
										___Flag="S";
										output;
									run;

									%if %nobs(___Pvalue_06)>0 %then
										%do;

											proc sort data = ___Pvalue_06;
												by &By. _Varn_ _pvalue_ID_;
											run;

											proc transpose data=___Pvalue_06 out=___Pvalue_07(drop=_name_) prefix=p_value;
												where ___Flag="P";
												by &By. _Varn_;
												var P;
/*												id _pvalue_ID_;*/
											quit;

													proc transpose data=___Pvalue_06 out=___Pvalue_07_S(drop=_name_) prefix=s_value;
														where ___Flag="S";
														by &By. _Varn_;
														var S;
/*														id _pvalue_ID_;*/
													quit;
											data ___Pvalue_07_p;
												set ___Pvalue_07;
												p_value=strip(scan(p_value1,1,''));
												_method=strip(scan(p_value1,2,''));
											run;
											proc sql undo_policy=none;
											     create table &Outds._sort  as
											          select distinct a.*,c.s_value1 as s_value ,b.p_value,b._method
											          from &Outds._sort as a 
											          left join ___Pvalue_07_p as b 
											          on a._Varn_=b._Varn_ and a._Vvaluelabeln_=1 			
%do i=1 %to &nby; and a.&&by&i..=b.&&by&i.. %end;

											          left join ___Pvalue_07_S as c 
											          on a._Varn_=c._Varn_ and a._Vvaluelabeln_=1
%do i=1 %to &nby; and a.&&by&i..=c.&&by&i.. %end;
											;
											quit;
											data &Outds._sort;
												set &Outds._sort;
												if _Vvaluelabeln_=1 then do;
													s_value=coalescec(s_value,'-');
													p_value=coalescec(p_value,'-');
													_method=coalescec(_method,'-');
												end;
											run;
										%end;
								%end;
								%else %do;
											data &Outds._sort;
												set &Outds._sort;
												if _Vvaluelabeln_=1 then do;
													s_value='-';
													p_value='-';
													_method='-';
												end;
											run;

								%end;
						%end;


	proc sort data=&Outds._sort out=&Outds.(drop=&By.  _Varn_ _Vname_ _Vvaluelabeln_);
		by &By.  _Varn_ _Vname_ _Vvaluelabeln_;
	quit;
	%if "&Debug." ^= "1" %then %do;
		proc datasets nolist nodetails NoWarn lib=work;
		delete ___:  
		%if "&Endline." ^= "0" %then %do;
			&Outds._sort
		%end;
		/memtype=data;
		quit;
	%end;

	%exit:
ods exclude none;
%mend;