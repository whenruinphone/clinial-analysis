/*************************************************************************************************
File name: quandesc-v1-13.sas

Study:

SAS version: 9.4

Purpose: DINGLIANG

Macros called: %m_var_exist  %nobs  %m_significant_digit 

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 23AUG2023

Date completed: 23AUG2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0  23AUG2023 Hao.Guo create
1.1  27FEB2024 Hao.Guo add type=1 for name and statistic on a line
1.2  29MAR2024 Hao.Guo CHANGE the macro variable _grp_n to just depend on then popn
1.3  20AUG2024 Hao.Guo CHANGE THE REPEAT FUNCTION WHERN &I=1
1.4  04SEP2024 Hao.Guo OUTDS Default
1.5  26SEP2024 Hao.Guo change left join keyvar of type=1 when by=param
1.6  12OCT2024 Hao.Guo change _text1 include param avisit when by=param avisit
								add log infomation ***treatment group&lp num is &&_GRP_&lp;
1.7  12OCT2024 Hao.Guo add pvalue
1.8  20JAN2025 Hao.Guo add pvalue when use by
1.9  21JAN2025 Hao.Guo  1.resolve,_grp_trtan and trtan is not resort num
						2.ADD P_Vvaluelabeln
1.10  23JAN2025 Hao.Guo  1.add total of paried t test value
						2.defualt wilcoxn pvalue change form else wil_t=1 to wil_normal=1
1.11 26JAN2025 Hao.Guo 	update s value when le 0.001 format
1.12 27JAN2025 Hao.Guo 	update pvalue warning whern paried t test
1.13 07FEB2025 Hao.Guo 	ADD Max_dlen= : keep 4 scdight when scdight gt 4
								2._npar1way = _Vvalue_ form ISIS keep 5 decimal
1.14 08FEB2025 Hao.Guo 	format pvalue debug

*********************************** Prepared by Highthinkmed ************************************/
%macro Quandesc(
DataSet=                     
,Cond=                       
,Popn=                        
,Casevar= USUBJID           
,Group= TRT01P               
,Groupn=                   
,Varlist=  
,type= 
,By=                      
,Listvars=                  
,PmKeywordList=             
,Round_3_scdigit=         
,Enotation= 
,Ltopformat=                 
,LLOQ=                       
,Preblank= %str(  )         
,Sdsemna=                 
,EndLine= 1                 
,Debug= 0                    
,OutDs=_table_rtf

,Pvaluetype= /*1.two tow compare and must have ctgroup 
				2.mutiple compare ,cant output total pvalue ,formatble for anova and wilcoxn */
,Ctgroup=
,P_Vvaluelabeln=1
,Max_dlen=
) / store;
    %put Running Macro (&SYSMACRONAME. V1.14);

ods exclude all;
%global ESCAPECHAR;
%let _MacroDigitName=M_SIGNIFICANT_DIGIT;
%let _BQL=BQL;
%let OutStat=;
%let Nmisstype= 1 ;
%let outtotalpvalue=0;
%if %length(&SDSEMNA.)=0 %then %let SDSEMNA=NA;
%if %length(&Enotation.)=0 %then %let Enotation=0;

data ___inds;
	set &DataSet.; %if %length(&Cond.) > 0 %then %do; where &Cond. %end; ;
	format _all_;
run;
%if %length(&popN)>0 %then %do;
	%let _pop_Cond=%sysfunc(scan(&Popn,2,|));
	%let _pop_data=%sysfunc(scan(&Popn,1,|));
%end;
%else %if %sysfunc(exist(adam.adsl)) %then %do;
	%let _pop_cond=1;
	%let _pop_data=adam.adsl;
%end;
%else %do;
	%put ER%STR(ROR): (&SYSMACRONAME.) The parameter popn can not be null, please check!;
	%goto exit;
%end;
%if %length(&_pop_cond.)=0 %then %let _pop_cond=1;

%if %sysfunc(exist(&_pop_data.))=0 %then %do;
	%put ER%STR(ROR): (&SYSMACRONAME.) The dataset &_pop_data. do not exist, please check the parameter popn!;
	%goto exit;
%end;

%if %length(&PvalueType.)=0 %then %let PvalueType=1;
	%if %length(&OutDs.)=0 		%then %let OutDs=_table_rtf;

data ___header;
	set &_pop_data.;
		where &_pop_Cond.;
		_Sortvar1_=1;
	_old&casevar._=&casevar.;
	keep _old&casevar._ &casevar &Group &Groupn ;
run;
proc sql undo_policy=none;
    create table ___inds_header as
        select distinct *
        from ___header as a
        left join ___inds(rename=(&casevar=&casevar._ind &Group=&Group._ind &Groupn=&Groupn._ind)) as b
        on a._old&casevar._=b.&casevar._ind
;
quit;

	%symdel  nby nvar LABELVAR SQLBY Listvarname Outpvalue/nowarn ;
	%local nby nvar LABELVAR SQLBY Listvarname Outpvalue ;
** Listvars *;
	%let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(%|),%nrbquote(*$*)));
	%let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(//),%nrbquote(/ /)));
	%let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(//),%nrbquote(/ /)));
	%let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(/\),%nrbquote(/ \)));
	%let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(\\),%nrbquote(\ \)));

	%let i = 1;
	%local nlistvars;
	%let nlistvars=0;
	%if %length(&Listvars.)>0 %then %do;
		%do %while(%qscan(&Listvars.,&i.,|) ^= %str( ));
			%local listvar&i. Listvarname&i.;
			%let listvar&i. = %sysfunc(scan(&Listvars.,&i.,|));
			%let Listvarname&i. = %sysfunc(scan(&&listvar&i..,1,/));
			%if %length(&Listvarname.) = 0 %then %do;
				%let Listvarname = %qcmpres(&&Listvarname&i..);
				%if %m_var_exist(&DataSet.,&Listvarname.)=0 %then %do;
					%put ER%STR(ROR): (&SYSMACRONAME.) The variable &Listvarname. is not in the dataset, please check!;
					%goto exit;
				%end;
				%if %sysfunc(indexw(%upcase(&By.),%upcase(&Listvarname.)))=0 %then %do;
					%put ER%STR(ROR): (&SYSMACRONAME.) The list variable &Listvarname. need to be listed in the by parameter!;
					%goto exit;
				%end;
			%end;
			%else %let Listvarname = &Listvarname. %qcmpres(&&Listvarname&i..);
			%let i = %eval(&i. + 1);
		%end;
		%let nlistvars = %eval(&i. - 1);
	%end;
	%let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(*$*),%nrbquote(%|)));

** Varlist *;
	%let i = 1;
	%let separator=/;
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%/),%nrbquote(*$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%|),%nrbquote(*$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%\),%nrbquote(*$$$*)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(//),%nrbquote(/ /)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(//),%nrbquote(/ /)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(/\),%nrbquote(/ \)));
	%let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(\\),%nrbquote(\ \)));
	%do %while (%qscan(%nrbquote(&Varlist.),&i.,|) ne %str( ));
		%symdel varvlmd&i varname&i varlabel&i varmethod&i Vardigit&i varmethodmatch&i. match&i. wilcoxonp&i. varnameSort&i varSort&i Outpvaluematch/ NOWARN;
		%local varvlmd&i varname&i varlabel&i varmethod&i Vardigit&i varmethodmatch&i. match&i. wilcoxonp&i. varnameSort&i varSort&i Outpvaluematch;
		%let varvlmd&i. = %qcmpres(%qscan(%nrbquote(&Varlist.),&i.,|));
		%let varnamesort&i. = %qscan(%nrbquote(&&varvlmd&i..),1,/);
		%let varname&i. = %upcase(%qscan(%nrbquote(&&varnamesort&i..),1,-));
		%let varsort&i. = %qscan(%nrbquote(&&varnamesort&i..),2,-);
		%let varlabel&i = %qcmpres(%sysfunc(scan(%nrbquote(&&varvlmd&i..),2,/)));
		%let varlabel&i = %sysfunc(tranwrd(%nrbquote(&&varlabel&i..),%nrbquote(*$*),%nrbquote(/)));
		%let varlabel&i = %sysfunc(tranwrd(%nrbquote(&&varlabel&i..),%nrbquote(*$$*),%nrbquote(|)));
		%let varlabel&i = %sysfunc(tranwrd(%nrbquote(&&varlabel&i..),%nrbquote(*$$$*),%nrbquote(\)));
		%if %length(%nrbquote(&&varlabel&i..))=0 %then %let varlabel&i.="";
		%let varmethod&i = %qcmpres(%sysfunc(scan(%str( )%sysfunc(scan(%nrbquote(&&varvlmd&i..),3,/)), 1, \)));
		%let Vardigit&i = %qcmpres(%sysfunc(scan(%nrbquote(&&varvlmd&i..),2,\)));

		%if %index(&&varmethod&i..,[) %then %do;
			%let wilcoxonp&i.=%sysfunc(compress(%sysfunc(scan(&&varmethod&i..,2,[)),]));
			%let varmethod&i=%sysfunc(scan(&&varmethod&i..,1,[));
		%end;
		%else %if &&varmethod&i..= %then %let varmethod&i=0;
		%let match&i.=%sysfunc(compress(%qscan(%qscan(%nrbquote(&&varvlmd&i..),1,\),4,/)));
		%if &&varmethod&i..>0 %then %let Outpvalue=1;
		%if %length(&&match&i..)=0 %then %let match&i.=0;
		%if &&match&i..>0 %then %let Outpvaluematch=1;
		%if &&varmethod&i..=2 or &&varmethod&i..=3 %then %do;
			%let Outpvaluewilcoxonp=1;
			%if %length(&&wilcoxonp&i..)=0 %then %let wilcoxonp&i.=2;
		%end;
		%else %let wilcoxonp&i.=0;

		%** When &&varmethod&i.. > 0 then Work;
		%if &&varmethod&i.. > 0 %then %do;
			%if &PvalueType.=1 %then %do;
				%if %length(&ctgroup.)=0 %then %do;
					%put ER%STR(ROR): (&SYSMACRONAME.) If PvalueType eq to 1 then parameter ctgroup should not be null, please check parameter ctgroup!;
					%goto exit;
				%end;
			%end;
			%if &PvalueType.=2 %then %do;
				%if &&varmethod&i..=1 or &&varmethod&i..=4 or &&varmethod&i..=5 %then %do;
					%put ER%STR(ROR): (&SYSMACRONAME.) If Pvalue method in 1, 4, 5 then PvalueType should be eq to 1, please check parameter PvalueType!;
					%goto exit;
				%end;
			%end;
		%end;
		** Check digit var *;
		%if %length(&&Vardigit&i..) = 0 %then %do;
			%put ERR%str(OR): (&SYSMACRONAME.) Need to fill in how to retain the decimal digits, Please check!!!;
			%goto exit;
		%end;
	%let i = %eval(&i. + 1);
	%end;
	%let nvar=%eval(&i. - 1);

** By var list *;
	%let Sqlby=;
	%if %length(&by.)>0 %then %do;
		%let i = 1;
		%let ii=;
		%do %while(%qscan(%nrbquote(%qcmpres(&By.)),&i.,%str( ) ) ne %str( ));
			%local by&i.;
			%let by&i. = %sysfunc(scan(%nrbquote(&By.),&i.,%str( )));
			%if %m_var_exist(&DataSet.,&&by&i..)=0 %then %do;
				%put ER%STR(ROR): (&SYSMACRONAME.) The variable by&i. = -- &&by&i.. -- is not in the dataset -- &DataSet. --, please check 234!;
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
		%let by=;
		%let by1=;
		%let nby=1;
		%let Sqlby=;
		%let Lstbyvar=;
	%end;

** In order to go back *;
	%SYMDEL Keepvars1 Keepvars2 Keepvars3 /NOWARN;
	%local Keepvars1 Keepvars2 Keepvars3;
	%let Keepvars1=%qcmpres(%upcase(&By. &Groupn. &Group. _Varn_ _Vname_ _Vlabel_ _Vdigit_ &Listvarname. ));
	%let i=1;
	%do %while(%qscan(&Keepvars1.,&i.,%str( ))^=%str( ));
		%local keepvar&i. ;
		%let keepvar&i=%sysfunc(scan(&Keepvars1.,&i.,%str( )));
		%if %sysfunc(findw(&Keepvars2,&&keepvar&i..))=0 %then %do;
			%let Keepvars2=&Keepvars2. &&keepvar&i..;

			%** Do not keep Group variables *;
			%if "&&keepvar&i.."^="%cmpres(%upcase(&Group.))" and "&&keepvar&i.."^="%cmpres(%upcase(&Groupn.))" %then %do;
				%let Keepvars3=&Keepvars3. &&keepvar&i..;
			%end;
		%end;
		%let i = %eval(&i. + 1);
	%end;

** Pmkeywords *;
data ___Keyword;
	length PmKeywords lag_column KeywordColumn $ 200;
	retain KeywordVarName PmKeywords;
	PmKeywordList = strip("&PmKeywordList");
	if substr(reverse(PmKeywordList),1,1) = "|" then PmKeywordList = substr(PmKeywordList,1,length(PmKeywordList)-1);

	do Row = 1 to count(PmKeywordList, "|") + 1;
	KeywordRow = scan(PmKeywordList, Row, "|");
	LtopFormat0 = prxchange('s/([A-Za-z0-9]+)\+?(\d?)/$1/', -1, KeywordRow);

	Pattern = prxchange('s/([A-Za-z0-9]+)\+?(\d?)/"||strip(_vvalue__$1c)||"/', -1, KeywordRow);
	if count(Pattern,"_vvalue_") = 1 then Pattern = compress(Pattern,'"|');
	else if count(Pattern,"_vvalue_") > 1 then do;
	if substr(Pattern,1,3) = '"||' then Pattern = substr(Pattern,4); else Pattern = cats('"', Pattern);
	if substr(reverse(strip(Pattern)),1,3) = '"||' then Pattern = substr(Pattern,1,length(Pattern)-3); else Pattern = cats(Pattern, '"');
	end;

	id = prxparse('/([A-Za-z0-9]+)\+?(\d?)/');
	start = 1;
	stop = lengthn(KeywordRow);
	column = 0;

	if stop ^= 0 then do;
	call prxnext(id,Start,Stop,KeywordRow,Position,Length);
	do while (Position gt 0);
	column + 1;
	if column ne 1 and upcase(KeywordColumn) in ("STDDEV" "STDERR") then lag_column=KeywordColumn; else lag_column = "";
	KeywordColumn = prxposn(id,1,KeywordRow);
	PmKeywords = catx(" ", PmKeywords, KeywordColumn);
	KeywordPrec = prxposn(id,2,KeywordRow);
	if missing(KeywordPrec) then KeywordPrec = "0";

	if column = 1 then KeywordVarName = upcase(KeywordColumn);
	else KeywordVarName = upcase(cats(KeywordVarName, "_",KeywordColumn));

	LtopFormat = LtopFormat0;
	if upcase(lag_column)="STDDEV" then LtopFormat = tranwrd(LtopFormat, strip(vvalue(lag_column)), "SD");
	if upcase(KeywordColumn)="STDDEV" then LtopFormat = tranwrd(LtopFormat, strip(vvalue(KeywordColumn)), "SD");
	if upcase(KeywordColumn)="STDERR" then LtopFormat = tranwrd(LtopFormat, strip(vvalue(KeywordColumn)), "SEM");
	output;
	call prxnext(id,Start,Stop,KeywordRow,Position,Length);
	end;
	end;
	end;
	drop lag_column LtopFormat0 id Start Stop Position Length;
run;

** Create Macro Variables *;
data _null_;
	retain pmLtopVarname; length pmLtopVarname $ 200;
	set ___Keyword end=last;
	By Row Column notSorted;
	if last.Row then do;
	pmLtopVarname = catx(" ", pmLtopVarname, KeywordVarName);
	call symputx('pmLtopVarname'||strip(put(Row,best.)) ,strip(KeywordVarName),'G');
	call symputx("npmLtopkeyword"||strip(put(Row,best.)),strip(put(Column,best.)),'G');
	call symputx('Ltopformat'||strip(put(Row,best.)) ,strip(LtopFormat),'G');
	call symputx('keywordPattern'||strip(put(Row,best.)),strip(Pattern),'G');
	end;
	call symputx ('pmLtop'||strip(put(Row,best.))||'keyword'||strip(put(Column,best.)), strip(KeywordColumn),'G');
	call symputx ('pmLtop'||strip(put(Row,best.))||'keyword'||strip(put(Column,best.))||'c', strip(KeywordColumn)||'c','G');
	call symputx ('pmLtop'||strip(put(Row,best.))||'prec'||strip(put(Column,best.)), strip(KeywordPrec),'G');
	if last then do;
	call symputx("nPmLtopkeyword",strip(put(Row,best.)),'G');
	call symputx("nPmKeywords" ,strip(put(_n_,best.)),'G');
	call symputx("PmKeywords" ,strip(PmKeywords),'G');
	call symputx("pmLtopVarname" ,strip(pmLtopVarname),'G');
	end;
run;

*******************************************************************
重新定义组别序号 groupn 的值
*******************************************************************;
proc sql undo_policy=none;
    create table ___unique_group_01 as
        select distinct &Groupn., &Group.
        from ___inds_header
;
quit;
data ___unique_group_02;
	set ___unique_group_01 end=eof;
	&Groupn.=_n_;
	if eof then call symputx("all_trtn",strip(put(_n_,best.)),'G');
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
	left join ___unique_group_02 as b on a.&Group. = b.&Group.
	;
quit;
data ___Conddsq_raw;
	length _Vvalue_ 8 _Vname_ _Vlabel_ $200;
	set ___Conddsq_newgrp;
	%do i=1 %to &nvar.;
		_Vname_ = "&&varname&i..";
		_Vlabel_ = %unquote(&&varlabel&i..);
		_Vvalue_ = %unquote(&&varname&i..);
		if %unquote(&&varname&i..)>0 then _Vlogvalue_ = log(%unquote(&&varname&i..));
		_Vmethod_ = %unquote(&&varmethod&i..);
		_wilcoxonp_ = %unquote(&&wilcoxonp&i..);
		_match_ = %unquote(&&match&i..);
		_Vdigit_ = %unquote(&&Vardigit&i..);
		_Varn_ = &i.;
		output;
	%end;
run;
data ___Conddsq_total;
	set ___Conddsq_raw;
	&Groupn. = 99;
	&Group. = "合计";
	_tablesGroupn_=&Groupn.;
run;
data ___Conddsq;
	set ___Conddsq_raw  ___Conddsq_total;
run;
data ___Conddsq;
	set ___Conddsq;
	array a(*) $200 AVISIT;
	if index(upcase(AVISIT),"基线") and upcase(_Vname_) in ("CHG" "PCHG") then delete;
	** trt Group judgement *;
	%if %length(&CtGroup.)>0 %then %do;
		_trtGroup_=(&Group. not in (&CtGroup.) );
	%end;
	%else %do;
		_trtGroup_=1;
	%end;
run;

proc sql undo_policy=none;
	create table ___header as
	select distinct a.*,b.&Groupn.
	from ___header(drop=&Groupn.) as a
	left join ___unique_group_02 as b on a.&Group. = b.&Group.
	;
quit;
** all total *;
data ___header_total; if _n_=0; run;
data ___header_total;
	set ___header;
	&Groupn. = 99;
	&Group. = "合计";
run;
data ___header_allGroup;
set ___header  ___header_total;
run;
proc sql undo_policy=none;
	create table ___header_out as
	select distinct &Group.,&Groupn.,count(distinct _old&casevar._) as _grpsum_
	from ___header_allGroup
	Group By &Groupn.
	order By &Groupn.
	;
quit;

%let PmKeywordsonly=%sysfunc(tranwrd(%upcase(&PmKeywords.),%str(GEOMEAN),%str( )));
%let PmKeywordsonly=%sysfunc(tranwrd(%upcase(&PmKeywordsonly.),%str(GEOCV),%str( )));
%let PmKeywordsonly=%sysfunc(tranwrd(%upcase(&PmKeywordsonly.),%str(GEOSTD),%str( )));
%let PmKeywordsonly=%sysfunc(tranwrd(%upcase(&PmKeywordsonly.),%str(GEOLCLM),%str( )));
%let PmKeywordsonly=%sysfunc(tranwrd(%upcase(&PmKeywordsonly.),%str(GEOUCLM),%str( )));
** proc mean *;
proc sort data = ___Conddsq out=___Conddsq_allGroup ;By &Keepvars3.; run;
ods output Summary = ___procmean_Summary;
proc means data = ___Conddsq_allGroup &PmKeywordsonly. classdata=___HEADER_OUT;
	By &Keepvars3.;
	var _Vvalue_;
	class &Groupn. &Group.;
run;

%** Get the new groupn for the max group *;
proc sql noprint;
select distinct max(&groupn.) into :maxnumgroupn
from ___HEADER_OUT;
select distinct min(&groupn.) into :minnumgroupn
from ___HEADER_OUT;
quit;

%** Get the new groupn for the ctgroup *;
%if %length(&ctgroup.)>0 %then %do;
proc sql noprint;
select distinct &Groupn. into: ctgroupn
from ___header_out where &Group.=&ctgroup.
;
quit;
%end;
** Pvalue part *;
%if "&Outpvalue."="1" %then %do;
	data ___Conddsq_pvalue_01;
		set ___Conddsq_allgroup;
		where _Vmethod_>0 and ^missing(_Vvalue_);
	run;

	%if %nobs(___Conddsq_pvalue_01)>0 %then %do;
	%if "&PvalueType."="1" %then %do;
		data ___Pvalue_ctgroup ___Pvalue_nonctgroup;
		set ___Conddsq_pvalue_01;
		if &Group. = &CtGroup. then output ___Pvalue_ctgroup;
		else if &Group. ^= &CtGroup. then output ___Pvalue_nonctgroup;
		run;

		%if %nobs(___Pvalue_ctgroup)<=0 %then %do;
			%put ER%STR(ROR): (&SYSMACRONAME.) There is no valided record in the control Group, can not calculate P value!;
			%goto Endpvalue;
		%end;
		%if %nobs(___Pvalue_nonctgroup)<=0 %then %do;
			%put ER%STR(ROR): (&SYSMACRONAME.) There is no valided record in the treated Group, can not calculate P value!;
			%goto Endpvalue;
		%end;

		proc sql undo_policy=none;
			create table ___Pvalue_nonCTGrouplist as
			select distinct &Group.,&Groupn.
			from ___Pvalue_nonctgroup
			order by &Groupn.
			;
		quit;

		data _null_;
			set ___Pvalue_nonCTGrouplist end = last;
			call symputx("pvalueGroupn"||strip(put(_n_,best.)),&Groupn.,'l');
			if last then call symputx("npvalueGroup",strip(put(_n_,best.)),'l');
		run;

		data ___Conddsq_pvalue_02;
			set
				%do i=1 %to &npvalueGroup.;
					___Conddsq_pvalue_01(where=(&Group. in (&CtGroup.) or &Groupn. in (&&pvalueGroupn&i..)) in=a&i.)
				%end;
				;
				%do i=1 %to &npvalueGroup.;
					if a&i. then _pvalue_ID_=&&pvalueGroupn&i..;
				%end;
		run;
	%end;
	%else %if "&PvalueType."="2" %then %do;
		data ___Conddsq_pvalue_02;
			set ___Conddsq_pvalue_01;
			_pvalue_ID_=&maxnumgroupn.;
		run;
	%end;
%end;
%else %do;
	%goto Endpvalue;
%end;

** Start of Exact Wilcoxon Test Judgement;
data ___pvalue_m4_Judgement_01;
	set ___Conddsq_pvalue_01;
	where _Vmethod_ =4  and &Groupn. not in (98 99);
run;

%if %nobs(___pvalue_m4_Judgement_01)>0 %then %do;
	proc sort data = ___pvalue_m4_Judgement_01 ;By _varn_ _trtGroup_ &Groupn. &By.;run;
	proc means data = ___pvalue_m4_Judgement_01 noprint;
		By _varn_ _trtGroup_ &Groupn. &By.;
		var _Vvalue_;
		output out=___pvalue_m4_Judgement_02 n=_n ;
	run;
	proc sql undo_policy=none;
		create table ___pvalue_m4_Judgement_03 as
		select distinct *,max(_n) as _grpsum_
		from ___pvalue_m4_Judgement_02
		Group By _varn_ ,_trtGroup_ %if %length(&SqlBy)>0 %then %do;,&SqlBy. %end;
		;
	create table ___pvalue_m4_Judgement_04 as
		select distinct *,max(_grpsum_) as max,min(_grpsum_) as min
		from ___pvalue_m4_Judgement_03
		Group By _varn_ %if %length(&SqlBy)>0 %then %do;,&SqlBy. %end;
		order By _varn_ %if %length(&SqlBy)>0 %then %do;,&SqlBy. %end;
		;
	quit;

	data ___pvalue_m4_Judgement_05;
		set ___pvalue_m4_Judgement_04;
		** ------------------------------------------------------------- *;
		** If the number of subjects for the larger Group<10 *;
		** and the number of subjects for the smaller Group<8, *;
		** then use the exact wilcoxon rank sum test. *;
		** ------------------------------------------------------------- *;
		if 1<max<10 and 0<min<8 then wil_ex = 1;
		else wil_ex = 0;
		if min<=0 or max<=1 then notest = 1;
		else notest = 0;
	run;
** End of Exact Wilcoxon Test Judgement;

** Start of KS Normality Judgement;
	proc sort data = ___pvalue_m4_Judgement_01;By _varn_ &By. &Groupn.;run;
	Ods Output PredictedValues = ___pvalue_m4_PredictedValues;
	proc glm data= ___pvalue_m4_Judgement_01 ;
		where ^missing(_Vvalue_);
		By _varn_ &By.;
		class &Groupn.;
		model _Vvalue_ = &Groupn. /p;
	quit;

	proc sort data = ___pvalue_m4_PredictedValues;By _varn_ &By.;run;
		Ods Output TestsForNormality = ___pvalue_m4_Normality_KS;
		proc univariate data = ___pvalue_m4_PredictedValues normal ;
		By _varn_ &By.;
		var residual;
	run;

** Kolmogorov-Smirnov ;

	proc sql undo_policy=none;
		create table ___pvalue_m4_Judgement_06 as
		select distinct a.*,b.pvalue
		from ___pvalue_m4_Judgement_05 as a
		left join ___pvalue_m4_Normality_KS(where=(test='Kolmogorov-Smirnov')) as b
		on a._varn_ = b._varn_ %if %length(&SqlBy)>0 %then %do;  %do k = 1 %to &nBy.; and a.&&By&k.. = b.&&By&k.. %end; %end;
		;
	quit;

	data ___pvalue_m4_Judgement_07;
		set ___pvalue_m4_Judgement_06;
		** ------------------------------------------------------------- *;
		** If the number of subjects for the larger Group>=10 *;
		** or the number of subjects for the smaller Group>=8, then *;
		** calculate wilcoxon rank sum test t-approximation p-value, *;
		** t-test/anova p-value, and kolmogorov-smirnov test p-value. *;
		** if kolmogorov-smirnov test p-value is <=0.05 then *;
		** use wilcoxon rank sum test t-approximation p-value *;
		** if kolmogorov-smirnov test p-value is >0.05 *;
		** then use t-test/anova p-value *;
		** ------------------------------------------------------------- *;
		if notest = 0 and wil_ex = 0 and pvalue > 0.05 then do;
		anova = 1; wil_t = 0;
		end;
		else if notest = 0 and wil_ex = 0 and pvalue <= 0.05 then do;
		anova = 0; wil_t = 1;
		end;
		else do; anova = 0; wil_t = 0; end;
	run;
	proc sort data = ___pvalue_m4_Judgement_07 nodupkey;
		By _varn_ &By.;
	run;** End of Normality Judgement;
	** Join the flags of Tests to Condtional DataSet;
	proc sql undo_policy=none;
		create table ___Conddsq_pvalue_02 as
		select a.*,b.notest,b.wil_ex,b.wil_t,b.anova
		from ___Conddsq_pvalue_02 as a
		left join ___pvalue_m4_Judgement_07 as b
		on a._varn_ = b._varn_ %if %length(&SqlBy)>0 %then %do;  %do k = 1 %to &nBy.; and a.&&By&k.. = b.&&By&k.. %end; %end;
		;
	quit;
%end;

** Start of SW Normality Judgement;
** ------------------------------------------------------------- *;
** if Shapiro-Wilk test p-value is >=0.05 *;
** then use t-test, else use wilconxon *;
** ------------------------------------------------------------- *;
%if "&PvalueType."="1" %then %do;
	data ___pvalue_m5_Judgement_SW_01;
		set ___Conddsq_pvalue_01;
		where _Vmethod_=5;
	run;

	%** Modify By Yunhui.Cui For Multi Group Pair P-Value Normal Check;
	%if %nobs(___pvalue_m5_Judgement_SW_01)>0 %then %do;
		 proc sort data=___pvalue_m5_Judgement_SW_01;By _varn_ &By. &Groupn. &Group.;run;
		    Ods Output TestsForNormality = ___pvalue_m5_Judgement_SW_02;
	    proc univariate data = ___pvalue_m5_Judgement_SW_01 normal ; 
	        By _varn_ &By. &Groupn. &Group.;
	        var _Vvalue_;
	     run;
		proc sql undo_policy=none;
			create table ___pvalue_m5_Judgement_SW_03 as
			select distinct a.*, b.pValue as pValue_CT
			from ___pvalue_m5_Judgement_SW_02( where=(test='Shapiro-Wilk' and &Group. not in (&CTgroup.))) as a
			left join ___pvalue_m5_Judgement_SW_02( where=(test='Shapiro-Wilk' and &Group. in (&CTgroup.))) as b
			on a._varn_ = b._varn_ %if %length(&by)>0 %then %do;%do k = 1 %to &nBy.; and a.&&By&k.. = b.&&By&k.. %end;%end;
			;
		quit;

		data ___pvalue_m5_Judgement_SW_03;
			set ___pvalue_m5_Judgement_SW_03;
			if pValue <0.05 or pValue_CT < 0.05 then wil=1;
		run;

		proc sql undo_policy=none;
			create table ___Conddsq_pvalue_02 as
			select a.*,b.wil
			from ___Conddsq_pvalue_02 as a
			left join ___pvalue_m5_Judgement_SW_03(where = (wil=1)) as b
			on a._varn_ = b._varn_ %if %length(&by)>0 %then %do;%do k = 1 %to &nBy.; and a.&&By&k.. = b.&&By&k.. %end;%end;
and a._pvalue_ID_ = b.&group.n
			;
		quit;
	%end;
%end;

%** -------------------------------------------------------------------------------------- *;
%** Analytical method classification per &By. var *;
%** method=0: null *;
%** method=1: t-test *;
%** method=2: ANOVA *;
%** method=3: Wilcoxon *;
%** method=4: Automatic select test method *;
%** method=5: If Shapiro-Wilk test p-value is >=0.05 then use t-test, else use wilconxon *;
%** *;
%** PvalueType: Only for ANOVA & Wilcoxon, only use for Outtotalpvalue=0 *;
%** 1=Pairwise comparison *;
%** 2=Do not consider group *;
%** *;
%** Outtotalpvalue: Whether to calculate the p value of the total group *;
%** 0=Not include 98 & 99 *;
%** 1=Include 98 & 99 *;
%** 2=Only include 98 *;
%** 3=Only include 99 *;
** -------------------------------------------------------------------------------------- *;
data ___Conddsq_pvalue_03 ___pvalue_ttest_01 ___pvalue_wil_t_01 ___pvalue_wil_normal_01 ___pvalue_wil_ex_01 ___pvalue_anova_01;
	set ___Conddsq_pvalue_02;
	array a (*) notest ttest anova wil wil_t wil_normal wil_ex kmtest;
	if _Vmethod_=4 then do;
		call missing(wil_normal,ttest,kmtest,wil);
	end;
	else if _Vmethod_ = 5 then do;
		call missing(anova,wil_t,wil_normal,wil_ex,kmtest);
		if wil=1 then do;
			if _wilcoxonp_=1 then wil_normal=1;
			else if _wilcoxonp_=2 then wil_t=1;
			else if _wilcoxonp_=3 or _wilcoxonp_=4 then wil_ex=1;
/*			else wil_t=1;*/
			else wil_normal=1;
		end;
		else do;
			ttest=1;
		end;
	end;
	else do;
		call missing(ttest,wil,wil_t,wil_normal,wil_ex,anova,kmtest);
		if _Vmethod_ = 1 then do;
			ttest=1;
		end;
		else if _Vmethod_ = 2 then do;
			anova=1;
		end;
		else if _Vmethod_ = 3 then do;
			if _wilcoxonp_=1 then wil_normal=1;
			else if _wilcoxonp_=2 then wil_t=1;
			else if _wilcoxonp_=3 or _wilcoxonp_=4 then wil_ex=1;
/*			else wil_t=1;*/
			else wil_normal=1;
		end;
	end;
	kmtest=1;
	%if "&PvalueType."="1" %then %do;
		%if "&Outtotalpvalue."="0" %then %do;
			if _pvalue_ID_ in (98 99) then delete;
		%end;
		%else %if "&Outtotalpvalue."="1" %then %do;
		%end;
		%else %if "&Outtotalpvalue."="2" %then %do;
			if _pvalue_ID_ in (99) then delete;
		%end;
		%else %if "&Outtotalpvalue."="3" %then %do;
			if _pvalue_ID_ in (98) then delete;
		%end;
	%end;
	%else %if "&PvalueType."="2" %then %do;
		if &groupn. in (98 99) then delete;
	%end;
	output ___Conddsq_pvalue_03;
	if ttest=1 then output ___pvalue_ttest_01;
	else if wil_t=1 then output ___pvalue_wil_t_01;
	else if wil_normal=1 then output ___pvalue_wil_normal_01;
	else if wil_ex=1 then output ___pvalue_wil_ex_01;
	else if anova=1 and &Groupn. not in (98 99) then output ___pvalue_anova_01;
run;

** Start of t tests;
%if %nobs(___pvalue_ttest_01)>0 %then %do;
	proc sort data = ___pvalue_ttest_01 ;by _pvalue_ID_ _varn_ &By. _Vmethod_;run;
	ods output ttests=___pvalue_ttest_02;
	ods output Equality=___pvalue_ttest_Equality;
	proc ttest data=___pvalue_ttest_01 nobyvar;
	var _Vvalue_;
	class &Groupn.;
	by _pvalue_ID_ _varn_ &By. _Vmethod_;
	run;
	quit;

	data ___pvalue_ttest_03;
	merge ___pvalue_ttest_02 ___pvalue_ttest_Equality(keep = ProbF _varn_ &By. _pvalue_ID_);
	by _pvalue_ID_ _varn_ &By.;
	run;

	data ___pvalue_ttest;
	set ___pvalue_ttest_03;
	length P S $200.;
	where (ProbF>0.05 and upcase(Variances) in ("EQUAL" "等于") ) or (.<ProbF<=0.05 and upcase(Variances) in ("UNEQUAL" "不等于"));
			if Probt>0.999 then P = ">0.999";
			else if .<Probt<.001 then P = "<0.001";
			else if ^missing(Probt) then P = strip(put(Probt,12.3));
			 if ^missing(tValue) then S = strip(put(tValue,32.3));
	&Groupn. = _pvalue_ID_;
	_CtGroupn_ = &CtGroupn.;
			_Vvaluelabeln_=&P_Vvaluelabeln.;
			_method="t检验";
	keep _varn_ &By. &Groupn. p S _Vmethod_ _pvalue_ID_ _CtGroupn_ _Vvaluelabeln_ _method;
	run;
%end;
** End of t tests;

** Start of Wilcoxon;
%**ISIS Comment: Force the raw result, chg and pchg to 5 decimal when use non-parametric tests;
%if %nobs(___pvalue_wil_ex_01)>0 %then %do;
	data ___pvalue_wil_ex_01;
	set ___pvalue_wil_ex_01;
	if ^missing(_Vvalue_) then _npar1way=input(compress(put(_Vvalue_,32.5)),best.);
	_Wiltype_="wil_ex";
	run;

	proc sort data = ___pvalue_wil_ex_01;by _pvalue_ID_ _varn_ &By. _Vmethod_ _Wiltype_;run;
	proc npar1way Data = ___pvalue_wil_ex_01 Wilcoxon;
	output out = ___pvalue_wil_ex_02;
	By _pvalue_ID_ _varn_ &By. _Vmethod_ _Wiltype_;
	class &Groupn.;
	var _npar1way;
	exact Wilcoxon;
	run;
	quit;
%end;

%if %nobs(___pvalue_wil_t_01)>0 or %nobs(___pvalue_wil_normal_01)>0 %then %do;
	data ___pvalue_wil_nex_01;
	set ___pvalue_wil_normal_01(in=a1) ___pvalue_wil_t_01(in=a2);
/*	if ^missing(_Vvalue_) then _npar1way=input(compress(put(_Vvalue_,32.5)),best.);*/
	if ^missing(_Vvalue_) then _npar1way=_Vvalue_;
	if a1 then _Wiltype_="wil_normal";
	else if a2 then _Wiltype_="wil_t";
	run;

	proc sort data = ___pvalue_wil_nex_01;by _pvalue_ID_ _varn_ &By. _Vmethod_ _Wiltype_;run;
	proc npar1way Data = ___pvalue_wil_nex_01 Wilcoxon;
	output out = ___pvalue_wil_nex_02;
	By _pvalue_ID_ _varn_ &By. _Vmethod_ _Wiltype_;
	class &Groupn.;
	var _npar1way;
	run;
	quit;
%end;

%if %sysfunc(exist(___pvalue_wil_ex_02)) or %sysfunc(exist(___pvalue_wil_nex_02)) %then %do;
	data ___pvalue_wil;
		length _Wiltype_ $20. P S P_ S_ $200.;
		array a(*) P2_WIL PT2_WIL XP2_WIL P2_KW XP2_KW P_KW _KW_ Z_WIL;
		set %if %sysfunc(exist(___pvalue_wil_ex_02)) %then ___pvalue_wil_ex_02; %if %sysfunc(exist(___pvalue_wil_nex_02)) %then ___pvalue_wil_nex_02; ;

		%if "&PvalueType."="1" %then %do;
/*			if _Wiltype_="wil_normal" and ^missing(P2_WIL) then P = "[WilN]_"||strip(put(P2_WIL,12.3))||"&escapechar.{super [N]}";*/
/*			else if _Wiltype_="wil_t" and ^missing(PT2_WIL) then P = "[WilT]_"||strip(put(PT2_WIL,12.3))||"&escapechar.{super [T]}";*/
/*			else if _Wiltype_="wil_ex" and ^missing(XP2_WIL) then P = "[WilE]_"||strip(put(XP2_WIL,12.3))||"&escapechar.{super [E]}";*/
/*			if _Wiltype_="wil_normal" and ^missing(z_WIL) then S = "[WilN]_"||strip(put(Z_WIL, 32.3))||"&escapechar.{super [N]}";*/
/*			else if _Wiltype_="wil_t" and ^missing(Z_WIL) then S = "[WilT]_"||strip(put(Z_WIL, 32.3))||"&escapechar.{super [T]}";*/
/*			else if _Wiltype_="wil_ex" and ^missing(Z_WIL) then S = "[WilE]_"||strip(put(Z_WIL, 32.3))||"&escapechar.{super [E]}";*/
			if _Wiltype_="wil_normal" and ^missing(P2_WIL) then do;P_ = strip(put(P2_WIL,32.3));P_n=P2_WIL;end;
			else if _Wiltype_="wil_t" and ^missing(PT2_WIL) then do;P_ = strip(put(PT2_WIL,32.3));P_n=PT2_WIL;end;
			else if _Wiltype_="wil_ex" and ^missing(XP2_WIL) then do;P_ = strip(put(XP2_WIL,32.3));P_n=XP2_WIL;end;
			if _Wiltype_="wil_normal" and ^missing(z_WIL) then S_ = strip(put(Z_WIL, 32.3));
			else if _Wiltype_="wil_t" and ^missing(Z_WIL) then S_ = strip(put(Z_WIL, 32.3));
			else if _Wiltype_="wil_ex" and ^missing(Z_WIL) then S_ = strip(put(Z_WIL, 32.3));

			S_n=input(S_,best.);
			if P_n>0.999 then P = ">0.999";
			else if .<P_n<.001 then P = "<0.001";
			else if ^missing(P_n) then P = strip(P_);
			else p ='-';
			if ^missing(input(S_,best.)) then S = strip(S_);
			else S ='-';

		%end;
		%else %if "&PvalueType."="2" %then %do;
			P2_KW=coalesce(P2_KW,P_KW);
			PT2_WIL=coalesce(PT2_WIL,P_KW);
			XP2_KW=coalesce(XP2_KW,P_KW);
			Z_WIL=coalesce(Z_WIL,_KW_);
			if _Wiltype_="wil_normal" and ^missing(P2_KW) then P = "[WilN]_"||strip(put(P2_KW,12.3))||"&escapechar.{super [N]}";
			else if _Wiltype_="wil_t" and ^missing(PT2_WIL) then P = "[WilT]_"||strip(put(PT2_WIL,12.3))||"&escapechar.{super [T]}";
			else if _Wiltype_="wil_ex" and ^missing(XP2_KW) then P = "[WilE]_"||strip(put(XP2_KW,12.3))||"&escapechar.{super [E]}";
			if _Wiltype_="wil_normal" and ^missing(Z_WIL) then S = "[WilN]_"||strip(put(Z_WIL, 32.3))||"&escapechar.{super [N]}";
			else if _Wiltype_="wil_t" and ^missing(Z_WIL) then S = "[WilT]_"||strip(put(Z_WIL, 32.3))||"&escapechar.{super [T]}";
			else if _Wiltype_="wil_ex" and ^missing(Z_WIL) then S = "[WilE]_"||strip(put(Z_WIL, 32.3))||"&escapechar.{super [E]}";
		%end;
		&Groupn. = _pvalue_ID_;
			_Vvaluelabeln_=&P_Vvaluelabeln.;
			_method="秩和检验";
		keep _varn_ &By. &Groupn. p S _Vmethod_ _pvalue_ID_ _Vvaluelabeln_ _method P_ S_ P_n S_n;
	run;
%end;
** End of Wilcoxon;

	** Start of Anova Test;
	%if %nobs(___pvalue_anova_01)>0 %then %do;
		%if "&PvalueType."="1" %then %do;
			data _null_;
				set ___pvalue_nonctgrouplist end = last;
				where &groupn. not in (98 99);
				call symputx("anovagrp"||strip(put(_n_,best.)),&Groupn.,'l');
				if last then call symputx("nanovaGRP",strip(put(_n_,best.)),'l');
			run;

			%let Contrast=-1 %sysfunc(repeat(0,%eval(&nanovaGRP.-1)));
			%do i=1 %to &nanovaGRP.;
				%local Contrast&i.;
				%if %eval(&i.+3)<%length(&Contrast.) %then %let Contrast&i.=%substr(&Contrast.,1,%eval(&i.+2))1%substr(&Contrast.,%eval(&i.+4));
				%else %let Contrast&i.=%substr(&Contrast.,1,%eval(&i.+2))1;
				%let Contrast&i.=%sysfunc(tranwrd(&&Contrast&i..,%str(01),%str(0 1)));
				%let Contrast&i.=%sysfunc(tranwrd(&&Contrast&i..,%str(00),%str(0 0)));
				%let Contrast&i.=%sysfunc(tranwrd(&&Contrast&i..,%str(00),%str(0 0)));
				%let Contrast&i.=%sysfunc(tranwrd(&&Contrast&i..,%str(11),%str(1 1)));
				%let Contrast&i.=%sysfunc(tranwrd(&&Contrast&i..,%str(10),%str(1 0)));
			%end;

		*** The sort variable value of the control group must be the smallest *;
		data ___pvalue_anova_02;
			set ___pvalue_anova_01;
			if &Group. = &CtGroup. then &Groupn.=%eval(&minnumgroupn.-1);
		run;

		*** Should be distinct *;
		proc sql undo_policy=none;
			create table ___pvalue_anova_03 as
			select distinct *
			from ___pvalue_anova_02(drop=_pvalue_ID_)
			order by _varn_, _Vmethod_%if %length(&SQLBy.)>0 %then %do;,&SQLBy.%end;
			;
			/***Check Contrast & Group list */
			create table __check_anova_Contrast as
			select distinct _varn_, _Vmethod_, %if %length(&SQLBy.)>0 %then %do;&SQLBy.,%end; count(distinct &groupn.) as ngroup
			from ___pvalue_anova_03
			group by _varn_, _Vmethod_%if %length(&SQLBy.)>0 %then %do;,&SQLBy.%end;
			having ngroup ^= %eval(&nanovaGRP.+1)
			;
		quit;

			%if %nobs(__check_anova_Contrast)>0 %then %do;
				%put ERR%str(OR:) (&SYSMACRONAME.) Group list and anova contrast not eq, please check dataset __check_anova_Contrast!;
			%end;
			%else %do;
				proc datasets nolist nodetails NoWarn lib=work;
				delete __check_anova_Contrast/memtype=data;
				quit;
			%end;
			Proc Sort data = ___pvalue_anova_03;
				By _varn_ _Vmethod_ &By.;
			run;
			ods output Contrasts = ___pvalue_anova_04;
			ods output overallanova= ___pvalue_anova_04_98;
			proc glm data = ___pvalue_anova_03;
			By _varn_ _Vmethod_ &By.;
			class &Groupn.;
			model _Vvalue_ = &Groupn.;
			%do i=1 %to &nanovaGRP.;
				Contrast "&&anovagrp&i.." &Groupn. %unquote(&&Contrast&i..);
			%end;
			quit;

			data ___pvalue_anova;
				length source P S $200.;
				set ___pvalue_anova_04(in=a1) ___pvalue_anova_04_98(in=a2 where=(Source="Model"));
				if ^missing(ProbF) then P = "[ANOVA]_"||strip(put(ProbF,12.3))||"&escapechar.{super [A]}";
				if ^missing(FValue) then S = "[ANOVA]_"||strip(put(FValue,32.3))||"&escapechar.{super [A]}";
				if a1 then &Groupn.=input(source,best.);
				else if a2 then &Groupn.=98;
				keep _varn_ &By. &Groupn. P S _Vmethod_;
			run;
		%end;
		%else %if "&PvalueType."="2" %then %do;
			proc sort data = ___pvalue_anova_01;by _varn_ _Vmethod_ &By.;run;
			ods output overallanova= ___pvalue_anova_overall;
			proc glm data = ___pvalue_anova_01;
				By _varn_ _Vmethod_ &By.;
				class &Groupn.;
				model _Vvalue_ = &Groupn.;
			quit;

			data ___pvalue_anova;
			set ___pvalue_anova_overall;
			length P S $200.;
			where Source="模型";
/*			where Source="Model";*/
			if ProbF>0.999 then P = ">0.999";
			else if .<ProbF<.001 then P = "<0.001";
			else if ^missing(ProbF) then P = strip(put(ProbF,12.3));
			 if ^missing(FValue) then S = strip(put(FValue,32.3));
			&Groupn. = &maxnumgroupn.
			;_Vvaluelabeln_=&P_Vvaluelabeln.;
			_method="方差分析";
			keep _varn_ &By. &Groupn. P S _Vmethod_ _method _Vvaluelabeln_;
			run;
		%end;
	%end;
	** End of Anova Test;

	** Merge all pvalue method **;
	%if %sysfunc(exist(___pvalue_ttest)) or %sysfunc(exist(___pvalue_wil)) or %sysfunc(exist(___pvalue_anova)) %then %do;
		data ___pvalue;
		array a(*) $200 P S _method;
		set
		%if %sysfunc(exist(___pvalue_ttest)) %then ___pvalue_ttest;
		%if %sysfunc(exist(___pvalue_wil)) %then ___pvalue_wil;
		%if %sysfunc(exist(___pvalue_anova)) %then ___pvalue_anova;
		;
		run;
	%end;
%end; ** End p value;

%Endpvalue:

** ------------------------------------------------------------- *;
** Output Pvalue match *;
** 1=Paired T Test P-value *;
** 2=Wilcoxon Signed Rank Test P-value *;
** 4=if Shapiro-Wilk test p-value is >=0.05 *;
** then use Students t, else use Signed Rank *;
** ------------------------------------------------------------- *;
%if "&Outpvaluematch."="1" %then %do;
	data ___Pvalue_match_01;
		set ___Conddsq_allGroup;
		where ^missing(_match_) and ^missing(_Vvalue_)
/*		%if "&Outtotalpvalue."="0" %then and &Groupn. not in (98 99);*/
/*		%else %if "&Outtotalpvalue."="2" %then and &Groupn. not in (99);*/
/*		%else %if "&Outtotalpvalue."="3" %then and &Groupn. not in (98);*/
		;
		if _match_=1 then do;
		end;
		else do;
			%**ISIS: please force the raw result, change and percent change to 5 decimal;
			_match_=input(compress(put(_match_,32.5)),best.);
		end;
	run;

	%if %nobs(___Pvalue_match_01)<1 %then %do;
		%put ER%STR(ROR): (&SYSMACRONAME.) There is no record, can not calculate P value match!;
		%goto Endpvaluematch;
	%end;

	proc sort data=___Pvalue_match_01;By &By. &Groupn. _Varn_ _match_;run;
	ods output TestsForLocation=___Pvalue_match_02;
	proc univariate data=___Pvalue_match_01;
	By &By. &Groupn. _Varn_ _match_;
	var _Vvalue_;
	run;

	Ods Output TestsForNormality = ___Pvalue_match_normal_01;
	proc univariate data = ___Pvalue_match_01 normal ;
	By &By. &Groupn. _Varn_ _match_;
	var _Vvalue_;
	run;

	data ___Pvalue_match_03;
		merge ___Pvalue_match_02(drop=test) ___Pvalue_match_normal_01(where=(test='Shapiro-Wilk') rename=(pvalue=SWpvalue) keep=_varn_ &By. _match_ &Groupn. pvalue test);
		By &By. &Groupn. _Varn_ _match_;
	run;

	data ___Pvalue_match;
		set ___Pvalue_match_03;
		length Pmatch Smatch $200.;
		where (_match_=1 and upcase(Testlab)="T") or (_match_=2 and upcase(Testlab)="S") or
		(_match_=4 and ((SWpvalue<0.05 and upcase(Testlab)="S") or (SWpvalue>=0.05 and upcase(Testlab)="T")));
		if pValue>0.999 then Pmatch="["||strip(upcase(Testlab))||"]_"||strip(">0.999")||"&escapechar.{super ["||strip(upcase(Testlab))||"]}";
		else if .<pValue<.001 then Pmatch="["||strip(upcase(Testlab))||"]_"||strip("<0.001")||"&escapechar.{super ["||strip(upcase(Testlab))||"]}";
		else if ^missing(pValue) then Pmatch="["||strip(upcase(Testlab))||"]_"||strip(put(pValue,12.3))||"&escapechar.{super ["||strip(upcase(Testlab))||"]}";
		if ^missing(stat) then Smatch="["||strip(upcase(Testlab))||"]_"||strip(put(stat,32.3))||"&escapechar.{super ["||strip(upcase(Testlab))||"]}";
	run;


/*	proc sort data=___Pvalue_match_01;By &By. &Groupn. _Varn_ _match_;run;*/
/*	ods output TTests=___Pvalue_match_02_p_t(where=(_match_=1));*/
/*proc ttest data=___Pvalue_match_01 ;*/
/*	By &By. &Groupn. _Varn_ _match_;*/
/*	paired AVAL*BASE;*/
/*run;*/

	proc sort data=___pvalue_match out=___pvalue_match_1 ;
		By &By.  _Varn_ ;
	quit;
	proc transpose data=___pvalue_match_1 out=___pvalue_match_2   prefix=col;
		By &By.  _Varn_ ;
		var Pmatch;
		id &groupn;
	quit;
	data ___pvalue_match_3;
		set ___pvalue_match_2;
		_Vvaluelabeln_=9;
		%do trt_n=1 %to &all_trtn ; _ngc&trt_n.=strip(scan(scan(col&trt_n.,2,'_'),1,'~')); drop col&trt_n.;%end;
		 _ngc99=strip(scan(scan(col99,2,'_'),1,'~')); drop col99;
		drop _name_;
		_text2='  Paired t-test P';
run;
%end;
%Endpvaluematch:

	%if %index(%upcase(&PmKeywords.), GEOMEAN) or %index(%upcase(&PmKeywords.), GEOCV) or %index(%upcase(&PmKeywords.), GEOSTD) or %index(%upcase(&PmKeywords.), GEOLCLM)
	or %index(%upcase(&PmKeywords.), GEOUCLM) %then %do;
	** create geo mean & cv *;
	proc sort data = ___Conddsq_allGroup ; By &Keepvars2.; run;
	ods output Summary = ___procmean_Summary_G;
	proc means data = ___Conddsq_allgroup mean std lclm uclm nway;
		By &Keepvars2.;
		var _Vlogvalue_;
	run;

	data ___procmean_Summary_G;
		set ___procmean_Summary_G;
		if ^missing(_Vlogvalue__Mean) then _Vvalue__Geomean=exp(_Vlogvalue__Mean);
		if ^missing(_Vlogvalue__Lclm) then _Vvalue__Geolclm=exp(_Vlogvalue__Lclm);
		if ^missing(_Vlogvalue__Uclm) then _Vvalue__Geouclm=exp(_Vlogvalue__Uclm);
		if ^missing(_Vlogvalue__StdDev) then do;
			_Vvalue__Geocv=(exp(_Vlogvalue__StdDev**2)-1)**(1/2)*100;
			_Vvalue__Geostd=exp(_Vlogvalue__StdDev);
		end;
		keep &Keepvars2. _Vvalue__Geomean _Vvalue__Geocv _Vvalue__Geostd _Vvalue__Geolclm _Vvalue__Geouclm;
	run;

	proc sort data= ___procmean_Summary_G; By &Keepvars2.; run;
	proc sort data= ___procmean_Summary; By &Keepvars2.; run;
	data ___procmean_Summary;
		merge ___procmean_Summary ___procmean_Summary_G;
		By &Keepvars2.;
	run;
	%end;

data _null_;
	set ___header_out end = last;
	retain headermaxwth 0;
	headerwth=klength(strip(scan(&Group.,1,"$")))+0.25*(lengthn(strip(scan(&Group.,1,"$")))-klength(strip(scan(&Group.,1,"$"))));
	if headermaxwth<=Headerwth then headermaxwth=Headerwth;
	call symputx("headername"||strip(put(_n_,best.)),"_ngc"||strip(put(&Groupn.,best.)),"L");
	call symputx("headerorgname"||strip(put(_n_,best.)),strip(put(&Groupn.,best.)),"L");
	call symputx("headerlabel"||strip(put(_n_,best.)),strip(&Group.),"L");
	call symputx("headersum"||strip(put(_n_,best.)),_grpsum_,"L");
	call symputx("mergeheader"||strip(put(_n_,best.)),mergeheader,"L");
	call symputx("function"||strip(put(_n_,best.)),function,"L");
	%if %sysfunc(exist(___header_period_nsubj)) %then %do;
		call symputx('newgroup'||strip(put(_n_,best.)),strip(&Group.),'l');
		call symputx('drug'||strip(put(_n_,best.)),strip(_old&Group._),'l');
		call symputx('nsubjdrug'||strip(put(_n_,best.)),_grpsum_,'l');
		call symputx('periodc'||strip(put(_n_,best.)),strip(&Period.),'l');
		call symputx('nsubjperiod'||strip(put(_n_,best.)),_grpperidsum_,'l');
	%end;

	if last then do;
	call symputx("nheader",_n_,"L");
	call symputx("Headerwth",headermaxwth,"L");
	end;
run;

data ___procmean;
%** First define the length to avoid truncation **;
	length
	%do i=1 %to &nPmLtopkeyword.;
		%do j=1 %to &&npmLtopkeyword&i..;
			_vvalue__&&&pmLtop&i.keyword&j..c
		%end;
	%end;
$50.;

	set ___procmean_Summary;
	%do i=1 %to &nPmLtopkeyword.;%** Start Ltop keyword *;
		%do j=1 %to &&npmLtopkeyword&i..;%** Start proc mean keywords cycle per Ltop *;
			_Vdigit_&&&pmLtop&i.keyword&j.._="32."||strip(put(sum(_Vdigit_,&&&pmLtop&i.prec&j..),best.));
			%if %length(&max_dlen)>0 %then %do;
				max_dlen=sum(_Vdigit_,&&&pmLtop&i.prec&j..);
				if max_dlen>&max_dlen then _Vdigit_&&&pmLtop&i.keyword&j.._="32.&max_dlen";
			%end;
	

			if index(upcase(_Vname_),"PCHG") or index(upcase(_Vlabel_),"PERCENT CHANGE") then _Vdigit_&&&pmLtop&i.keyword&j.._="32."||strip(put(_Vdigit_,best.));

			%if "%upcase(&&&pmLtop&i.keyword&j..)"="N" or "%upcase(&&&pmLtop&i.keyword&j..)"="NMISS" %then %do;
				_vvalue__&&&pmLtop&i.keyword&j..=coalesce(_vvalue__&&pmLtop&i.keyword&j.,0);
			%end;

			%** Recreate NMISS, NMISS=N(header) -N *;
			%if "&Nmisstype."="1" %then %do;
				%if "%upcase(&&&pmLtop&i.keyword&j..)"="NMISS" %then %do;
					%do loop1 = 1 %to &nheader.;
						%if %sysfunc(exist(___header_period_nsubj)) %then %do;
							if "_ngc"||strip(put(&groupn.,best.))="&&headername&loop1.." then _vvalue__&&pmLtop&i.keyword&j.=&&nsubjperiod&loop1..-_vvalue__N;
						%end;
						%else %do;
							if "_ngc"||strip(put(&groupn.,best.))="&&headername&loop1.." then _vvalue__&&pmLtop&i.keyword&j.=&&headersum&loop1..-_vvalue__N;
						%end;
					%end;
				%end;
			%end;

			%if "%upcase(&&&pmLtop&i.keyword&j..)"="N" or "%upcase(&&&pmLtop&i.keyword&j..)"="NMISS" %then %do;
				_vvalue__&&&pmLtop&i.keyword&j..c=coalescec(strip(put(_vvalue__&&pmLtop&i.keyword&j.,??best32.)),'0');
			%end;

			%else %do;
			%** keep the valid decimal number *;
				%if %sysfunc(prxmatch(/^\d+$/, &Round_3_scdigit)) or %sysfunc(prxmatch(/\b&&pmLtop&i.keyword&j.\b/, &Round_3_scdigit)) %then %do;
					if ^missing(_vvalue__&&pmLtop&i.keyword&j.) then do;
					if round(_vvalue__&&pmLtop&i.keyword&j.,0.0000000001)=0 then do;
					_vvalue__&&pmLtop&i.keyword&j.=0;
					end;
					end;
					%if "%upcase(&_MacroDigitName.)"="M_SIGNIFICANT_DIGIT" %then %do;
						%if %sysfunc(prxmatch(/^\d+$/, &Round_3_scdigit)) %then %do;
							%m_significant_digit(_vvalue__&&pmLtop&i.keyword&j., _vvalue__&&&pmLtop&i.keyword&j..c, &Round_3_scdigit. %if "&Enotation."="1" %then , &Enotation.;);
						%end;
						%else %do;
							%m_significant_digit(_vvalue__&&pmLtop&i.keyword&j., _vvalue__&&&pmLtop&i.keyword&j..c, &&&pmLtop&i.prec&j.. %if "&Enotation."="1" %then , &Enotation.;);
						%end;
					%end;
					%else %if "%upcase(&_MacroDigitName.)"="SIGNIF3QC" %then %do;
						%Signif3qc(_vvalue__&&pmLtop&i.keyword&j., _vvalue__&&&pmLtop&i.keyword&j..c, missing="");
					%end;
					%if "%upcase(&&&pmLtop&i.keyword&j..)"="CV" %then %do;
						if _vvalue__mean=0 then do;
						_vvalue__cvc="NA";
						end;
					%end;
				%end;
				%else %do;
					_vvalue__&&pmLtop&i.keyword&j.c=strip(putn(_vvalue__&&pmLtop&i.keyword&j.,_Vdigit_&&&pmLtop&i.keyword&j.._));
				%end;

				%** For PK concentrations analysis *;
				%** If statistics(mean, min, max, median, p25, p75) ls than LLOQ then wil be set BQL(cn) or BLQ(en) *;
				%** If mean ls than LLOQ then statistics(geomean, geolclm, geouclm, geocv, geostd, stddev, stderr, cv) wil be set NA *;
				%** If statistics can not be calculated, will be set 'NA' *;
				%if %length(&LLOQ.)>0 %then %do;
				%** If statistics(mean, min, max, median, p25, p75) ls than LLOQ then wil be set BQL or BLQ *;
					%if "%upcase(&&&pmLtop&i.keyword&j..)"="MEAN"
					or "%upcase(&&&pmLtop&i.keyword&j..)"="MIN"
					or "%upcase(&&&pmLtop&i.keyword&j..)"="MAX"
					or "%upcase(&&&pmLtop&i.keyword&j..)"="MEDIAN"
					or "%upcase(&&&pmLtop&i.keyword&j..)"="P25"
					or "%upcase(&&&pmLtop&i.keyword&j..)"="P50"
					or "%upcase(&&&pmLtop&i.keyword&j..)"="P75" %then %do;
						if .<_vvalue__&&pmLtop&i.keyword&j.<&LLOQ. then _vvalue__&&pmLtop&i.keyword&j.c="&_BQL.";
					%end;

					%** If mean ls than LLOQ then statistics(geomean, geolclm, geouclm, geocv, geostd, stddev, stderr, cv) wil be set NA *;
					%if %m_var_exist(___procmean_Summary, _vvalue__mean) %then %do;
						%if "%upcase(&&&pmLtop&i.keyword&j..)"="GEOMEAN"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="GEOLCLM"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="GEOUCLM"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="GEOCV"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="GEOSTD"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="STDDEV"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="STDERR"
						or "%upcase(&&&pmLtop&i.keyword&j..)"="CV" %then %do;
							if _vvalue__mean<&LLOQ. then _vvalue__&&pmLtop&i.keyword&j.c="NA";
						%end;
					%end;

					%** If statistics can not be calculated, will be set 'NA' *;
					_vvalue__&&pmLtop&i.keyword&j.c=coalescec(_vvalue__&&pmLtop&i.keyword&j.c,"NA");
				%end;

				%** Display 'NA' for chinese format *;
					_vvalue__&&pmLtop&i.keyword&j.c=coalescec(_vvalue__&&pmLtop&i.keyword&j.c,"&Sdsemna.");
			%end;
		%end;%** End proc mean keywords cycle per Ltop *;

		%** put display result **;
		&&pmLtopVarname&i.. = &&keywordPattern&i..;
	%end;;%** End Ltop keyword *;
run;
** Merge all the statistic *;
	proc sort data = ___procmean ; by &By. &Groupn. _Varn_; run;
	%if %sysfunc(exist(___ci)) %then %do;
	proc sort data = ___ci ; by &By. &Groupn. _Varn_; run;
	%end;
	%if %sysfunc(exist(___pvalue)) %then %do;
	proc sort data = ___pvalue ; by &By. &Groupn. _Varn_; run;
	%end;
	%if %sysfunc(exist(___Pvalue_kmtest)) %then %do;
	proc sort data = ___Pvalue_kmtest ; by &By. &Groupn. _Varn_; run;
	%end;
	%if %sysfunc(exist(___Pvalue_match)) %then %do;
	proc sort data = ___Pvalue_match ; by &By. &Groupn. _Varn_; run;
	%end;
/*data ___report_out_1;*/
/*	array a(*) $200 CI P S kmpvalue kmsvalue pmatch smatch;*/
/*	array b(*) $2000 _footnote_;*/
/*	merge ___procmean*/
/*	%if %sysfunc(exist(___ci)) %then %do;*/
/*	___ci*/
/*	%end;*/
/*	%if %sysfunc(exist(___pvalue)) %then %do;*/
/*	___pvalue(keep =&By. &Groupn. _Varn_ P S)*/
/*	%end;*/
/*	%if %sysfunc(exist(___Pvalue_kmtest)) %then %do;*/
/*	___Pvalue_kmtest(keep =&By. &Groupn. _Varn_ kmpvalue kmsvalue)*/
/*	%end;*/
/*	%if %sysfunc(exist(___Pvalue_match)) %then %do;*/
/*	___Pvalue_match(keep =&By. &Groupn. _Varn_ Pmatch Smatch)*/
/*	%end;*/
/*	;*/
/*	by &By. &Groupn. _Varn_;*/
/*run;*/
data ___report_out_1;
	set ___procmean;
run;
proc sort data = ___report_out_1  ;
	By &Keepvars3. ;
run;

proc transpose data = ___report_out_1 out = ___report_out_2 prefix=_ngc;
	By &Keepvars3. ;
	id &Groupn.;
	idlabel &Group.;
	var &pmLtopVarname.   /*P S Pmatch */  ;
run;

** Create a format order to control the _Ltop By user customization *;
proc format;
	value $ Ltop_format_default
	%do f = 1 %to &nPmLtopkeyword.;
		%if "%upcase(&&pmLtopVarname&f)"^= "CV" %then %do;
		"&&pmLtopVarname&f" = "&Preblank.&&Ltopformat&f"
		%end;
	%end;
	"CV" = "&Preblank.%nrstr(%%)CV"
	;
run;
data ___report_out_3;
	length _Ltop $500 _NAME_ $32.;
	set ___report_out_2;
	By &Keepvars3. notSorted;
	_NAME_=strip(upcase(_NAME_));

	** Create _Ltop *;
	%do i=1 %to &nPmLtopkeyword.;
		if _name_ = "%upcase(&&pmLtopVarname&i..)" then do;
			_Ltopn = &i.;
		end;
	%end;
	_Ltop = trim(put(_name_,$Ltop_format_default.));
	%if %length(&Ltopformat.)>0 %then %do;
		_Ltop = trim(put(_name_,$&Ltopformat..));
	%end;
	if _name_='P' then _Ltopn=50;
	else if _name_='S' then _Ltopn=51;
	else if _name_='PMATCH' then _Ltopn=52;
	_Vvaluelabeln_=_Ltopn;
	%if "&Outstat."^="1" %then %do;
		if _name_='S' then delete;
	%end;
run;

proc sort data =___report_out_3(where=(^missing(_Vlabel_))) out=___report_out_4 ;
	by &By.  _Varn_ _Ltopn;
run;

data ___table_rtf_varlabel(where=(^missing(_text2)));
	length  _text2  $200;
	set ___report_out_4;
	by &By.  _Varn_ _Ltopn;
	if first._Varn_ ;
	_text2=_Vlabel_;
	_Ltopn=0;_Vvaluelabeln_=_Ltopn;
	keep  &By.  _text2 _Varn_ _Vname_ _Vvaluelabeln_;
run;

** ___table_rtf_list listvar列数据集 ;
	data ___table_rtf_list;		if _n_=0;	run;
%if %length(&nlistvars.)>0 %then %do;
			%local  Listvarnameby;
	%do i=1 %to &nlistvars.;
		%if %length(&Listvarnameby.) = 0 %then %do;
			%let Listvarnameby = %qcmpres(&&Listvarname&i..);
		%end;
		%else %let Listvarnameby = &Listvarnameby. %qcmpres(&&Listvarname&i..);
		proc sort data=___table_rtf_varlabel out=___table_rtf_list&i. nodupkey ;
			by &Listvarnameby;
		quit;
		data ___table_rtf_list&i.;
			length _text1 $200;
			set ___table_rtf_list&i.;
			_text2='';
			_Vvaluelabeln_=-10+&i.;	
			%if &i gt 1 %then %do;
				_text1=repeat("  ",&i.-2)||&&Listvarname&i.;
			%end;
			%else %do;	_text1=&&Listvarname&i.;
			%end;
		run;
		data ___table_rtf_list;
			set ___table_rtf_list ___table_rtf_list&i. ;
		run;
	%end;
%end;

data ___table_rtf_cat;
	length  _text2  $200;
	set ___report_out_4;
	by &By.  _Varn_ _Ltopn;
	_text2 = trim(put(_name_,$Ltop_format_default.));
	%if %length(&Ltopformat.)>0 %then %do;
		_text2 =  "&Preblank."||trim(put(_name_,$&Ltopformat..));
	%end;
	%do i=1 %to &nvar.;
		%if &&varmethod&i..=0 %then %do;
			if _Varn_=&i. and _name_='P' then delete;
		%end;
		%if &&match&i..=0 %then %do;
			if _Varn_=&i. and _name_='PMATCH' then delete;
		%end;
	%end;
	keep  _text2 
			%do trt_n=1 %to &all_trtn ; _ngc&trt_n. %end; _ngc99
			 &By.  _Varn_ _Vname_ _Vvaluelabeln_;
run;

%if &type.=1 %then %do;
	data ___table_rtf_varlabel_type1;
		set ___table_rtf_varlabel;
		_Vvaluelabeln_=1;
		rename _text2=_text1;
	run;
	proc sql undo_policy=none;
	     create table ___table_rtf_cat_type1  as
	          select distinct b._text1,a.*
	          from ___table_rtf_cat as a 
	          left join ___table_rtf_varlabel_type1 as b 
	          on a._Vvaluelabeln_=b._Vvaluelabeln_ and a._Varn_=b._Varn_ 
				%if %length(&by.)>0 %then   %do i=1 %to &nby; and a.&&by&i..=b.&&by&i.. %end;
	;
	quit;
%end;
** 定义header的N值全局宏变量 _GRP_n  ;
proc sql undo_policy=none;
    create table ___inds_grp as
        select distinct &Groupn.,&Group.,_Varn_,count(usubjid) as _grp
        from ___Conddsq 
		group by  &Groupn.,&Group.,_Varn_
		order by  &Groupn.,&Group.,_Varn_
;
quit;

** 定义header的N值全局宏变量 _GRP_n ,完全依据popn来计算header的n值 ;
data _null_;
	set ___header_out;
	call symputx('_GRP_'||strip(put(&Groupn.,best.)),strip(put(_grpsum_,best.)),'G');
run;
data ___table_rtf_varlabel1;
	set ___table_rtf_varlabel(rename=(_text2=_text1));
	_text1='    '||_text1;
run;
	data ___table_rtf_set;
	length _text1 _text2 %do trt_n=1 %to &all_trtn ; _ngc&trt_n. %end; _ngc99 $200;
		array a(*) $200 _text1;
		set %if &type.=1 %then %do;___table_rtf_cat_type1 %end;
			%else %do; ___table_rtf_varlabel1 ___table_rtf_cat %end; ___table_rtf_list
%if %sysfunc(exist(___pvalue_match_3)) %then ___pvalue_match_3;
;
	run;
*******************************************************************
add pvalue.
*******************************************************************;
%if %nobs(___pvalue)>0 %then %do;
	proc sql undo_policy=none;
	     create table ___table_rtf_set  as
	          select distinct a.*,b.s as s_value,b.p as p_value,b._method
	          from ___table_rtf_set as a 
	          left join ___pvalue as b 
	          on a._Varn_=b._Varn_ and a._Vvaluelabeln_=b._Vvaluelabeln_  
		%if %length(&by.)>0 %then	  %do i=1 %to &nby; and a.&&by&i..=b.&&by&i.. %end;

	;
	quit;
%end;
*******************************************************************
Step3.删除中间数据集及输出
_table_rtf_sort：含排序变量比的数据集
_table_rtf：无排序变量数据集
*******************************************************************;
	proc sort data=___table_rtf_set out=&Outds._sort;
		by &By.  _Varn_  _Vvaluelabeln_;
	quit;
	proc sort data=&Outds._sort out=&Outds. ( drop= &By.  _Varn_ _Vname_ _Vvaluelabeln_) ;
		by &By.  _Varn_  _Vvaluelabeln_;
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
%do lp=1 %to &all_trtn;
	%put ***treatment group&lp num is &&_GRP_&lp;
%end;
	%put ***treatment group99 num is &_GRP_99;
%exit:

ods exclude none;
%mend quandesc;
