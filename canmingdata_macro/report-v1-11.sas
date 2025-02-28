/*************************************************************************************************
File name: report-v1-10.sas

Study:

SAS version: 9.4

Purpose: report listing and table

Macros called: %Separate_param, %m_var_exist, %m_var_type,%rtftemp

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 06SEP2023

Date completed: 06SEP2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 06SEP2023 Hao.Guo create
1.1 05DEC2023 Hao.Guo if population is mising then change then title_text near 1275
1.2 14DEC2023 Hao.Guo add Compute_line= for a black _row_
1.3 22DEC2023 Hao.Guo for batchrun so delete prco printto
1.4 23FEB2024 Hao.Guo add ods exclude none
1.5 07MAR2024 Hao.Guo add _null__program_name dataset and put error
1.6 29MAY2024 Hao.Guo change fs form 9 to 10
1.7 14JUN2024 Hao.Guo TitleNo blank MainTitle
1.8 13AUG2024 Hao.Guo no reocord display modyfie wujilu 
1.9 19AUG2024 Hao.Guo %let _program_name=%lowcase(&table)
1.10  21AUG2024 Hao.Guo 1.title_text = tranwrd(title_text, "%", "\uc0\u37") 
						2.debug for weichushihua
						3.call symputx("SAS_prog_name",SAS_prog_name)
1.11  01JAN2024 Hao.Guo 1.ADD qctable.title_footnote 

*********************************** Prepared by Highthinkmed ************************************/
%macro report(title =
,OutputFileName=
,Norecord =
,dataset =
,cond =
,varlist =

,debug =
,Footnote =
,FootnoteDisplay=
,Compute_line=
)/MINOPERATOR store;

	ods exclude none;
    %put Running Macro (&SYSMACRONAME. V1.4);
	%******************************************;
	%** get_program_name ;
	%******************************************;
	%let _program_name=%lowcase(&table);
	%if &Debug > 0 %then %do;	%put Get_Program_Name:&_program_name; %end;

	%if %length(&OutputFileName.)=0 %then %let OutputFileName=&_program_name;
	%******************************************;
	%** initialize, macro variables and datase ;
	%******************************************;

	title ;
	footnote ;

	%global _hpagewidth _displayheader escapechar  _paging _bodytitle_aux bodytitle_aux _orientation _PageInFootnote _RTFFMT _ENCODING _ROLE;
	%local i j k _varlist column _ntitle lastordervar maxmergeheader computetype ncomputevar _calculate 
	gpagesize ptr lastbyvar titleweight 
	PaddingBottom PaddingTop PaddingLeft PaddingRight CellPadding RenameForCompare CodeBeforeReport HeaderJusteqColumn VerticalAlign
	Skip Breakvars ComputeLine Computestyle PageInFootnote FootnoteDisplay FootnoteFs Tabwp datarows Fs
	dsid rc __report_in_nobs
	org_ordervarlist new_ordervarlist
	breakvars_comma breakvars_last
	sourcefootnote Pretext By
	getpage _titletext Order_Y_N ID_N PAGE_N ;


	%** whether display header when output blank page ;
	%if %length(&dataset.)=0 %then %let dataset=_table_rtf;
	%if %length(&_displayheader.)=0 %then %let _displayheader=1;
	%if %length(&cond.)=0 %then %let cond=1;
	%if %length(&escapechar.) = 0 %then %let escapechar=~;
	%if %length(&_orientation.) = 0 %then %let _orientation=landscape;
	%if %length(%nrbquote(&Norecord.))=0 and %symexist(_Norecord) %then %let Norecord=%nrbquote(&_Norecord);
	%if %length(&_RTFFMT.)=0 %then %let _RTFFMT=CH;
	%if %length(&_ENCODING.)=0  %then %let _ENCODING=UTF-8;
	%if %length(&_ROLE.)=0 %then %do;
		%put ERR%STR()OR: Please use %setlib() or user define macro variable _ROLE,value of macro variable _ROLE must be QC or Primary! ;
		%goto exit;
	%end;
	
	%let _paging=0;
	%let bodytitle_aux=0;
/*	%if %length(&_bodytitle_aux.)=0  %then %let bodytitle_aux=0;*/
/*	%else %do; %let bodytitle_aux=&_bodytitle_aux.; %end;*/


	%** text in table ;
	%if %length(%nrbquote(&title.))=0 and %symexist(_Title_) %then %let Title=%nrbquote(&_Title_);
	%if %length(%nrbquote(&footnote.))=0 and %symexist(_footnote_) %then %let footnote=%nrbquote(&_footnote_);
	%if %length(&Pretext.)>0 %then %let Title=&Title.$&Pretext.;

	%** control display ;
	%if %length(&FootnoteDisplay.)=0 %then %let FootnoteDisplay=0;
	%if %length(&PaddingBottom.)=0 %then %let PaddingBottom=1;
	%if %length(&PaddingTop.)=0 %then %let PaddingTop=3;
	%if %length(&PaddingLeft.)=0 %then %let PaddingLeft=1.5;
	%if %length(&PaddingRight.)=0 %then %let PaddingRight=1.5;
	%let _leftmargin=1in;
	%let _rightmargin=1in;
	%let _bottommargin=1in;
	%let _topmargin=1in;
	%if %length(&VerticalAlign.)=0 %then %let VerticalAlign=Top;

	%** footnote information;
	%if %length(&fs.)=0 %then %let fs=10;
	%let fs=%sysfunc(compress(%nrbquote(&fs.),,kd));
	%if %length(&FootnoteFs.)=0 %then %let FootnoteFs=&fs.;
	%let FootnoteFs=%sysfunc(compress(%nrbquote(&FootnoteFs.),,kd));
	%if %length(&PageInFootnote.) = 0 %then %do;
	%if %length(&_PageInFootnote.)>0 %then %let PageInFootnote = &_PageInFootnote.;
	%else %let PageInFootnote = 0;
	%end;

	%** PageInFootnote Just Be Used in _Paging = 1;
	%if &PageInFootnote. = 1 and &_Paging. = 0 %then %do;
		%put ERR%str()OR: PageInFootnote = 1 can not be used in Paging = 0.;
		%let PageInFootnote = 0;
	%end;

	%** whether rename the name of variables in compared dataset ;
	%if %length(&RenameForCompare.)=0 %then %let RenameForCompare=1;
	%if %length(&HeaderJusteqColumn.)=0 %then %let HeaderJusteqColumn=0;

	%** derive macro variables needed ;
	%if %length(&by.)>0 %then %let lastbyvar = %scan(&by.,-1,%str( ));%** last variable if BY statement ;
	%if %length(&Breakvars.)>0 %then %let LastBreakvar = %scan(&Breakvars.,-1,%str( ));%** last variable if Breakvars statement ;

	%** check fontsize must in 7 8 9 10 11;
	%if not (&fs. in (7 8 9 10 11)) %then %do;
		%put ERR%STR()OR: Fs should be specified to numeric 7, 8, 9, 10, 11.;
		%goto exit;
	%end;

	%** Check Order ;
	%let Order_Y_N = N;

	%** Tabwp;
	%if %length(&tabwp.) = 0 %then %let tabwp = 98;

	proc datasets nolist nodetails NoWarn lib=work;
		delete __report_in _mergeheader: _varlist1 _varlist2 _width1_label _width1_value _width2 _width3 _width4 _none
		__report_out __report_in___pre __report_in_braek/memtype=data;
	quit;

	%************************************************************************;
	%** separate varlist: get variable name, label, width, align, order, asis ;
	%************************************************************************;
	%if %length(&varlist.)>0 %then %do;
		%Separate_param(varlist = %nrbquote(&varlist.)
		,separators = | \ /
		,amounts = 0 0 0
		,outds = _varlist1 );

		%** _exist : remove the varibale if all missing value in a order1 ;
		proc sql undo_policy=none;
		create table _varlist1(drop = order1) as
		select distinct *,order1 as order1_,max(^missing(value)) as _exist
		from _varlist1
		group by order1
		order by order1_,order2,order3
		;
		quit;

		%let ID_N = 0;
		%let PAGE_N = 0;

		data _varlist2(drop = order1_);
			length compheader $400;
			set _varlist1 end=end;
			by order1_ order2 order3;
			where _exist=1 and ^missing(order1_); %** remove the blank records in varlist;
			retain order1 PAGE_N 0 compheader "";
			if _N_ = 1 then PAGE_N = 0;
			if first.order1_ then do;
				order1+1; %** derived continuous order of report variable , which replace the pervious order1 ;
				%** initialize macro variables ;
				compheader=""; %**compheader, just store the header and order into the compare dataset;
				call symputx("var"||strip(put(order1,best.)),"","L");
				call symputx("label"||strip(put(order1,best.)),"","L");
				call symputx("width"||strip(put(order1,best.)),"","L");
				call symputx("align"||strip(put(order1,best.)),"C","L");
				call symputx("order"||strip(put(order1,best.)),"","L");
				call symputx("asis"||strip(put(order1,best.)),"","L");
				call symputx("ID"||strip(put(order1,best.)),"","L");
				call symputx("PAGE"||strip(put(order1,best.)),"","L");
			end;
		if order2=1 and order3=1 then do;
			%** variable name ;
			value=strip(value);
			call symputx("var"||strip(put(order1,best.)),strip(value),"L");
			end;
			else if order2=1 and order3=2 then do;
			%** variable label ;
			call symputx("label"||strip(put(order1,best.)),'%nrstr('||trim(tranwrd(tranwrd(tranwrd(value,"%","%%"),"'","%'"),'"','%"'))||')',"L");
			compheader=strip(value);
		end;
		else if order2=1 and order3=3 then do;
			%** variable width, required numeric ;
			if lengthn(compress(value,' .','d'))>0 then put "ERR" "OR: Width of variable should be numeric, but the width of the " order1 "variable is :" value;
			call symputx("width"||strip(put(order1,best.)),trim(value),"L");
		end;
		else if order2=1 and order3>3 then do;
			%** merge header ;
			compheader=catx("/",compheader,value);
		end;
		else if order2 >= 2 and order3=1 then do;
			%** order, align or asis ;
			if upcase(compress(value)) not in ("" "C" "R" "L" "ORDER" "3" "ASIS=ON" "ASIS=OFF" "ID" "PAGE") then put "ERR" "OR: " value " in Varlist= is not avail. It must be C, R, L, ORDER, 3, ASIS=ON, ASIS=OFF." ;

			if upcase(compress(value)) in ("C" "R" "L") then call symputx("align"||strip(put(order1,best.)),trim(value),"L");
			else if upcase(compress(value)) in ("ORDER" "3") then do;
			call symputx("order"||strip(put(order1,best.)),"order","L");
			call symputx("Order_Y_N","Y");
			compheader=cats(compheader,"\order");
		end;
		else if upcase(compress(value)) in ("ASIS=ON" "ASIS=OFF") then call symputx("ASIS"||strip(put(order1,best.)),trim(value),"L");
		else if upcase(compress(value)) in ("ID") then do;
			call symputx("ID"||strip(put(order1,best.)),trim(value),"L");
			call symputx("ID_N",strip(put(order1,best.)),"L");
		end;
		else if upcase(compress(value)) in ("PAGE") then do;
			call symputx("PAGE"||strip(put(order1,best.)),trim(value),"L");
			PAGE_N = PAGE_N + 1;
			call symputx("PAGE_N",strip(put(PAGE_N,best.)),"L");
			call symputx("PAGE_P"||strip(put(PAGE_N,best.)),strip(put(order1,best.)),"L");
		end;
		end;
		if last.order1_ then do;
			compheader=tranwrd(compheader,"$"," ");
			call symputx("compheader"||strip(put(order1,best.)),'%nrstr('||strip(tranwrd(tranwrd(tranwrd(compheader,"%","%%"),"'","%'"),'"','%"'))||')',"L");
		end;
		if end then call symputx("nvar",strip(put(order1,best.)),"L");
		run;

	%** new_orderlist include new order variables which can keep the order of dataset in proc report ;
	%** get the last order variable for skip=1 ;

	%let lastordervar=;
	%let org_ordervarlist=;
	%let new_ordervarlist=;
		%do i=1 %to &nvar.;
			%if "&&order&i.."="order" %then %do;
			%let lastordervar = &&var&i..; %** for skip=1 ;
			%let org_ordervarlist = &org_ordervarlist. &&var&i..;
			%let new_ordervarlist = &new_ordervarlist. __&&var&i..;
			%end;
		%end;

		%if %length(&skip.)>0 %then %do;
			%if "&skip."="1" %then %do;
			%** The last order variable is the skip variable if skip=1 ;
				%if %length(&lastordervar.)>0 %then %let skip = &lastordervar.;
				%else %if %length(&computeline.)>0 %then %do;
				%let skip = _compute_;
				%end;
				%else %do;
				%put ERR%STR()OR: Parameter SKIP=1, but there are no order variable in VARLIST= and no COMPUTELINE= !!!;
				%goto exit;
				%end;
			%end;
			%else %if "&skip."="0" %then %let skip=;
			%else %do;
			%** The skip variable should be in dataset ;
				%if %m_var_exist(&dataset., &skip.)<=0 %then %do;
				%put ERR%STR()OR: Variable SKIP=&skip. does not exist in dataset &dataset.!!!;
				%goto exit;
				%end;
			%** The skip variable should be in order varlist ;
				%if %index(%upcase(&org_ordervarlist.),%upcase(&skip.))<=0 %then %do;
				%put ERR%STR()OR: Variable SKIP=&skip. does not exist in order varlist!!! Please specify ORDER for variable &skip..;
				%goto exit;
				%end;
			%end;
		%end;
	%end;%** end varlist justify;

	%else %do;
		%put Reporting a blank page without headers because no VARLIST.;
		%goto starttf;
	%end;

%************************************************************************;
%** Multiple Header ;
%************************************************************************;

%** sort and keep order2=1 (variable name, label, width and multiple header) ;
proc sort data = _varlist2 out = _mergeheader1;
where ^missing(order3) and order2=1 and ^missing(value) ;
by order1 order2 order3;
run;

proc sql undo_policy=none noprint;
select distinct max(order3) into: maxmergeheader from _mergeheader1; %** max number of multiple header ( include var name, label, width);
quit;
%let maxmergeheader=%cmpres(&maxmergeheader.);

proc transpose data=_mergeheader1 out=_mergeheader2 prefix=header; %** one record per variable ;
by order1;
id order3;
var value;
run;

%let _BlankCol_N = 0;
data _mergeheader3; %**derive text for column statement in proc report ;
	length column $32767.;
	set _mergeheader2 end=end;
	by %do i=&maxmergeheader. %to 4 %by -1; header&i. %end; notsorted;
	retain column "";
	%do i= &maxmergeheader. %to 4 %by -1;
	if first.header&i. and ^missing(header&i.) then do;
		%** add a blank column between two multiple headers ;
		if ^missing(column) then do;
			if substr(column,lengthn(column))=")" then column=trim(column)||' _blankcol';
		end;

		%** add multiple header and underline, \brdrb\brdrs ;
		column=trim(column)||' ( "'||trim(header&i.)||'\brdrb\brdrs"';
	end;
	%end;

	%** concatenate variables ;
	%do i = 1 %to &nvar.;
		%if "&&order&i.."="order" %then %do;
			%** concatenate numeric varibale __&&var&i.. if order variables ;
			if header1="&&var&i.." then column=trim(column)||" __"||strip(header1)||" "||strip(header1);
		%end;
		%else %do;
			if header1="&&var&i.." then column=trim(column)||" "||strip(header1);
		%end;
	%end;

	%do i= &maxmergeheader. %to 4 %by -1;
		%** concatenate right quote if end of multiple header ;
		if last.header&i. and ^missing(header&i.) then column=trim(column)||")";
	%end;
	if end then do;
		call symputx("column",strip(column),"L");
		call symputx("_blankcol_n",strip(put(count(column,"_blankcol"),best.)),"L");
	end;
run;

%********************************************;
%** computeline ;
%********************************************;

%let ncomputevar=0;
%let computetype=;
%if %length(%nrbquote(&computeline.))>0 %then %do;
%if %index(%nrbquote(&computeline.),[) %then %do;
%** compute and display a line of text ;
%let computetype=TEXT;

%** change to SAS code ;
%let i=1;
%let computevar=%substr(%nrbquote(&computeline.),%index(%nrbquote(&computeline.),[));
%do %while( %length(%scan(%nrbquote(&computevar.),&i.,[))>0 );
%let computevar&i.=%scan(%nrbquote(&computevar.),&i.,[);
%let computevar&i.=%sysfunc(compress(%scan(%nrbquote(&&computevar&i..),1,])));
%if %m_var_exist(&dataset., &&computevar&i..)<=0 %then %do;
%put ERR%STR()OR: Variable &&computevar&i.. specified in COMPUTELINE=, but does not exist in &dataset.. ;
%goto exit;
%end;
%let i=%eval(&i+1);
%end;
%let ncomputevar=%eval(&i-1);

data _null_;
length txt $5000;
txt="&computeline.";
%do i=1 %to &ncomputevar.;
txt=tranwrd(txt,"[&&computevar&i..]","'||strip(vvalue(&&computevar&i..))||'");
%end;
txt= tranwrd(tranwrd("'"||strip(txt)||"'","''||",""),"||''","");
call symputx("computetext",strip(txt),"L");
run;
%end;
%else %do;
%put ERR%STR()OR: There are no variable in COMPUTELINE=!!!;
%goto exit;
%end;
%end;

%************************************************************************;
%** screen input dataset,
derive new order variables to keep the order of dataset
derive _compute_ for compute line
;
%************************************************************************;

%** Input dataset;
data __report_in___pre;
set &dataset.;
where &cond.;
%if "&_paging."="0" %then %do;
page_seq=1;
%end;
run;

data __report_in;
set __report_in___pre;
_blankcol="";
__n_for_report = _n_;

%if %length(%nrbquote(&computeline.))>0 or %length(%nrbquote(&breakvars.))>0 %then %do;

%if %length(%nrbquote(&computeline.))>0 %then %do;
%** derive ___compute_ and _compute_ variable to compute line.;
length _compute_ $1000;
_compute_=&computetext.;
%end;

%if %length(%nrbquote(&breakvars.))>0 and "&_paging."="1" %then %do;
%** derive _breakvar_group variable to adjust page break according to breakvars.;
by &breakvars. notsorted;
retain _breakvar_group 0;
if first.&LastBreakvar. then _breakvar_group=__n_for_report;
%end;

data __report_in;
set __report_in;
%end;

%** derive new order variables ;
%if %length(&org_ordervarlist.)>0 or %length(%nrbquote(&computeline.))>0 %then %do;
by %if %length(%nrbquote(&computeline.))>0 %then _compute_ ; &org_ordervarlist. notsorted;
retain %if %length(%nrbquote(&computeline.))>0 %then ___compute_ ; &new_ordervarlist. 0;
%if %length(%nrbquote(&computeline.))>0 %then %do;
if first._compute_ then ___compute_+1;
%end;
%do i=1 %to &nvar.;
%if "&&order&i.."="order" %then %do;
if first.&&var&i.. then __&&var&i.+1;
%end;
%end;
%end;

keep _blankcol __n_for_report &by.
%if %length(%nrbquote(&computeline.))>0 %then ___compute_ _compute_ ;
%if %length(%nrbquote(&breakvars.))>0 and "&_paging."="1" %then _breakvar_group ;
&new_ordervarlist.
%do i=1 %to &nvar.;
&&var&i..
%end;
%if "&_paging."="0" %then %do; page_seq %end;
;
run;

%** get the record number of input dataset, report blank page if no record ;
%let dsid=%sysfunc(open(__report_in,i));
%let __report_in_nobs=%sysfunc(attrn(&dsid.,NOBS));
%let rc=%sysfunc(close(&dsid.));

%**************************************************;
%** Calculate Width in cm and Output Rows ;
%** 1.Sponsor information ;
%** 2.Title ;
%**************************************************;
%** speify the total lines for one page and PTR according to fontsize ;
%** Calculate useble papersize unit is in;
%let _papersize=A4;
%let _FONT=TIMES NEW ROMAN;
data _useble_pagersize;

	%** Get the Paper Size;
	%if %upcase(&_papersize.) = A4 %then %do;
	paper_width = %if %lowcase(&_orientation.) = portrait %then 8.27;%if %lowcase(&_orientation.) = landscape %then 11.7;;
	paper_height = %if %lowcase(&_orientation.) = portrait %then 11.7;%if %lowcase(&_orientation.) = landscape %then 8.27;;
	%end;
	%if %upcase(&_papersize.) = LETTER %then %do;
	paper_width = %if %lowcase(&_orientation.) = portrait %then 8.5;%if %lowcase(&_orientation.) = landscape %then 11;;
	paper_height = %if %lowcase(&_orientation.) = portrait %then 11;%if %lowcase(&_orientation.) = landscape %then 8.5;;
	%end;

	%** Get the top bottom left right Size;
	topmargin = "&_topmargin.";
	bottommargin = "&_bottommargin.";
	leftmargin = "&_leftmargin.";
	rightmargin = "&_rightmargin.";
	array margin(4) $ topmargin bottommargin leftmargin rightmargin;
	array margin_n(4) topmargin_n bottommargin_n leftmargin_n rightmargin_n;
	do i = 1 to 4;
	%** Unit in In;
	margin_n(i) = input(compress(margin(i),".","kd"),best.);
	end;

	%** Usable Size;
	usable_width = (paper_width - leftmargin_n - rightmargin_n)*72;
	call symput("usable_width",strip(put(usable_width,best.)));
	usable_height = (paper_height - topmargin_n - bottommargin_n)*72;
	call symput("usable_height",strip(put(usable_height,best.)));
run;
%** Macro variable for calculating width;
%local _calculate;

%** Calculation mode applicable to fonts, Now has Times New Roman, Arial, Simsun;
%** For Arial;
%** Do not calculation { };
%if %upcase("&_Font") = "ARIAL" %then %do;
	%let _calculate = ((_cchar_ in ("%nrstr(%')" )) * 391) +
		((_cchar_ in ('i' 'j' 'l' )) * 455) +
		((_cchar_ in ("|" )) * 532) +
		((_cchar_ in ("!" "," "." "/" "[" "\" "]" "f" "I" " " "t")) * 569) +
		((_cchar_ in ("-" "(" ")" "r" ":" ";" )) * 682) +
		((_cchar_ in ('"' )) * 727) +
		((_cchar_ in ('*' )) * 797) +
		((_cchar_ in ('^' )) * 961) +
		((_cchar_ in ("c" "J" "k" "s" "v" "x" "y" "z" )) * 1024) +
		((_cchar_ in ("#" "$" "?" "_" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "d" "e"
		"g" "h" "L" "n" "o" "p" "q" "u" )) * 1139) +
		((_cchar_ in ("~" "+" "<" "=" ">" )) * 1196) +
		((_cchar_ in ("F" "T" "Z" )) * 1251) +
		((_cchar_ in ('&' "A" "B" "E" "K" "P" "S" "V" "X" "Y" )) * 1366) +
		((_cchar_ in ("C" "D" "H" "N" "R" "U" "w" )) * 1479) +
		((_cchar_ in ("G" "O" "Q" )) * 1593) +
		((_cchar_ in ("M" "m" )) * 1706) +
		((_cchar_ in ("%" )) * 1821) +
		((_cchar_ in ("W" )) * 1933) +
		((_cchar_ in ("@" )) * 2079);

	%let _calculate_b = ((_cchar_ in ("%nrstr(%')" )) * 487) +
	((_cchar_ in ("|" )) * 573) +
	((_cchar_ in ("!" "," "." "/" ":" ";" "\" "I" 'i' 'j' " "
	'l' )) * 569) +
	((_cchar_ in ("-" "(" ")" "[" "]" "f" "t" )) * 682) +
	((_cchar_ in ('"' )) * 971) +
	((_cchar_ in ('*' "r" )) * 797) +
	((_cchar_ in ("z" )) * 1024) +
	((_cchar_ in ("#" "$" "_" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "c" "e"
	"J" "k" "s" "v" "x" "y" )) * 1139) +
	((_cchar_ in ("~" "+" "<" "=" ">" '^' )) * 1196) +
	((_cchar_ in ("F" "T" "Z" "?" "L" "b" "d" "g" "h" "n"
	"o" "p" "q" "u" )) * 1251) +
	((_cchar_ in ("E" "P" "S" "V" "X" "Y" )) * 1366) +
	((_cchar_ in ("C" "D" "H" "N" "R" "U" '&' "A" "B" "K" )) * 1479) +
	((_cchar_ in ("G" "O" "Q" "w" )) * 1593) +
	((_cchar_ in ("M" )) * 1706) +
	((_cchar_ in ("%" "m" )) * 1821) +
	((_cchar_ in ("W" )) * 1933) +
	((_cchar_ in ("@" )) * 1997);
%end;

%** For Times New Roman and Simsun, Simsun like Times New Roman?;
%if %upcase("&_Font") = "TIMES NEW ROMAN" or %upcase("&_Font") = "SIMSUN" %then %do;
	%let _calculate = ((_cchar_ in ("%nrstr(%')" )) * 369) +
	((_cchar_ in ("|" )) * 410) +
	((_cchar_ in ("/" ":" ";" "t" 'i' 'j' "l" "\" )) * 569) +
	((_cchar_ in ("," "." " " )) * 512) +
	((_cchar_ in ("-" "(" ")" "r" "!" "I" "[" "]" "`" "f" )) * 682) +
	((_cchar_ in ('"' )) * 836) +
	((_cchar_ in ("J" "s" )) * 797) +
	((_cchar_ in ("?" "a" "c" "e" "z" )) * 909) +
	((_cchar_ in ('^' )) * 961) +
	((_cchar_ in ("v" "x" "y" "#" "$" '*' "0" "1" "2" "3" "4" "5" "6" "7"
	"8" "9" "_" "b" "d" "g" "h" "k" "n" "o" "p" "q" "u")) * 1024) +
	((_cchar_ in ("~" )) * 1108) +
	((_cchar_ in ("F" "P" "S" )) * 1139) +
	((_cchar_ in ("+" "<" "=" ">" )) * 1155) +
	((_cchar_ in ("T" "Z" "E" "L" )) * 1251) +
	((_cchar_ in ("B" "C" "R" )) * 1366) +
	((_cchar_ in ("A" "D" "G" "H" "K" "N" "Q" "U" "w" "V" "X" "Y" "O")) * 1479) +
	((_cchar_ in ('&' "m" )) * 1593) +
	((_cchar_ in ("%" )) * 1706) +
	((_cchar_ in ("M" )) * 1821) +
	((_cchar_ in ("@" )) * 1886) +
	((_cchar_ in ("W" )) * 1933);

	%let _calculate_b = ((_cchar_ in ("%nrstr(%')" )) * 569) +
	((_cchar_ in ("|" )) * 451) +
	((_cchar_ in ("/" ";" 'i' "l" "\" )) * 569) +
	((_cchar_ in ("," "." " " )) * 512) +
	((_cchar_ in ("-" "(" ")" "!" "[" "]" "`" "f" ":" 'j' "t"
	)) * 682) +
	((_cchar_ in ('"' )) * 1137) +
	((_cchar_ in ("s" "I" )) * 797) +
	((_cchar_ in ("?" "c" "e" "z" "r" )) * 909) +
	((_cchar_ in ('^' )) * 1190) +
	((_cchar_ in ("v" "x" "y" "#" "$" '*' "0" "1" "2" "3" "4" "5" "6" "7"
	"8" "9" "_" "a" "g" "o" "J" )) * 1024) +
	((_cchar_ in ("~" )) * 1065) +
	((_cchar_ in ( "S" "b" "d" "h" "k" "n" "p" "q" "u" )) * 1139) +
	((_cchar_ in ("+" "<" "=" ">" )) * 1167) +
	((_cchar_ in ( "P" "F" )) * 1251) +
	((_cchar_ in ("B" "E" "L" "T" "Z" )) * 1366) +
	((_cchar_ in ("A" "C" "D" "R" "N" "U" "w" "V" "X" "Y" )) * 1479) +
	((_cchar_ in ("G" "H" "K" "O" "Q" )) * 1593) +
	((_cchar_ in ('&' "m" )) * 1706) +
	((_cchar_ in ("%" )) * 2048) +
	((_cchar_ in ("M" )) * 1933) +
	((_cchar_ in ("@" )) * 1905) +
	((_cchar_ in ("W" )) * 2048);
%end;

%************************************ Calculate Header Width and Use lines ********************************;
%** get the actual rows for split by $;
data _width1_label;
	length __m_source $100.;
	%do i=1 %to &nvar.;
	length _vc&i. $5000.;
	_vc&i. = tranwrd("&&label&i..","$"," "||byte(27));
	%end;
	__m_source = "the width of label";
run;

%************************************** Calculate Report Text Width and Use lines ********************************;

%** get the format of variables to calculate length ;
data _null_;
set __report_in (obs=1);
%do i=1 %to &nvar.;
%local vformat&i.;
call symputx("vformat&i.",vformat(&&var&i..),"L");
%end;
run;data _width1_label_value

%** Split word by newline charater;
data _width1_value;
	length __m_source $100.;
	set __report_in;
	__m_source = "the width of value";
	array o_char(4) $100 ("&escapechar.R/RTF'{\line}" " " "&escapechar.R/RTF""{\line}" " ");
	array r_char(4) $100 ("&escapechar.R\/RTF'{\\line}'" "&escapechar.R\/RTF'{\\line}" "&escapechar.R\/RTF""{\\line}""" "&escapechar.R\/RTF""{\\line}");
	%do i=1 %to &nvar.;
	length _vc&i. $5000.;
	%if %length(&&vformat&i..) > 0 %then %do;
	_vc&i. = strip(put(&&var&i..,&&vformat&i..));
	%end;
	%else %do;
	%if %m_var_type(__report_in,&&var&i..) = "C" %then _vc&i. = &&var&i..;;
	%if %m_var_type(__report_in,&&var&i..) = "N" %then _vc&i. = strip(put(&&var&i..,best.));;
	%end;
	do i = 1 to 4 by 2;
	if find(_vc&i.,strip(o_char(i)),"i") then _vc&i. = prxchange("s/("||strip(r_char(i))||")|("||strip(r_char(i+1))||")/"||byte(32)||byte(27)||"/i",-1,_vc&i.);
	end;
	%end;
	keep __m_source __n_for_report
	%if %length(%nrbquote(&computeline.))>0 %then ___compute_ _compute_ ;
	_vc1 - _vc&nvar.;
run;

data _width1_value;
set _width1_value;
by _vc1 - _vc&nvar. notsorted;
%do i=1 %to &nvar.;
%if %length(&&order&i..) >0 %then %do;
if ^(first._vc&i.) then call missing(_vc&i.);
%end;
%end;
run;
proc append base= _width1_value data=_width1_label force nowarn;
run;

%** get the width of all records ;
data _width1_label_value;
	set _width1_value;
	array _vc(*) $ _vc1 - _vc&nvar.;
	array _vc_clen_save(*) $3000 _vc_clen_save1 - _vc_clen_save&nvar.;
	array o_char(8) $50 ("\uc" "&escapechar.{unicode" "{\super " "{\sub " "&escapechar.{super " "&escapechar.{sub " "&escapechar.R/RTF'{\cf " "&escapechar.R/RTF""{\cf ");
	array r_char(8) $50 ("{\\uc(\d+)\\u(\d+)}" "&escapechar.{unicode[[:ascii:]]+}" "{\super " "{\sub " "&escapechar.{super " "&escapechar.{sub " "&escapechar.R/RTF'{\cf " "&escapechar.R/RTF""{\cf ");
/*	length _cchar_ $10. ;*/

	if __m_source = "the width of value" then __m_source_b = 0;
	else __m_source_b = 1;
	%** Calculate lines of Varlist;
	do i=1 to &nvar.;
	%** One RTF/unicode code about equal to two "yy" width;
	do j = 1 to 8;
	if find(_vc(i),strip(o_char(j)),"i") then _vc(i) = prxchange("s/"||strip(r_char(j))||"/yy/i",-1,_vc(i));
	end;

	%** find super/sub/new line code equal to empty;
	end;

	%if %length(%nrbquote(&computeline.))>0 %then %do;
	%** Calculate lines of computeline, _comp_line ;
	length _vc_clen_save_comp $1000.;
	by ___compute_ notsorted ;
	if first.___compute_ then do;
	retain __comp_lines;
	end;
	keep __comp_lines;
	%end;

	keep __m_source __n_for_report _vc_clen_save1 - _vc_clen_save&nvar.;
run;

%*********************************** Calculate Cellwidth Percent of Header and Value *********************************;
%let Use_Ratio = (0.98 - 0.003 * &_blankcol_n.);

%** Calculate the sum of each column max_width;
data _width1;
set _width1_label_value
;
array _vc_clen_save(*) _vc_clen_save1 - _vc_clen_save&nvar.;
array _vc_clen_(*) _vc_clen_1 - _vc_clen_&nvar.;
do i = 1 to &nvar.;
_vc_clen_(i) = 0;
do j = 1 to count(_vc_clen_save(i),"|");
_vc_clen_(i) = max(_vc_clen_(i),input(scan(scan(_vc_clen_save(i),j,"|"),2,"="),best.)) ;
end;
if _vc_clen_(i) > 0 then _vc_clen_(i) = _vc_clen_(i) * &fs. + (&PaddingLeft. + &PaddingRight.) ;

%** Delete extra long field;
if _vc_clen_(i) > &usable_width. * 0.5 then delete;
end;
run;

proc sql;
create table _width1_max as
select distinct "Column Max Length" as __m_source
%do i = 1 %to &nvar.; ,max(_vc_clen_&i.) as _vc_clen_max_&i. %end;
from _width1
;
quit;
%** Use the Max Width to Calculate the Max Total Width;
data _width1_Precent;
set _width1_max;
array _vc_clen_max(*) _vc_clen_max_1 - _vc_clen_max_&nvar.;
array _vc_clen_p(*) _vc_clen_p1 - _vc_clen_p&nvar.;
_total_actual_length_ID = 0;
_total_actual_length_ID_P = 0;
_total_actual_length = sum(of _vc_clen_max_1 - _vc_clen_max_&nvar.) * &nvar.;

%if &ID_N. > 0 %then _total_actual_length_ID = sum(of _vc_clen_max_1 - _vc_clen_max_&ID_N.) * &ID_N. ;;
__sum_p = 0;
%if &PAGE_N. = 0 %then %do;
do i = 1 to &nvar.;
if missing(symget("width"||strip(put(i,best.)))) then _vc_clen_p(i) = (_vc_clen_max(i))/_total_actual_length*100*&Use_Ratio.;
else _vc_clen_p(i) = input(symget("width"||strip(put(i,best.))),best.);
end;
__sum_p = sum(of _vc_clen_p1 - _vc_clen_p&nvar.) ;
do i = 1 to &nvar.;
_vc_clen_p(i) = (_vc_clen_p(i)/__sum_p)*100*&Use_Ratio.;
call symput("width"||strip(put(i,best.)),strip(put(_vc_clen_p(i),best.)));
end;
%end;
%if &PAGE_N. ~= 0 %then %do;
Page_Cumulative = 0;
%do j = 1 %to %eval(&PAGE_N.+1);
%** Calculate from the first column to the previous column of the first page;
%if &j. = 1 %then %do;
_total_actual_length_page&j. = sum(of _vc_clen_max_1 - _vc_clen_max_%eval(&&PAGE_P&j..-1));
page_start = 1;
page_end = &&PAGE_P&j.. - 1;
Percent = 100;
%end;
%** Calculate from between page and page;
%if &j.>1 and &j.<%eval(&PAGE_N.+1) %then %do;
_total_actual_length_page&j. = sum(of _vc_clen_max_1 - _vc_clen_max_%eval(&&PAGE_P&j..-1)) - Page_Cumulative;
%let j_p = %eval(&j.-1);
page_start = &&PAGE_P&j_p..;
page_end = &&PAGE_P&j.. - 1;
Percent = 100 - _total_actual_length_ID_P;
%end;
%** Calculate from the column of the last page to the last column;
%if &j. = %eval(&PAGE_N.+1) %then %do;
_total_actual_length_page&j. = sum(of _vc_clen_max_1 - _vc_clen_max_&nvar.) - Page_Cumulative;
%let j_p = %eval(&j.-1);
page_start = &&PAGE_P&j_p..;
page_end = &nvar.;
Percent = 100 - _total_actual_length_ID_P;
%end;

%** Calculate the Percent of Width;
do i = page_start to page_end;
if missing(symget("width"||strip(put(i,best.)))) then _vc_clen_p(i) = (_vc_clen_max(i))/_total_actual_length_page&j.*100*&Use_Ratio.;
else _vc_clen_p(i) = input(symget("width"||strip(put(i,best.))),best.);

__sum_p = __sum_p + _vc_clen_p(i);
end;

do i = page_start to page_end;
_vc_clen_p(i) = (_vc_clen_p(i)/__sum_p)*Percent*&Use_Ratio. ;
call symput("width"||strip(put(i,best.)),strip(put(_vc_clen_p(i),best.)));
end;
%if &j. = 1 %then %do;
do i = 1 to &ID_N.;
_total_actual_length_ID_P = _total_actual_length_ID_P + _vc_clen_p(i);
end;
%end;
Page_Cumulative = Page_Cumulative + _total_actual_length_page&j. - _total_actual_length_ID;
__sum_p = 0;
%end;
%end;
run;

%** Calculate maxlines;
data _width1_label_value;
	set _width1_label_value;
/*	maxlines = max(of __vc_line1 - __vc_line&nvar.);*/
    maxlines = .;
	if __m_source = "the width of label" then call symput("_vline_h",strip(put(maxlines,best.)));
run;

%** merge to __report_in;
data __report_in;
	merge __report_in
	_width1_label_value(where=(__m_source = "the width of value")
	keep = __m_source __n_for_report maxlines
	%if %length(%nrbquote(&computeline.))>0 %then __comp_lines;
	);
	by __n_for_report;
run;


%************************************** Calculate Merge Header Width and Use lines ********************************;
%** if exist merge header;

%let _vline_m_header = 0;

%if &maxmergeheader. >= 4 %then %do;

	data _mergeheader_width;
		set _mergeheader2;
		length Page $100.;
		retain Page;
		%do i = 1 %to &nvar.;
			if ^missing("&&Page&i..") and _N_ = &i. then Page = "&&Page&i..,&i.";
		%end;
	run;

	data _mergeheader_width;
		set _mergeheader_width end=final;
		%** Calculate lines of each header;
		%do j=4 %to &maxmergeheader.; %** Multiple header (header4, header5, header6.... );
/*			length _vc_clen_save&j. $5000.;*/
			%** ;
			header&j. = tranwrd(header&j.,"$"," "||byte(27));
			%** One RTF/unicode code about equal to two "yy" width;
			header&j. = prxchange("s/{\\uc(\d+)\\u(\d+)}|&escapechar.{unicode([[:ascii:]]+)}/yy/i",-1,header&j.);
			%** find super/sub/new line code equal to empty;
			header&j. = prxchange("s/({\\super )|({\\sub )|(&escapechar.{super )|(&escapechar.{sub )|(&escapechar.R\/RTF'{\\cf')|(&escapechar.R\/RTF""{\\cf"")//i",-1,header&j.);
			__m_source_b = 1;
/*			%Get_Width(Inpu_Var = header&j. , Save_Width = _vc_clen_save&j. ,__m_source_b = __m_source_b );*/
		%end;%** End of Multiple header (header4, header5... );
	run;

	data _mergeheader_width;
		set _mergeheader_width;
		%do i = 1 %to &nvar.;
			if _N_ = &i. then _width_precent = &&width&i..;
		%end;
	run;
	%do j=4 %to &maxmergeheader.;

		data _mergeheader_width_1;
			set _mergeheader_width;
			by Page header&j. notsorted;
			retain usable_width;
			if first.header&j. then usable_width = _width_precent;
			else usable_width = usable_width + _width_precent;
			if last.header&j. and ^missing(header&j.) then do;
				usable_width = &usable_width. * usable_width / (100 *&Use_Ratio.);%** Usable Width by Each Column;
				__vc_line&j. = 1;
			end;
		run;

		proc sql noprint;
			select max(__vc_line&j.) into: vline_m_header from _mergeheader_width_1;
		quit;

		%let _vline_m_header = &_vline_m_header. + &vline_m_header.;

	%end;

%end;%** if exist merge header;


%****************************************;
%** REPORT ;
%****************************************;

%starttf:

%****************************************;
%** title and footnote ;
%****************************************;
data _null_;
	%if "&_rtffmt."="EN" %then %do;
	pageof = "Page &escapechar.{pageof}";
	%end;
	%else %if "&_rtffmt."="CH" and "&_Encoding"^="UTF-8" %then %do;
	pageof =strip(byte(181)||byte(218))||" &escapechar.{thispage} "||strip(byte(210)||byte(179))
	||" "||strip(byte(185)||byte(178))||" &escapechar.{lastpage} "||strip(byte(210)||byte(179));
	%end;
	%else %if "&_rtffmt."="CH" and "&_Encoding"="UTF-8" %then %do;
	pageof =strip(byte(231)||byte(172)||byte(172))||" &escapechar.{thispage} "||strip(byte(233)||byte(161)||byte(181))
	||" "||strip(byte(229)||byte(133)||byte(177))||" &escapechar.{lastpage} "||strip(byte(233)||byte(161)||byte(181));
	%end;
	call symputx("_pageof",strip(pageof),'L');
run;

	title1 %if %symexist(_sponsor) %then %do; j = l "%nrbquote(&_sponsor.)" %end;
	%if %symexist(_pageof) %then %do; j = r "%nrbquote(&_pageof.)" %end; ;
	title2 %if %symexist(_prjname) %then %do; j = l "%nrbquote(&_prjname.)" %end;
	%if %symexist(_rptfor) %then %do; j = r "%nrbquote(&_rptfor.)" %end; ;

%local _ntitle _vline_t _nfootnote _vline_f;
	%let _ntitle=3; %** 3 title statements before, title1, title2, title3 ;
	%let _vline_t = 3; %** 3 lines of title before ;
	%let _nfootnote=0; %** footnote displayed by compute but not footnote statement, so seq no use ;
	%let _vline_f = 0; %** no footnote before ;

data _title_footnote;
	length cat $10. value0 $32760.;
	if lengthn(strip("%nrbquote(&title.)"))>0 then do;
		cat="Title";
		justify="C"; %** default=center ;
		seq=&_ntitle.;
		value0=strip(tranwrd(tranwrd("%nrbquote(&title.)","$$","$ $"),"$$","$ $"));
		if ^missing(value0) then output;
	end;
	if lengthn(strip("%nrbquote(&Footnote.)"))>0 then do;
		cat="Footnote";
		justify="L"; %** default=left ;
		seq=&_nfootnote.;
		value0=" $"||strip(tranwrd(tranwrd("%nrbquote(&Footnote.)","$$","$ $"),"$$","$ $")); %** add 1 blank line between table and footnote ;
		if ^missing(value0) then output;
	end;
run;
/*data title_footnote1;*/
/*	set _title_footnote;*/
/*run;*/
data _title_footnote;
	set _title_footnote;
	do t_f_i= 1 to (count(value0,"$")+1);
		value=strip(scan(value0,t_f_i,"$"));
		%if "&bodytitle_aux"="1" %then %do;
			%** justify ;
			if index(upcase(value),"\QL ") then do;
			value=strip(tranwrd(value,"\QL ",""));
			value=strip(tranwrd(value,"\ql ",""));
			justify="L";
			end;
			else if index(upcase(value),"\QR ") then do;
			value=strip(tranwrd(value,"\QR ",""));
			value=strip(tranwrd(value,"\qr ",""));
			justify="R";
			end;
			else if index(upcase(value),"\QC ") then do;
			value=strip(tranwrd(value,"\QC ",""));
			value=strip(tranwrd(value,"\qc ",""));
			justify="C";
			end;
		%end;
		call symputx(cats(cat,put(seq+t_f_i,best.)),value,"L");
		call symputx(cats(cat,"just",put(seq+t_f_i,best.)),strip(justify),"L");
		output;
	end;
run;
/*data title_footnote2;*/
/*	set _title_footnote;*/
/*run;*/

%************************************** Calculate Report Text Width and Use lines ********************************;
data _title_footnote;
	set _title_footnote end = final;
	by cat notsorted;
	retain _vline_sum;
	length value_c $32760. /*_vc_clen_save $2000.*/;

	%** One RTF/unicode code about equal to two "yy" width;
	value_c = prxchange("s/{\\uc(\d+)\\u(\d+)}|&escapechar.{unicode([[:ascii:]]+)}/yy/i",-1,value);
	%** find super/sub/new line code equal to empty;
	value_c = prxchange("s/({\\super )|({\\sub )|(&escapechar.{super )|(&escapechar.{sub )|(&escapechar.R\/RTF'{\\cf)|(&escapechar.R\/RTF""{\\cf)|(&escapechar.R\/RTF)//i",-1,value_c);
	if cat="Title" then do;__m_source_b = 1;Get_Line_fs = 10;end;
	else do;__m_source_b = 0;Get_Line_fs = &fs.;end;

	if _vline = 0 then _vline = 1; %** blank line;

	if first.cat then _vline_sum = _vline;
	else _vline_sum = _vline_sum + _vline;

	if last.cat then do;
		if cat="Title" then do;
			call symputx("_vline_t",strip(put(_vline_sum,best.)),"L");
			call symputx("_ntitle",strip(put(seq+t_f_i,best.)),"L");
		end;
		if cat="Footnote" then do;
			call symputx("_vline_f",strip(put(_vline_sum,best.)),"L");
			call symputx("_nfootnote",strip(put(seq+t_f_i,best.)),"L");
		end;
	end;
run;
/*data title_footnote3;*/
/*	set _title_footnote;*/
/*run;*/
%** Output Title;

%if "&bodytitle_aux"="1" %then %do;
title3 " ";
%do i=4 %to &_ntitle. %by 1;
title&i. bold j=&&TitleJust&i.. "&&Title&i.. " ;
%end;
%end;
%else %do;
%if %index(%nrbquote(&pretext.),%str(#byval)) %then %do;
%put ERR%STR(OR:) Title will be display by pretext not use title statement, not supported #byval statement, please change global macro bodytitle_aux equal to 1 or check the parameter pretext!;
%goto exit;
%end;
%do i=4 %to &_ntitle. %by 1;
%** Diplay title by pretext *;
%if &i.=4 %then %let _titletext=%nrbquote(&&Title&i..);
%else %let _titletext=&_titletext.%str(\par )&&Title&i..;
%end;
%end;

%** add 1 blank line between title and table.;
%** No program for this blank line because SAS will output one automatically ;
%let _vline_t = %eval(&_vline_t. + 1);

%** display input datasets and source text with posttext= ;
%if %symexist(_inputdata_) or %symexist(_sourcetxt) %then %do;
%let _vline_f = %eval(&_vline_f. + 1); %** blank line between footnote and source.;
%end;

%if %symexist(_inputdata_) %then %do;
%if %length(%nrbquote(&_inputdata_.)) %then %do;
%let _vline_f = %eval(&_vline_f. + 1);
%let sourcefootnote=&sourcefootnote.%str(\par )%qsysfunc(tranwrd(%nrbquote(&_inputdata_.),\,\\)); %** new line and display inputdatasets;
%end;
%end;

%if %symexist(_sourcetxt) %then %do;
%let _vline_f = %eval(&_vline_f. + 1);
%let sourcefootnote=&sourcefootnote.%str(\par )%qsysfunc(tranwrd(%nrbquote(&_sourcetxt.),\,\\)); %** new line and display source text;
%end;

** Incase no var to report;
%if %length(&varlist.)=0 %then %do;
%goto report;
%end;

%********************************************;
%** get page ;
%********************************************;

%** Determine how to get page ;

%if %symexist(_RptType)=0 %then %let _RptType=;
%if %length(&_RptType.)>0 and %upcase("&_RptType.")^="RTF" and %upcase("&_RptType.")^="NONE" and %upcase("&_RptType.")^="DATA" %then %do;
ERR%STR()OR: Macro stop beacuse RPTTYPE dose not specified to be RTF, NONE or DATA!!!;
%goto exit;
%end;

%if &__report_in_nobs.=0 %then %let getpage=Do not get page beacuse of no record in the input dataset;
%else %if &_paging.=0 %then %let getpage=Do not get page beacuse of report no paging;
%else %if %m_var_exist(__report_in,page_seq)>0 %then %let getpage=By variable(PAGE_SEQ) from input dataset;
%else %if %length(&datarows.)>0 and &__report_in_nobs.>0 %then %let getpage=Specified by macro parameter, DATAROWS;
%else %let getpage=Calculated by macro automatically;

%if "&getpage."="Specified by macro parameter, DATAROWS" or "&getpage."="Calculated by macro automatically" %then %do;
%** Calculate the number of rows that each page can hold;
data __m_hold_lines;
	datarows = input("&datarows.",best.);
	usable_height = &usable_height.;
	lines_Sponsor = &lines_Sponsor. + 1 %if "&bodytitle_aux." = "1" %then %do; + 1 %end;; %** Sponsor lines;
	lines_title = &_vline_t. + 1; %** Title lines;
	lines_footnote= &_vline_f.; %** footnote lines;
	lines_header = &_vline_h.; %** Header lines;
	lines_m_header= &_vline_m_header.; %** Merge Header lines;
	height_p = (%upcase("&_rtffmt.") = "CH")*1.3 + (%upcase("&_rtffmt.") = "EN")*1.2;
	hold_height = usable_height - ( lines_footnote + lines_header + lines_m_header)*height_p*&fs. - (lines_Sponsor + lines_title)*height_p*10;
	call symputx("hold_height",strip(put(hold_height,best.)),'l');
	call symputx("Cdatarows",hold_height/(&fs. * height_p + 0.5 * (&PaddingBottom. + &PaddingTop.)),'l');
	if ^missing(datarows) then do;
	data_height = (&fs. * height_p + 0.5 * (&PaddingBottom. + &PaddingTop.)) * datarows;
	call symput("hold_height",strip(put(data_height,best.)));
	end;
run;

%** Get page;
data __report_in;
	set __report_in;

	%** Whole page can use height;
	hold_height = &hold_height.;
	%** Each line use height;
	height_p = (%upcase("&_rtffmt.") = "CH")*1.3 + (%upcase("&_rtffmt.") = "EN")*1.2;
	if "&Order_Y_N." = "Y" then height_p = 1.3;
	_vc_height = (&fs. * height_p + 0.5 * (&PaddingBottom. + &PaddingTop.)) * maxlines;
	_comp_height = &fs. * height_p + 0.5 * 10;
	_skip_height = 10 * 1.3 ;
	%** sum height;
	retain page_seq 1 lines_seq 0;
	lines_seq = lines_seq + _vc_height ;

%** Calculate with by, breakvar, computeline or skip;
%if %length(&by.)>0 or %length(&Breakvars.)>0 or %length(%nrbquote(&skip.))>0 or %length(%nrbquote(&computeline.))>0 %then %do;
by
%if %length(%nrbquote(&by.))>0 %then &by.;
%if %length(%nrbquote(&Breakvars.))>0 %then _breakvar_group;
%if %length(%nrbquote(&computeline.))>0 %then ___compute_;
%if %length(%nrbquote(&skip.))>0 %then &skip.;
notsorted;
%if %length(%nrbquote(&by.))>0 %then %do;
if first.&lastbyvar. and _n_ ~= 1 then do;
lines_seq = _vc_height ;
page_seq + 1;
%if %length(%nrbquote(&Breakvars.))>0 %then %do;
_Breakvar_lines_seq = _vc_height;
_Breakvar_page_seq + 1;
%end;
end;
%end;

%if %length(%nrbquote(&Breakvars.))>0 %then %do;
retain _Breakvar_lines_seq _Breakvar_page_seq 0;
if first._breakvar_group then do;
_Breakvar_lines_seq = _vc_height;
_Breakvar_page_seq + 1;
end;
else do;
_Breakvar_lines_seq = _Breakvar_lines_seq + _vc_height;
end;
%end;
%if %length(%nrbquote(&computeline.))>0 %then %do;
if first.___compute_ then do;
lines_seq = lines_seq + _comp_height * __comp_lines;
_comp_add_y = "Y";
%if %length(%nrbquote(&Breakvars.))>0 %then _Breakvar_lines_seq = _Breakvar_lines_seq + _comp_height * __comp_lines;;
end;
%end;
%if %length(%nrbquote(&skip.))>0 %then %do;
if first.&skip. then do;
lines_seq = lines_seq + _skip_height;
_skip_add_y = "Y";
%if %length(%nrbquote(&Breakvars.))>0 %then _Breakvar_lines_seq = _Breakvar_lines_seq + _skip_height;;
end;
%end;
%end;

%** When the accumulation reaches the upper limit, page change and re accumulate;
	array lines_seqn(*) lines_seq %if %length(%nrbquote(&Breakvars.))>0 %then _Breakvar_lines_seq;;
	array page_seqn(*) page_seq %if %length(%nrbquote(&Breakvars.))>0 %then _Breakvar_page_seq;;
	do lines_seqn_i = 1 to dim(lines_seqn);

		if input(put(lines_seqn(lines_seqn_i),best.),best.) > input(put(hold_height,best.),best.) then do;
			lines_seqn(lines_seqn_i) = _vc_height;
			page_seqn(lines_seqn_i) + 1;
			%if %length(%nrbquote(&computeline.))>0 %then %do;
			lines_seqn(lines_seqn_i) = lines_seqn(lines_seqn_i) + _comp_height * __comp_lines;;
			_comp_add_y = "Y";
			%end;
			%if %length(%nrbquote(&skip.))>0 %then %do;
			lines_seqn(lines_seqn_i) = lines_seqn(lines_seqn_i) + _skip_height;;
			_skip_add_y = "Y";
			%end;
		end;
	end;
	%if %length(%nrbquote(&Breakvars.))=0 %then %do;
		if _vc_height > hold_height * 1.1 then put "WARN%str()ING: _N_ = " _N_ "is too long and there is a risk of cross page, please adjust it! If there is no problem, Please ignore.";
	%end;
run;
%if %length(%nrbquote(&Breakvars.))>0 %then %do;
data _null_;
SqlBy = "&by.";
if ^missing(SqlBy) then call symput("SqlBy",strip(tranwrd(compbl(SqlBy)," ",","))||",");
else call symput("SqlBy","");
run;

proc sql;
create table __report_in_braek as
select distinct &SqlBy. _breakvar_group,_Breakvar_page_seq,max(_Breakvar_lines_seq) as _Breakvar_lines_seq,hold_height
from __report_in
group by &SqlBy. _breakvar_group,_Breakvar_page_seq
;
quit;

data __report_in_braek;
set __report_in_braek;
retain _Breakvar_page_sum 1 _Breakvar_lines_sum 0;
_Breakvar_lines_sum = _Breakvar_lines_sum + _Breakvar_lines_seq;
%if %length(&by.) > 0 %then %do;
by &by.;
if first.&lastbyvar. and _n_~=1 then do;
_Breakvar_page_sum + 1;
_Breakvar_lines_sum = _Breakvar_lines_seq;
end;
%end;
if _Breakvar_lines_sum > hold_height then do;
	_Breakvar_page_sum + 1;
	_Breakvar_lines_sum = _Breakvar_lines_seq;
end;
run;

data __report_in;
	merge __report_in __report_in_braek(keep=_Breakvar_page_seq _Breakvar_page_sum);
	by _Breakvar_page_seq;
	page_seq = _Breakvar_page_sum;
run;

%end;

%end;%** end of get page ;

%if %length(&getpage.)>0 %then %do;
%put %str(===================================================================================);
%put Get Page: &getpage.;
%do i = 1 %to &nvar.;
%put Cellwidth percent of <&&var&i..>/<&&label&i..> is: &&width&i..;
%end;

%if "&getpage."="Specified by macro parameter, DATAROWS" %then %do;
%put %str(-----------------------------------------------------------------------------------);
%put Datarows for each page has been specified by macro parameter: DATAROWS = &datarows.;
%end;

%else %if "&getpage."="Calculated by macro automatically" %then %do;
%put %str(-----------------------------------------------------------------------------------);
%put Lines of title is: &_vline_t. (including blank lines);
%put Lines of header is: &_vline_h.;
%put Lines of footnote is: &_vline_f. (including blank lines);
%put %str(-----------------------------------------------------------------------------------);
%put Calculated datarows for each page is: &Cdatarows.;
%end;
%put %str(===================================================================================);
%end;

%*****************************************;
%** proc report ;
%*****************************************;
%report:

	%if %symexist(escapechar)=0 %then %let escapechar=~;
	ods escapechar="&escapechar.";

	ods html close;
	ods listing close;

	%if &__report_in_nobs.>0 and %length(&varlist.)=0 %then %do;
		%put ERR%STR()OR: There are some records in input dataset, but you did not specify varlist=. Stop macro!!!;
		%goto exit;
	%end;
	%if &__report_in_nobs.=0 or %length(&varlist.)=0 %then %do;
		%** report blank page if no record or no varlist;

			%if %length(&Norecord.)=0 %then %do;
				%if %length(&Title.)>0 %then %do;
					%local titlebodyindex1 titlebodyindex2;
					%let titlebodyindex1 = %eval(%index(%nrbquote(&Title.),:)+1);
					%let titlebodyindex2 = %eval( %length(%nrbquote(%scan(%nrbquote(&Title.),1,$)))-%index(%nrbquote(&Title.),:) );
					%let Norecord=No record was reported.;
				%end;
				%else %do;
					%let Norecord=No Data Available;
				%end;
			%end;

		data _nodata_;
			length _nodata_ $2000.;
			_nodata_="&Norecord.";
			call symputx("lengthofnocord",strip(put(length(_nodata_)+10,best.)),"L");
		run;
		data __report_in; set %if %sysfunc(exist(__report_in)) %then __report_in; _nodata_; run;
	%end;

	%** Modify dataset before report ;
	&CodeBeforeReport.;

	%** Add Page in Footnote;
	%if &PageInFootnote.= 1 %then %do;
		%if &__report_in_nobs. > 0 %then %do;
			data _null_;
			set __report_in end=last;
			if last then call symput("total_page",strip(put(page_seq,best.)));
			run;
			%let each_page = #byval(page_seq);
		%end;
		%else %if &__report_in_nobs. = 0 %then %do;
			%let each_page = 1;
			%let total_page = 1;
		%end;

		data _null_;
		pageoffootnote =strip(byte(181)||byte(218))||" &each_page. "||strip(byte(210)||byte(179))
		||" "||strip(byte(185)||byte(178))||" &total_page. "||strip(byte(210)||byte(179));
		call symputx("_pageoffootnote",strip(pageoffootnote),'L');
		run;

		footnote j = r "&_pageoffootnote.";
	%end;

	%rtftemp;

	**get title and footnote information;
	data _null__program_name;
		set %if %index(%UPCASE(&_role), QC) %then 		qctable._title_footnote;
			%else table._title_footnote;;
		where lowcase(ProgramName)=lowcase("&_program_name");
		if ^missing(Population) then title_text=strip(TitleNo)||" "||cats(MainTitle,"(",Population,")");
		else title_text=strip(TitleNo)||" "||cats(MainTitle);
		footnote_text=strip(FootNote);
		       title_text = tranwrd(title_text, "%", "\uc0\u37");
		       title_text = tranwrd(title_text, "&", "\uc0\u38");
		call symputx("title_text",title_text);
		call symputx("footnote_text",footnote_text);
		call symputx("SAS_prog_name",SAS_prog_name);
	run;

	footnote j=l "PROGRAM: &SAS_prog_name..sas";

	%if %nobs(_null__program_name) = 0 %then %do;
		%put ERR%str()OR: &_program_name not in program_name of table._title_footnote , Please check!;
		%goto exit;
	%END;
	%if "&_Encoding"="UTF-8" %then %do;
		data _null_;
		       length _titletext _titletext_out   $32760 unicode1  $200 _char1  $20;
		       retain _titletext_out ;
		       _titletext="&title_text";
		       do i = 1 to klength(_titletext);
		              _char1 = ksubstr(_titletext, i, 1);
		              if lengthn(_char1)>1 then unicode1 = cats("\uc0\u", compress(unicodec(_char1,"ncr"),,"kd"), "\uc1\u32");
		              else if lengthn(_char1)=0 then unicode1 = "\uc1\u32";
		              else unicode1 = _char1;
		              _titletext_out = cats(_titletext_out, unicode1);
		       end;
		       %** \uc1\u32 represent blank;
		       %** each multi-byte character need to transcode to utf8: "\uc0\uXXXXX ";
		       %** add \uc1 to avoid semicolon appear in column header;
		       _titletext_out = tranwrd(cats(_titletext_out, "\uc1"), "\uc1\u32", " ");
		       %** translate % & to unicode;
		       _titletext_out = tranwrd(_titletext_out, "%", "\uc0\u37");
		       _titletext_out = tranwrd(_titletext_out, "&", "\uc0\u38");
		       call symputx("title_text", _titletext_out);
		run;
		data _null_;
		       length _titletext _titletext_out   $32760 unicode1  $200 _char1  $20;
		       retain _titletext_out ;
		       _titletext="&footnote_text";
		       do i = 1 to klength(_titletext);
		              _char1 = ksubstr(_titletext, i, 1);
		              if lengthn(_char1)>1 then unicode1 = cats("\uc0\u", compress(unicodec(_char1,"ncr"),,"kd"), "\uc1\u32");
		              else if lengthn(_char1)=0 then unicode1 = "\uc1\u32";
		              else unicode1 = _char1;
		              _titletext_out = cats(_titletext_out, unicode1);
		       end;
		       %** \uc1\u32 represent blank;
		       %** each multi-byte character need to transcode to utf8: "\uc0\uXXXXX ";
		       %** add \uc1 to avoid semicolon appear in column header;
		       _titletext_out = tranwrd(cats(_titletext_out, "\uc1"), "\uc1\u32", " ");
		       %** translate % & to unicode;
		       _titletext_out = tranwrd(_titletext_out, "%", "\uc0\u37");
		       _titletext_out = tranwrd(_titletext_out, "&", "\uc0\u38");
		       call symputx("footnote_text", _titletext_out);
		run;
	%end;

	PROC REPORT nowd split = "$" Data = __report_in out = __report_out SPACING=1 %if "&_paging."^="0" %then SPANROWS;
		style(report) = {nobreakspace=off protectspecialchars = off OutputWidth = 100% CellPadding = 0 just=left
		pretext="%nrbquote(&title_text.)"
		%if (&__report_in_nobs = 0 and &FootnoteDisplay = 1) or &__report_in_nobs > 0  %then posttext="%nrbquote(&footnote_text.)"; }

		style(header) = {nobreakspace=off protectspecialchars = off Font_Size = &Fs.pt just=c asis=on PaddingBottom = 0 PaddingTop = 0 PaddingLeft = &PaddingLeft. PaddingRight = &PaddingRight. CellPadding = 0}
		style(column) = {nobreakspace=off protectspecialchars = off Font_Size = &Fs.pt VerticalAlign = &VerticalAlign. PaddingBottom = &PaddingBottom. PaddingTop = &PaddingTop. PaddingLeft = &PaddingLeft. PaddingRight = &PaddingRight. CellPadding = 0 };

		%if &__report_in_nobs. > 0 and &PageInFootnote.= 1 %then %do; by page_seq ; %end;
		%if %length(&by.)>0 %then %do;
			by &By. %if &__report_in_nobs. > 0 and &PageInFootnote.= 1 %then %do; page_seq %end;;
		%end;

		%****************;
		%** define columns ;
		%****************;

		column (%if &__report_in_nobs.>0 %then %do;
			page_seq maxlines
			%if %length(%nrbquote(&computeline.))>0 %then ___compute_ _compute_ ;
				%sysfunc(strip(%nrbquote(&column.)))
			%end;
			%else %do;
				_nodata_
				%if %length(&varlist.)>0 and "&_displayheader."="1" %then %do;
					%sysfunc(strip(%nrbquote(&column.)))
				%end;
			%end;
			);

		%** define page_seq which break page by ;
		%if &__report_in_nobs.>0 %then %do;
			define page_seq / order noprint;
			define maxlines / noprint;
		%end;

		%** define all columns ;
		%if &__report_in_nobs.>0 or (&__report_in_nobs.=0 and %length(&varlist.)>0 and "&_displayheader."="1") %then %do;
			%if %index(&column.,_blankcol) %then define _blankcol /display " " style(column)={cellwidth=0.2%};;
			%do i=1 %to &nvar.;
				%if "&&order&i.."="order" %then %do;
				define __&&var&i.. / noprint %if &__report_in_nobs.>0 %then order order=data ; ;
				%end;
				define &&var&i.. / display missing "&&label&i.." %if &__report_in_nobs.>0 %then &&order&i.. order=data ;
				%if "&headerjusteqcolumn."="1" %then %do;
					style(header)={JUST=&&align&i..}
				%end;
				%if %upcase("&&ID&i..") = "ID" %then %do;
				id
				%end;
				%if %upcase("&&PAGE&i..") = "PAGE" %then %do;
				PAGE
				%end;
				style(column)={ nobreakspace=off cellwidth= %sysevalf(&&width&i.. * &Tabwp./100)% JUST=&&align&i. 
					%if %m_var_type(__report_in,&&var&i..)=C %then asis=on ; &&asis&i.. };
			%end;
		%end;

		%****************;
		%** compute line ;
		%****************;
		%if %length(%nrbquote(&compute_line.))>0 %then %do;
			%let compute_line_p1=%scan(&compute_line,1,|);
			%let compute_line_p2=%scan(&compute_line,2,|);
			compute  &compute_line_p1;
			if &compute_line_p1="&compute_line_p2" then do;
				call define(_ROW_,"style","style={bordertopwidth=0.5pt bordertopcolor=black}");
			end;
			endcomp;
		%end;
		%if &__report_in_nobs.>0 %then %do;
			%if %length(%nrbquote(&computeline.))>0 %then %do;
				define ___compute_ / order missing order=data noprint;
				define _compute_ / order missing order=data noprint;
				%if "&computetype."="TEXT" %then %do;
					compute before _compute_
					/style=[ nobreakspace=off PaddingTop=10 just=l fontweight=bold backgroundcolor=white BORDERBOTTOMWIDTH=1pt FONTSIZE=&Fs.pt &Computestyle.];
					line _compute_ $1000.;
					endcomp;
				%end;
				%else %do;
					compute before _compute_
					/style=[BORDERBOTTOMCOLOR=white backgroundcolor=white &Computestyle.];
					line " ";
					endcomp;
				%end;

				%** add a line before compute text ;
				%if %length(&skip.)>0 and %upcase("&skip.")="_COMPUTE_" %then %do;
					compute after _compute_;
					line " ";
					endcomp;
				%end;
			%end;

			%** skip ;
			%if %length(&skip.)>0 and %upcase("&skip.")^="_COMPUTE_" %then %do;
				compute after &skip. ;
				line " ";
				endcomp;
			%end;
			%** Break;
			break after page_seq / page;
		%end;
		%else %if &__report_in_nobs.=0 %then %do;
			%** no record in input dataset ;
			define _nodata_ /order order= data  noprint;
			compute after _nodata_ 
			%if %length(&varlist.)=0 or "&_displayheader."="0" %then %do;
				/style={nobreakspace=off bordertopcolor=white BORDERBOTTOMCOLOR=white borderleftcolor=white borderrightcolor=white just=left}
			%end;
			%else %do;
				/style={ just=left}
			%end;
			;
			line _nodata_ $&lengthofnocord..;
			endcomp;
		%end;

	RUN;

	ods rtf close;
	ods listing;

	%** save dataset for QC ;
	%** rename the report variables for QC if generating listing ;
	data __report_out(keep = &by. _break_
		%if &__report_in_nobs.>0 %then %do;
			page_seq maxlines
			%if %length(%nrbquote(&computeline.))>0 %then _compute_ ;
			%if "&RenameForCompare."="1" %then %do; _rptvar: %end;
			%else %do; %do i=1 %to &nvar.; &&var&i.. %end; %end;
		%end;
		%if &__report_in_nobs.=0 and %length(&varlist.)>0 and "&_displayheader."="1" %then %do;
			%if "&RenameForCompare."="1" %then %do; _rptvar: %end;
			%else %do; %do i=1 %to &nvar.; &&var&i.. %end; %end;
		%end;
	);
	set __report_out;
	where missing(_break_);
	%if "&RenameForCompare."="1" %then %do;

		%** convert to character variable ;
		%if &__report_in_nobs.>0 or (%length(&varlist.)>0 and "&_displayheader."="1") %then %do;
			%do i=1 %to &nvar.;
				%if %m_var_type(__report_out,&&var&i..)=N %then %do;
					_rptvar&i.=strip(vvalue(&&var&i..));
				%end;
				%else %do;
					&&var&i..=compbl(tranwrd(strip(&&var&i..),"$"," "));
				%end;
			%end;

			label
				%do i=1 %to &nvar.;
					%if %m_var_type(__report_out,&&var&i..)=C %then %do;
						&&var&i..=" "
					%end;
				%end;
			;
			rename
				%do i=1 %to &nvar.;
					%if %m_var_type(__report_out,&&var&i..)=C %then %do;
						&&var&i..=_rptvar&i.
					%end;
				%end;
			;
		%end;

		format _all_ ;
	%end;

run;

%EndReport:
%** save report dataset for QC;
        data 
		%if %index(%UPCASE(&_role), QC) %then 		qcTable.&OutputFileName. ;
		%else 	Table.&OutputFileName. ;
		;
			retain Title Footnote  %do i=1 %to &nvar.; Compheader&i. %end;;
            set __report_out;
			Title="%nrbquote(&title_text) ";
			Footnote="%nrbquote(&footnote_text)";
			%do i=1 %to &nvar.; Compheader&i.="&&compheader&i.";%end;
			drop 		%if &__report_in_nobs.>0 %then %do;page_seq maxlines %end;_break_;
        run;

title ;
footnote ;
%let title=;
%let footnote=;
%if &Debug<1 %then %do;
	proc datasets nolist nodetails NoWarn lib=work;
		delete _mergeheader: _varlist1 _varlist2
		_width1 _width1_label _width1_label_value _width1_value _width1_max _width1_precent
		_useble_pagersize __m_hold_lines _sponsor_inf
		_none _title_footnote _nodata_
		__report_in___pre __report_in_break __report_in __report_out /memtype=data;

	quit;
%end;


	%exit:
%mend;
