/*************************************************************************************************
File name: shifttable-v1-0.sas

Study:

SAS version: 9.4

Purpose:   Create shift table

Macros called:  %nobs, %m_var_exist, %m_var_type

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 13SEP2023

Date completed: 13SEP2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 13SEP2023 Hao.Guo create
1.1 11DEC2023 Hao.Guo add DNMTRTYPE=0 for no percent,lowcase (group groupn by)
*********************************** Prepared by Highthinkmed ************************************/
%macro shifttable(Dataset= 
,Casevar= USUBJID

,Popn=
,Group=
,Groupn= 

,SubGrp= 
,SubGrpn= 
,FullSubGrp=

,Cond= 
,Var=
,Varn=
,Fullvar=

,DNMTRTYPE=
,MissingDescribe=
,By= 
,prec= 1
,Listvars=
,Endline= 1
,Debug= 0
,Outds=
) / store;

	ods exclude all;
    %put Running Macro (&SYSMACRONAME. V1.0);

**----------------------------------------------------------------------------
| Step 1: pre-proccessing 
|     a): Define some macro variables.
|     b): Assign default values for some paramaters.
|     c): Check required parameters.
|     d): Delete the dataset will be used.
-----------------------------------------------------------------------------;

    ** Delete the dataset will be used *;
    proc datasets nolist nodetails NoWarn lib=work;
        delete ___: _table _table_rtf/memtype=data;
    quit;

    ** Define some macro variables *;
    %local i j k loop1 loop2 nby ngroup nSubGrp Sqlby Lstbyvar nFullgroup nFullgroup2 nFillMissingBy     
           _pop_cond _pop_data Sortgrpvar CustomSortGrpvar SortSubgrpvar CustomSortSubgrpvar
           Listvarname nListvars Computevar Computevarlist 
           _DonotdisplayGroup _validvarname _mcompilenote 
           _err_or_message_ byvarlist 
		   Preblank Dispopn Outtotal Totname Denopopn Dnmtrtype
		 SUBGRPTOTAL  FOLLOWDATA  FOLLOWDATA  VARTOTAL  FILLMISSING  FullGroup
		 MISSINGDESCRIBE TOTSUBGRPNAME  TOTVARNAME  REPORTBY LTOPLEN LTOPVAR Sqlby_notrt_cn Sqlby_notrt_c
          ;
    %if %length(&group.)>0          %then %let    group=%lowcase (&group);
    %if %length(&groupn.)>0          %then %let    groupn=%lowcase (&groupn);
    %if %length(&by.)>0          	%then %let    by=%lowcase (&by);

    %let _err_or_message_=0;
    %let _validvarname=%sysfunc(getoption(validvarname));
    %let _mcompilenote=%sysfunc(getoption(mcompilenote));
    options mcompilenote=all validvarname=V7;
    %if %symexist(_Encoding)=0 %then %let _Encoding=%upcase(&SYSENCODING);

    ** Assign default values for some paramaters *;
    %if %length(&Group.)=0 %then %do;
        %let Group=_NOGROUP_;
        %let _DonotdisplayGroup=1;
    %end;
    %if %length(&Popn.)=0 %then %do;
        %let Denopopn=0;
    %end;
    %if %length(&OutDs.)=0          %then %let    OutDs=_table_rtf;
    %if %length(&Casevar.)=0 %then %let Casevar=USUBJID;
    %if %length(&Outtotal.)=0 %then %let Outtotal=0;
    %if %length(&Denopopn.)=0 %then %let Denopopn=1;
    %if %length(&SubGrpTotal.)=0 %then %let SubGrpTotal=1;
     %if %length(&LTOPLEN.)=0 %then %let LTOPLEN=500;
   %if %length(&FollowData.)=0 %then %let FollowData=0;
    %if "&FollowData."="1" %then %do;
        %let Fullvar=;
        %let FullSubGrp=;
    %end;
    %else %do;
        %if %length(&Fullvar.)=0 and %length(&FullSubGrp.)>0 %then %let Fullvar=&FullSubGrp.;
        %if %length(&FullSubGrp.)=0 and %length(&Fullvar.)>0 %then %let FullSubGrp=&Fullvar.;
    %end;
    %if %length(&Preblank.)=0 %then %let Preblank=%str(  );
    %if %length(&VarTotal.)=0 %then %let VarTotal=1;
	*** Dnmtrtype=0 : no percent
	* Dnmtrtype=1 : no percent
	* Dnmtrtype=2 : column + line =totol as deno  for calculating percent
	* Dnmtrtype=3 : Heade as deno  for calculating percent
	* Dnmtrtype=4 : line as deno  for calculating percent;
    %if %length(&Dnmtrtype.)=0 %then %let Dnmtrtype=3;
    %if %length(&FillMissing.)=0 %then %let FillMissing=1;
    %if "&Dnmtrtype."="3" %then %do;
        %if %length(&Group.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) If parameter Dnmtrtype eq to 3 than parameter Group should not be null!;
            %let _err_or_message_=1;
        %end;
    %end;
    %if "&Denopopn."="0" %then %do;
        %if "&Dnmtrtype."="3" %then %do;
            %let Dnmtrtype=2;
            %put WAR%STR(NING): (&SYSMACRONAME.) If paramater Denopopn eq to 0 or paramater Popn is null then paramater Dnmtrtype can not be eq to 3, 2 will be insteaded of, change the paramater remove the war%nrstr()ning! ;
        %end;
    %end;
    %if %length(&Dispopn.)=0 %then %let Dispopn=1;
    %if %length(&Totname.)=0 %then %do;
        %if %upcase("&_Rtffmt.")="EN" %then %do;
            %let Totname=Total;
        %end;
        %else %if %upcase("&_Rtffmt.")="CH" %then %do;
            data _null_;
                %if "&_Encoding"="UTF-8" %then %do; Totname=byte(229)||byte(144)||byte(136)||byte(232)||byte(174)||byte(161); %end;
                %else %do; Totname=byte(186)||byte(207)||byte(188)||byte(198); %end;
                call symputx("Totname",strip(Totname),"l");
            run;
        %end;
    %end;
    %if %length(&Missingdescribe.)=0 %then %do;
            data _null_;
                %if "&_Encoding"="UTF-8" %then %do; Missingdescribe=byte(230)||byte(156)||byte(170)||byte(230)||byte(159)||byte(165); %end;
                %else %do; Missingdescribe=byte(206)||byte(180)||byte(178)||byte(233); %end;
                call symputx("Missingdescribe",strip(Missingdescribe),"l");
            run;
    %end;
    %if %length(&Totsubgrpname.)=0 %then %let totsubgrpname=%str(&totname.);
    %if %length(&totvarname.)=0 %then %let totvarname=%str(&totname.);
    %if %length(&Endline.)=0 %then %let Endline=1;
    %if %length(&Debug.)=0 %then %let Debug=0;
    %if %length(&prec.)=0 %then %let prec=1;
    %let _precblank=0.%sysfunc(repeat(0,%eval(&prec.-1)));

    ** Check required parameters *;
    %if %length(&Dataset.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Parameter &Dataset. should not be null, please check!. ;
        %let _err_or_message_=1;
    %end;
    %if %sysfunc(exist(&Dataset.))=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) The dataset &Dataset. do not exist, please check the parameter Dataset!;
        %let _err_or_message_=1;
    %end;
    %if %length(&Subgrp.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Parameter subgrp should not be null, please check!. ;
        %let _err_or_message_=1;
    %end;    
    %if %length(&Var.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Parameter var should not be null, please check!. ;
        %let _err_or_message_=1;
    %end;
    %if "%upcase(&Subgrp.)"="%upcase(&Var.)" %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Parameter subgrp and var should not be eq, please check!. ;
        %let _err_or_message_=1;
    %end;
    %if %length(&Popn.)>0 %then %do;
        %let _pop_cond=%qscan(&Popn.,2,|);
        %let _pop_data=%qscan(&Popn.,1,|);
    %end;
    %else %do;
        %let _pop_cond=&Cond.;
        %let _pop_data=&Dataset.;
    %end;
    %if %m_var_exist(inds=&_pop_data.,varname=&Casevar.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Casevar. not in dataset &_pop_data., please check!;
        %let _err_or_message_=1;
    %end;
    %if %m_var_exist(inds=&Dataset.,varname=&Casevar.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Casevar. not in dataset &Dataset., please check!;
        %let _err_or_message_=1;
    %end;
    %if %length(&Subgrp.)>0 %then %do;
        %if %m_var_exist(inds=&Dataset.,varname=&Subgrp.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Subgrp. not in dataset &Dataset., please check!;
            %let _err_or_message_=1;
        %end;
        %if %m_var_type(&DataSet. ,&SubGrp.)=N %then %do;
            %put  ER%STR(ROR): (&SYSMACRONAME.) The variable &SubGrp. variable should be character, please check!;
            %let _err_or_message_=1;
        %end;
    %end;
    %if %length(&Var.)>0 %then %do;
        %if %m_var_exist(inds=&Dataset.,varname=&Var.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Var. not in dataset &Dataset., please check!;
            %let _err_or_message_=1;
        %end;
        %if %m_var_type(&DataSet. ,&Var.)=N %then %do;
            %put  ER%STR(ROR): (&SYSMACRONAME.) The variable &Var. variable should be character, please check!;
            %let _err_or_message_=1;
        %end;
    %end;
    %if "&_DonotdisplayGroup."^="1" %then %do;
        %if %length(&Group.)>0 %then %do;
            %if %m_var_exist(inds=&Dataset.,varname=&Group.)=0 %then %do;
                %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Group. not in dataset &Dataset., please check!;
                %let _err_or_message_=1;
            %end;
        %end;
    %end;
    %if %length(&Subgrpn.)>0 %then %do;
        %if %m_var_exist(inds=&Dataset.,varname=&Subgrpn.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Subgrpn. not in dataset &Dataset., please check!;
            %let _err_or_message_=1;
        %end;
    %end;
    %if %length(&Varn.)>0 %then %do;
        %if %m_var_exist(inds=&Dataset.,varname=&Varn.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Varn. not in dataset &Dataset., please check!;
            %let _err_or_message_=1;
        %end;
    %end;
    %if "&_DonotdisplayGroup."^="1" %then %do;
        %if %length(&Groupn.)>0 %then %do;
            %if %m_var_exist(inds=&Dataset.,varname=&Groupn.)=0 %then %do;
                %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Groupn. not in dataset &Dataset., please check!;
                %let _err_or_message_=1;
            %end;
        %end;
    %end;

**--------------------------------------------
 | Step 2: pre-proccessing input paramaters
 ---------------------------------------------;
   **----------------------------------------------------------------------------
    | computeline    
    | create macro variables:
    | Computevar&i.: each computer variable
    | Computevarlist: computer variable list
    -----------------------------------------------------------------------------;

   **----------------------------------------------------------------------------
    | Listvars    
    | create macro variables:
    | listvar&i.: each list variable name/label/width
    | Listvarname&i.: each list variable name
    | Listvarname: list variables name list
    | nListvars: number of list variables
    -----------------------------------------------------------------------------;    
    %let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(%|),%nrbquote(*$*)));
    %let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(//),%nrbquote(/ /)));
    %let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(//),%nrbquote(/ /)));
    %let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(/\),%nrbquote(/ \)));
    %let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(\\),%nrbquote(\ \)));

    %let i = 1;
    %let nlistvars=0;
    %if %length(&Listvars.)>0 %then %do;
        %do %while(%qscan(&Listvars.,&i.,|) ^= %str( ));
            %local listvar&i. Listvarname&i.;
            %let listvar&i. = %sysfunc(scan(&Listvars.,&i.,|));
            %let Listvarname&i.  = %sysfunc(scan(&&listvar&i..,1,/));
            %if %length(&Listvarname.) = 0 %then %do;
                %let Listvarname = %qcmpres(&&Listvarname&i..);
                %if %m_var_exist(&DataSet.,&Listvarname.)=0 %then %do;
                    %put  ER%STR(ROR): (&SYSMACRONAME.) The variable &Listvarname. is not in the dataset, please check!;
                    %let _err_or_message_=1;
                %end;
                %if %length(&Reportby.)>0 %then %do;
                    %if %sysfunc(indexw(%upcase(&Reportby.),%upcase(&Listvarname.))) %then %do;
                        %put  ER%STR(ROR): (&SYSMACRONAME.) Variable &Listvarname. both exist in parameter Reportby and Listvars, please check!;
                        %let _err_or_message_=1;
                    %end;
                %end;
                %if %sysfunc(indexw(%upcase(&By.),%upcase(&Listvarname.)))=0 %then %do;
                    %put  ER%STR(ROR): (&SYSMACRONAME.) The list variable &Listvarname. need to be listed in the by parameter!;
                    %let _err_or_message_=1;
                %end;
            %end;
            %else %let Listvarname = &Listvarname. %qcmpres(&&Listvarname&i..); 
            %let i = %eval(&i. + 1);
        %end;
        %let nlistvars = %eval(&i. - 1);
    %end;
    %let Listvars=%sysfunc(tranwrd(%nrbquote(&Listvars.),%nrbquote(*$*),%nrbquote(%|)));

   **----------------------------------------------------------------------------
    | Ltopvar     
    -----------------------------------------------------------------------------;

   **----------------------------------------------------------------------------
    | By var
    | by&i: each by var
    | sqlby: by var list, comma separated, will be used in sql statement
    | lstbyvar: the last variable of the by var list
    | nby: number of by var list
    -----------------------------------------------------------------------------;
    %let nby=0;
    %let nFillMissingBy=0;
    %if %length(&by.)>0 %then %do;
        %let by=%qcmpres(&by.);
        %let sqlby=%sysfunc(tranwrd(&by.,%str( ),%str(,)));

        %let i = 1;
        %let byvarlist=;
        %do %while(%qscan(%nrbquote(%qcmpres(&By.)),&i.,%str( ) ) ne %str( )); 
            %local by&i. bylist&i.;
            %let by&i. = %sysfunc(scan(%nrbquote(&By.),&i.,%str( )));

            %if %m_var_exist(&DataSet.,&&by&i..)=0 %then %do;
                %put  ER%STR(ROR): (&SYSMACRONAME.) By variable &&by&i.. should be in the dataset &DataSet., please check!;
                %let _err_or_message_=1;
            %end;

            %let byvarlist=&byvarlist. &&by&i..; 
            %let bylist&i.=&byvarlist.;
            %let sqlbylist&i.=%sysfunc(tranwrd(&&bylist&i..,%str( ),%str(,)));

            %let i = %eval(&i. + 1);
        %end;
        %let nby=%eval(&i. - 1);
        %let Lstbyvar=%sysfunc(scan(%nrbquote(&By.),-1,%str( )));

        %** For Fullmissing SubGrp;
        proc sql undo_policy=none;
            create table ___Bycycle as
                select distinct &Casevar.,&Sqlby.,&SubGrp.
                    from &Dataset.(where = (^missing(&SubGrp.)))
                    %if %length(&Cond.) > 0 %then where &Cond.;
            ;
        quit;    

        %let sqlbylist = ;
        %** One Case One Baseline One SubGrp by Param(+); 
        %if &nby.>1 %then %do;
            %let j = &nby.;
            %do j= 1 %to &nby.;
                %let sqlbylist = &sqlbylist. ,&&sqlbylist&j..;
                proc sql undo_policy=none;
                    create table ___Bycycle&j.(where = (n>1)) as
                        select distinct &Casevar.,&&sqlbylist&j..,count(distinct &SubGrp.) as n
                            from ___Bycycle
                            group by &Casevar. &sqlbylist.
                    ;
                quit;
                %if %nobs(___Bycycle&j.)=0 %then %do;
                    %let nFillMissingBy=&j.;
                    %let j = %eval(&nby. + 10);%** End Cycle;
                %end;                
            %end;
        %end;
        %else %do;
            %let nFillMissingBy=1;
        %end;
    %end;
    %else %do;
        %let by=_NOBYVARS_;
        %let by1=_NOBYVARS_;
        %let nby=1;
        %let Sqlby=_NOBYVARS_;
        %let Lstbyvar=_NOBYVARS_;
        %let nFillMissingBy=1;
    %end;

    %if "&_err_or_message_."="1" %then %do;
        %goto exit;
    %end;

	**for ___POPN_denopopn nowarning;
	data _null_;
		b=tranwrd("&Sqlby.",",&Group.n","");
		c=tranwrd(b,",&Group.","");
		h=tranwrd(c,"&Group.n ,","");
		call symputx("Sqlby_notrt_cn",strip(h),'L');

		d=tranwrd("&Sqlby.",",&Group.n",",___&Group.n");
		e=tranwrd(d,",&Group.","");
		f=tranwrd(e,",___&Group.n",",&Group.n");
		call symputx("Sqlby_notrt_c",strip(f),'L');

		g=tranwrd("&Sqlby.",",&Group.",",b.&Group");
		call symputx("Sqlby_add_b",strip(g),'L');
	run;

    **--------------------------------------------------------------------------------
     | Step 3: Get group for header
     |     a): parameter popN and group should be filled, the parameter groupn is the 
     |         sorting variable, and if it is not filled in, the group variable is used to sort.
     |     b): The default output data set popn has a group list. When the fullgroup parameter is not 
     |         used, otherwise the group list will be output according to the fullgroup parameter,
     |         and groupn parameter will not work.
     ---------------------------------------------------------------------------------;
    ** Recreate a numeric group variable to sort *;
    %if %length(&Groupn.)>0 %then %let Sortgrpvar=&Groupn.; 
    %else %let Sortgrpvar=&Group.;
    %let CustomSortGrpvar=__Sortgrpvar;

    %if "&_DonotdisplayGroup."^="1" %then %do;
        %if %m_var_exist(inds=&_pop_data.,varname=&Sortgrpvar.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Sortgrpvar. not in dataset &_pop_data., please check!;
            %goto exit;
        %end;
    %end;

    data ___popn;
        set &_pop_data.;
        %if %length(&_pop_cond.) > 0 %then where %unquote(&_pop_cond.); ;
        %if "&_DonotdisplayGroup."="1" %then %do;
            &Group.="_NOGROUP_";
        %end;
        totflag=0;
    run;

    %if &outtotal.>0 %then %do;
        %let nFullgroup2=0;
        %if %length(&Fullgroup.)>0 %then %do;
            %let nFullgroup2=%sysfunc(count(&Fullgroup.,|));
        %end;
        %else %do;
            proc sql noprint;
                select distinct count(distinct &Group.) into: nFullgroup2 from ___popn;
            quit;
        %end;

        %if &nFullgroup2.>0 %then %do;
            data ___popn;
                length &casevar. $200.;
                set ___popn;
                &casevar.=cats(&casevar.,&Group.);
                output;
                totflag = 1;
                &Group. = "&Totname.";
                &casevar.=cats(&casevar.,&Group.);
                output;
            run;        
        %end;
        %else %do;
            %let outtotal=0;
        %end;
    %end;

    %if %nobs(___popn)=0 and %length(&Fullgroup.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) No record in the dataset &Popn., please check!, or you can fill the paramater Fullgroup!;
        %goto exit;
    %end;

    proc sort data = ___popn; by totflag &Sortgrpvar.; run;
    data ___popn;
        set ___popn;
        by totflag &Sortgrpvar. ;
        retain &CustomSortGrpvar. 0;
        if first.&Sortgrpvar. then &CustomSortGrpvar.=&CustomSortGrpvar.+1;
    run;

    proc sql undo_policy=none;
        create table ___Fullgroup as
            select distinct &CustomSortGrpvar.,&Group.
                from ___popn
        ;
    quit;

    ** Fullgroup(Need to list which should categories will be subject to ins data set) *;
    %if %length(&Fullgroup.)>0 %then %do;
        %if &outtotal.>0 %then %let Fullgroup=&Fullgroup.|&totname.;
        proc datasets nolist nodetails NoWarn lib=work;
            delete ___Fullgroup /memtype=data;
        quit;
        %let i = 1;
        %do %while(%qscan(&fullgroup.,&i.,|) ^= %str( ));
            %local Fullgroup&i.;
            %let Fullgroup&i.=%sysfunc(scan(&Fullgroup.,&i.,|));
            %let i = %eval(&i. + 1);
        %end;
        %let nFullgroup = %eval(&i. - 1);
        data ___Fullgroup;
            length &Group. $200.;
            %do i=1 %to &nFullgroup.;
                &Group. = "&&Fullgroup&i.";                    
                &CustomSortGrpvar.=&i.;
                output;
            %end;
        run;
    %end;
    %let ngroup=%nobs(___Fullgroup);

    data _null_;
        set ___Fullgroup end=last;
        call symputx("__Group"||strip(put(_n_,best.)),strip(&Group.),"L");
        if last then call symputx("__Grouplast",strip(put(_n_,best.)),"L");
    run;

**--------------------------------------------------------------------------------
 | Step 4: Get Subgroup for header
 ---------------------------------------------------------------------------------;
   data ___Conddsq ;
        set &Dataset.;
        %if %length(&cond.)>0 %then %do; where (&cond.) %end; ;
        %do i=1 %to &nby.;
            array a&i.(*) &&by&i..;
        %end;
        %if "&_DonotdisplayGroup."="1" %then %do;
            &Group.="_NOGROUP_";
        %end;
        totflag=0;
    run;
data ___Conddsq_gh2;
	set ___Conddsq;
run;

    %if &outtotal.>0 %then %do;
        data ___Conddsq;
            length &casevar. $200.;
            set ___Conddsq;
            &casevar.=cats(&casevar.,&Group.);
            output;
            totflag=1;
            &Group. = "&Totname.";
            &casevar.=cats(&casevar.,&Group.);
            output;
        run;        
    %end;   
data ___Conddsq_gh3;
	set ___Conddsq;
run;

    data ___Conddsq_missingvalue;
        set ___Conddsq;
        if cmiss(&Var.,&SubGrp.)^=0 then output ___Conddsq_missingvalue;
    run;  

    %** Check missing value for the analysis variables &var & &subgrp *;
    %if %length(&fillmissing.)=0 %then %do;
        %if %nobs(___Conddsq_missingvalue)>0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Analysis variables &Var. and &SubGrp. should not include missing value, please check! ;
            %goto exit;
        %end;
    %end;

    ** Check the KEY variables *;
    proc sql undo_policy=none;
          create table ___Conddsq_keyvar as
                select distinct &Sqlby_notrt_cn.,&Var.,&Casevar.
                    from ___Conddsq
          ;
    quit;

    %if %nobs(___Conddsq)^=%nobs(___Conddsq_keyvar) %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Variables &Sqlby. are not the KEY variables, please check the parameter by!. ;
        %goto exit;
    %end;

    ** Recreate a numeric Subgroup variable to sort *;
    %if %length(&SubGrpn.)>0 %then %let SortSubgrpvar=&SubGrpn.; 
    %else %let SortSubgrpvar=&Subgrp.;
    %let CustomSortSubgrpvar=__SortSubgrpvar;

    %if %nobs(___Conddsq)=0 %then %do;
        %if %length(&FullSubGrp.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) No record in the dataset ___Conddsq, please check!, or you can fill the paramater FullSubGrp!;
            %goto exit;
        %end;
        %else %do;
            %goto FullSubGrp;
        %end;
    %end;

    **-------------------------------------------------------------------------------------------------------------
    |     Merge the popn dataset or not?
    |        When data level and adsl do not match, you need to consider whether the denominator is adsl data base,
    |        So we add the parameter denopopn, specify the data set used by the denominator, if not fill the parameter
    |        then will not merge.
     --------------------------------------------------------------------------------------------------------------;

    data ___Conddsq_missingvalue;
        set ___Conddsq;
        if cmiss(&Subgrp.,&Var.)^=0 then output;
    run;

    %if %nobs(___Conddsq_missingvalue)>0 %then %do;
        %if "%nrbquote(&Fillmissing.)"="1" %then %do;
            data ___Conddsq;
                length &Var. &SubGrp. $200.;
                set ___Conddsq;
                if missing(&Var.) then &Var.="&Missingdescribe.";
                if missing(&SubGrp.) then &SubGrp.="&Missingdescribe.";
            run;        
        %end;
        %else %if %length(&Fillmissing.)>0 %then %do;
            %unquote(&FillMissing.);
            %if %nobs(___Conddsq_missingvalue)>0 %then %do;
                %put ER%STR(ROR): (&SYSMACRONAME.) There are still missing values after filling, please check the filling code check data ___Conddsq_missingvalue! ;
                %goto exit;
            %end;  
        %end;    
    %end;    

    proc sql undo_policy=none;
        create table ___POPN_denopopn as
            select distinct &Casevar.,  a.&Group.,  a.&Groupn.,&Sqlby_notrt_cn.
                from (select distinct &Casevar., &Group. , &Groupn. from ___popn) as a
                    left join (select distinct &Sqlby_notrt_cn. from ___Conddsq) as b on ^missing(&Casevar.)  
        ;
    quit;
data ___Conddsq_gh4;
	set ___Conddsq;
run;

    proc sql undo_policy=none;
        create table ___Conddsq as
            select distinct a.*, b.&var., c.&SubGrp., b.&Casevar. as &Casevar._b, c.&Casevar. as &Casevar._c
                from ___POPN_denopopn as a
                    left join ___Conddsq as b on a.&Casevar.=b.&Casevar. %do i=1 %to &nby.; and a.&&by&i..=b.&&by&i.. %end;
                    left join ___Conddsq as c on a.&Casevar.=c.&Casevar. %do j=1 %to &nFillMissingBy.; and a.&&by&j..=c.&&by&j.. %end;
        ;
    quit;

    %if %nobs(___POPN_denopopn)^=%nobs(___Conddsq) %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Err%str(or) linking baseline, please check dataset ___Bycycle: and parameter by!;
        %goto exit;
    %end;  

    data ___Conddsq_missingvalue_popn;
        set ___Conddsq;
        if missing(&Casevar._b) or missing(&Casevar._c) then output;
    run;    
data ___Conddsq_gh0;
	set ___Conddsq;
run;

    %if %nobs(___Conddsq_missingvalue_popn)>0 %then %do;
        %if "&Denopopn."="1" %then %do;
            %if "%nrbquote(&Fillmissing.)"="1" %then %do;
                data ___Conddsq;
                    length &Var. &SubGrp. $200.;
                    set ___Conddsq;
                    if missing(&Var.) then &Var.="&Missingdescribe.";
                    if missing(&SubGrp.) then &SubGrp.="&Missingdescribe.";
                run;        
            %end;
            %else %if %length(&Fillmissing.)>0 %then %do;
                %unquote(&FillMissing.);
                data ___Conddsq_missingvalue_popn;
                    set ___Conddsq;
                    if cmiss(&Subgrp.,&Var.)^=0 then output;
                run;

                %if %nobs(___Conddsq_missingvalue_popn)>0 %then %do;
                    %put ER%STR(ROR): (&SYSMACRONAME.) There are still missing values after filling, please check the filling code and check data ___Conddsq_missingvalue_popn! ;
                    %goto exit;
                %end;
            %end;
        %end;
        %else %if "&Denopopn."="0" %then %do;
            data ___Conddsq;
                set ___Conddsq;
                if cmiss(&Casevar._b,&Casevar._c)=2 then delete;
            run;  
        %end;
        %else %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) The dataset ___SubGrppopn and &_pop_data. do not match, please check the dataset ___SubGrppopn_not_match and fill the parameter denopopn!;
            %goto exit;
        %end;
    %end;
data ___Conddsq_gh;
	set ___Conddsq;
run;

    proc sort data = ___Conddsq; by &SortSubgrpvar.; run;
    data ___Conddsq;
        set ___Conddsq;
        by &SortSubgrpvar.;
        retain &CustomSortSubgrpvar. 0;
        if first.&SortSubgrpvar. then &CustomSortSubgrpvar.=&CustomSortSubgrpvar.+1;
    run;

    proc sql undo_policy=none;
        create table ___FullSubGrp as
            select distinct &CustomSortSubgrpvar.,&Subgrp.
                from ___Conddsq
        ;
    quit;

    ** FullSubGrp(Need to list which should categories will be subject to ins data set) *;
    %FullSubGrp:
    %if %length(&FullSubGrp.)>0 %then %do;
        proc datasets nolist nodetails NoWarn lib=work;
            delete ___FullSubGrp /memtype=data;
        quit;
        %let i = 1;
        %do %while(%qscan(&FullSubGrp.,&i.,|) ^= %str( ));
            %local FullSubGrp&i.;
            %let FullSubGrp&i.=%sysfunc(scan(&FullSubGrp.,&i.,|));
            %let i = %eval(&i. + 1);
        %end;
        %let nFullSubGrp = %eval(&i. - 1);
        data ___FullSubGrp;
            length &Subgrp. $200.;
            %do i=1 %to &nFullSubGrp.;
                &Subgrp. = "&&FullSubGrp&i.";                    
                &CustomSortSubgrpvar.=&i.;
                output;
            %end;
        run;
    %end;
    %let nSubGrp=%nobs(___FullSubGrp);

   **----------------------------------------------------------------------------
    | Add total group    
    |    a): if parameter SubGrpTotal eq to 1 then total will be display the front
    |    b): if parameter SubGrpTotal eq to 2 then total will be display the back
    -----------------------------------------------------------------------------;
    %if "&SubGrpTotal."="1" or "&SubGrpTotal."="2" %then %do;
        data ___FullSubGrp;
            length &Subgrp. $200.;
            set ___FullSubGrp end=last;
            _Resort=1;
            output;
            if last then do;
                &Subgrp. = "&Totsubgrpname.";   
                %if "&SubGrpTotal."="1" %then %do;
                    &CustomSortSubgrpvar.=%eval(&nSubgrp.+1);
                %end;
                %else %do;
                    &CustomSortSubgrpvar.=0;
                %end;
                _Resort=999;
                output;
            end;
        run;
        %if "&SubGrpTotal."="2" %then %do;
            data ___FullSubGrp;
                set ___FullSubGrp;
                &CustomSortSubgrpvar.=&CustomSortSubgrpvar.+1;
            run;
        %end;
        %let nSubGrp=%eval(&nSubgrp.+1);
    %end;
    %else %do;
        data ___FullSubGrp;
            set ___FullSubGrp;
            _Resort=1;
        run;
    %end;

    proc sort data=___FullSubGrp; by &CustomSortSubgrpvar.; run;
    data _null_;
        set ___FullSubGrp end=last;
        call symputx("__SubGrp"||strip(put(_n_,best.)),strip(&Subgrp.),"L");
    run;

    ** Get the number of subject per group per subgroup display to header *;
    proc sql undo_policy=none;
        create table ___header_01 as
            select distinct *
                from ___Fullgroup as a
                    full join ___FullSubGrp as b on a.&Group.^=b.&Subgrp.
        ;
        create table ___header_Grp as
            select distinct &Group. ,count(distinct &Casevar.) as _grpsum_
                from ___popn
                    group by &Group. 
        ;
        create table ___header_Subgrp as
            select distinct &Group.,&Subgrp.,count(distinct &Casevar.) as _Subgrpsum_
                from ___Conddsq
                    group by &Group. ,&Subgrp.
        ;
        create table ___header_02 as
            select distinct a.*
                            ,coalesce(b._grpsum_,0) as _grpsum_
                            ,coalesce(c._Subgrpsum_,0) as _Subgrpsum_
                from ___header_01 as a
                    left join ___header_Grp as b on a.&Group.=b.&Group.
                    left join ___header_Subgrp as c on a.&Group.=c.&Group. and a.&Subgrp.=c.&Subgrp.
                        order by a.&CustomSortgrpvar.,a._Resort
        ;
    quit;

    data ___header_03;
        set ___header_02 end=last;
        by &CustomSortgrpvar. _Resort;

        ** If need display total then should be recreate the number of subject *;
        retain __Subgrpntotal 0;
        if first.&CustomSortgrpvar. then do;
            __Subgrpntotal=0;
        end;
        __Subgrpntotal+_Subgrpsum_;
        if &Subgrp. = "&Totsubgrpname." then _Subgrpsum_=__Subgrpntotal;
    run;

    ** Resort *;
    proc sort data = ___header_03 out=___header;
        by &CustomSortgrpvar. &CustomSortSubgrpvar.;
    run;

    data _null_;
        set ___header end=last;
        by &CustomSortgrpvar. &CustomSortSubgrpvar.;

        ** Get number of subject by group *;
        if first.&CustomSortgrpvar. then do;
            call symputx(cats("__Grpnsubj",&CustomSortgrpvar.),_grpsum_,"L");
        end;

        ** Get number of subject by group and subgrp *;
        call symputx(cats("__Subgrpnsubj",&CustomSortgrpvar.,&CustomSortSubgrpvar.),_Subgrpsum_,"L");
    run;

**--------------------------------------------------------------------------------
 | Step 5: Start calculating
 |     a): if parameter Dnmtrtype eq to 0 then will not be display percent
 |     b): if parameter Dnmtrtype eq to 1 then take the total of the columns as the denominator
 |     c): if parameter Dnmtrtype eq to 2 then take the total of the columns and rows as the denominator
 |     d): if parameter Dnmtrtype eq to 3 then will be use the total subjects of each group as the denominator to display percent
 |     e): if parameter Dnmtrtype eq to 4 then take the total of the rows as the denominator
 ---------------------------------------------------------------------------------;
    %if %nobs(___Conddsq)=0 %then %do;
        data ___table_rtf;
            array a(*) $ _Ltop &Listvarname.;
            %do i=1 %to &nGroup.; 
                %do j=1 %to &nSubgrp.; 
                    _&i.&j._value="";
                %end; 
            %end;
            if _n_=0;
        run;
        %let computeline=;
        %let ltopvar=;
        %let by=;
        %let reportby=;
        %let breakvars=;
        %goto report;
    %end;


    **--------------------------------------------------------------------------------
     | Recreate a numeric var variable to sort
     |     a): parameter Var and dataset should be filled, the parameter Varn is the 
     |         sorting variable, and if it is not filled in, the Var variable is used to sort.
     |     b): The default output data set &Dataset. has a Var list. When the FullVar parameter is not 
     |         used, otherwise the Var list will be output according to the FullVar parameter,
     |         and Varn parameter will not work.
     ---------------------------------------------------------------------------------;
    %if %length(&Varn.)>0 %then %let Sortvar=&Varn.; 
    %else %let Sortvar=&Var.;
    %let CustomSortvar=__Sortvar;

    %if %m_var_exist(inds=&Dataset.,varname=&Sortvar.)=0 %then %do;
        %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Sortvar. not in dataset &Dataset., please check!;
        %goto exit;
    %end;

    proc sort data = ___Conddsq; by &Sortvar.;run;
    data ___Conddsq;
        set ___Conddsq;
        by &Sortvar. ;
        retain &CustomSortvar. 0;
        if first.&Sortvar. then &CustomSortvar.=&CustomSortvar.+1;
    run;

    proc sql undo_policy=none;
        create table ___Fullvar as
            select distinct &CustomSortvar.,&Var. length=200
                from ___Conddsq
        ;
    quit;

    ** Fullvar(Need to list which should categories will be subject to ins data set) *;
    %if %length(&Fullvar.)>0 %then %do;
        proc datasets nolist nodetails NoWarn lib=work;
            delete ___FullVar /memtype=data;
        quit;
        %let i = 1;
        %do %while(%qscan(&Fullvar.,&i.,|) ^= %str( ));
            %local Fullvar&i.;
            %let Fullvar&i.=%sysfunc(scan(&Fullvar.,&i.,|));
            %let i = %eval(&i. + 1);
        %end;
        %let nFullvar = %eval(&i. - 1);
        data ___Fullvar;
            length &Var. $200.;
            %do i=1 %to &nFullvar.;
                &Var. = "&&Fullvar&i.";                    
                &CustomSortvar.=&i.;
                output;
            %end;
        run;
    %end;
    %let nvar=%nobs(___Fullvar);

   **----------------------------------------------------------------------------
    | Add total group    
    |    a): if parameter VarTotal eq to 1 then total will be display the front
    |    b): if parameter VarTotal eq to 2 then total will be display the back
    -----------------------------------------------------------------------------;
    %if "&VarTotal."="1" or "&VarTotal."="2" %then %do;
        data ___Fullvar;
            length &Var. $200.;
            set ___Fullvar end=last;
            output;
            if last then do;
                &Var. = "&totvarname.";  
                %if "&VarTotal."="1" %then %do;
                    &CustomSortvar.=999;
                %end;
                %else %do;
                    &CustomSortvar.=0;
                %end;
                output;
            end;
        run;
        %let nvar=%eval(&nvar.+1);
    %end;
    data _null_;
        set ___Fullvar end=last;
        call symputx("__var"||strip(put(_n_,best.)),strip(&Var.),"L");
    run;
data ___Conddsq;
	set ___Conddsq;
	weicha=byte(230)||byte(156)||byte(170)||byte(230)||byte(159)||byte(165);
run;
    ** Calculate number of patients per &by. per group per SubGrp *;
    proc sql undo_policy=none;
        create table ___nsubj_each as
            select distinct &Sqlby.,&Subgrp.,&Var.,count(distinct &Casevar.) as nsubj
                from ___Conddsq 
                    group by &Sqlby.,&Subgrp.,&Var.
        ;
        create table ___nsubj_&Var. as
            select distinct &Sqlby_notrt_c.,&Group.,&Subgrp.,"&totvarname." as &Var.,count(distinct &Casevar.) as nsubj
                from ___Conddsq 
                    group by &Sqlby_notrt_c.,&Group.,&Subgrp.
        ;
        create table ___nsubj_&Subgrp. as
            select distinct &Sqlby_notrt_c.,&Group.,&Var.,"&Totsubgrpname." as &Subgrp.,count(distinct &Casevar.) as nsubj
                from ___Conddsq 
							%if "&Dnmtrtype."="2" %then (where=(UPCASE(&SubGrp) not in (  "NOT DONE") and UPCASE(&SubGrp)^=weicha )) ;
                    group by &Sqlby_notrt_c.,&Group.,&Var.
        ;
    quit;
data ___nsubj_&Var.;
	set ___nsubj_&Var.;
	weicha=byte(230)||byte(156)||byte(170)||byte(230)||byte(159)||byte(165);
run;
    %if ("&SubGrpTotal."="1" or "&SubGrpTotal."="2") and ("&VarTotal."="1" or "&VarTotal."="2") %then %do;
        proc sort data = ___nsubj_&Var.
			%if "&Dnmtrtype."="2" %then (where=(UPCASE(&SubGrp) not in (  "NOT DONE") and UPCASE(&SubGrp)^=weicha )) ;
		; by &by. &Group.; run;
        data ___nsubj_&Var.;
            length &Var. &Subgrp. $200.;
            set ___nsubj_&Var.;
            retain totnsubj 0;
            by &by. &Group.;
            output;
            if first.&Group. then totnsubj=0;
            totnsubj=totnsubj+nsubj;
            if last.&Group. then do
                &Subgrp.="&Totsubgrpname.";
                nsubj=totnsubj;
                output;
            end;
        run;
    %end;

    data ___nsubj1;
        length &Var. &Subgrp. $200.;
        set ___nsubj_each 
        %if "&VarTotal."="1" or "&VarTotal."="2" %then ___nsubj_&Var.; 
        %if "&SubGrpTotal."="1" or "&SubGrpTotal."="2" %then ___nsubj_&Subgrp.; ;
    run;

    ** Create sort variables, to be consistent with header *;
    proc sql undo_policy=none;
        create table ___nsubj2 as
            select distinct a.*,d.&CustomSortSubgrpvar.,b.&CustomSortgrpvar.
                from ___nsubj1 as a
                    left join ___Fullgroup as b on a.&Group.=b.&Group.
                    left join ___FullSubGrp as c on a.&Var.=c.&Subgrp.
                    left join ___FullSubGrp as d on a.&Subgrp.=d.&Subgrp.
        ;
    quit;

    data ___nsubj3;
        set ___nsubj2;
        _newgroup = cats(&Group.,&Subgrp.);
        _newgroupn = cats(&CustomSortgrpvar.,&CustomSortSubgrpvar.);
        if missing(&CustomSortgrpvar.) then delete;
    run;

    proc sort data = ___nsubj3 ;by &by. &Var. _newgroupn;run;
    proc transpose data=___nsubj3 out=___nsubj_trans;
        by &by. &Var.;
        var nsubj;
        idlabel _newgroup;
        id _newgroupn;
    run;

   **----------------------------------------------------------------------------
    | Display the category of var    
    |    a): if parameter FollowData eq to 1 then follow the dataset
    |    b): if parameter FollowData not eq to 1 then follow parameter Fullvar
    -----------------------------------------------------------------------------;
    %if "&FollowData."="1" %then %do;
        proc sql undo_policy=none;
            create table ___report_rtf_01 as
                select distinct &Sqlby.&CustomSortvar. as _ltopn ,&Var. length=200
                    from ___Conddsq 
            ;
        run;

       **----------------------------------------------------------------------------
        | Add total group    
        |    a): if parameter VarTotal eq to 1 then total will be display the front
        |    b): if parameter VarTotal eq to 2 then total will be display the back
        -----------------------------------------------------------------------------;
        %if "&VarTotal."="1" or "&VarTotal."="2" %then %do;
            proc sort data = ___report_rtf_01; by &by. _ltopn; run;
            data ___report_rtf_01;
                set ___report_rtf_01;
                by &by. _ltopn;
                output;
                if last.&Lstbyvar. then do;
                    &Var. = "&totvarname.";
                    %if "&VarTotal."="1" %then %do;
                        _ltopn=999;
                    %end;
                    %else %do;
                        _ltopn=0;
                    %end;
                    output;
                end;
            run;
        %end;
    %end;

    %else %do;
        proc sql undo_policy=none;
            create table ___cycle as
                select distinct &Sqlby 
				%if %index((&Sqlby) , &Group.) = 0 %then  ,"" as &Group.;
                    from ___Conddsq 
            ;
            create table ___report_rtf_01( %if %index(%quote(&Sqlby) , &Group.) = 0 %then drop=&Group.; rename=(&CustomSortvar.=_ltopn)) as
                select distinct *
                    from ___cycle as a
                        full join ___FullVar as b on a.&Group.^=b.&Var.
            ;
        quit;
    %end;

    proc sort data = ___report_rtf_01; by &by. &Var.; run;
    proc sort data = ___nsubj_trans; by &by. &Var.; run;
    data ___report_rtf_02;
        merge ___report_rtf_01(in=a) ___nsubj_trans;
        by &by. &Var.;
        if a;
    run;

    ** Adjust the format *;
    proc sort data = ___report_rtf_02; by &by. _ltopn; run;
    data ___report_rtf_03;
        set ___report_rtf_02 end=last;
        by &by. _ltopn;
        array a(*) %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; _&i.&j. %end; %end; ;
        do i = 1 to dim(a);
            if 0 <= _ltopn < 9999 then a(i) = coalesce(a(i),0);
        end;
    run;

    ** Calculate percent *;
    %if &Dnmtrtype.>0 %then %do;
        %if "&Dnmtrtype."="1" or "&Dnmtrtype."="2" or "&Dnmtrtype."="3" %then %do;
            proc sql undo_policy=none;
                create table ___report_rtf_04 as
                    select distinct *
                        %if "&VarTotal."="1" or "&VarTotal."="2" %then %do;
                            %do i=1 %to &nGroup.; 
                                %do j=1 %to &nSubgrp.;
                                    ,max(_&i.&j.) as _&i.&j._d 
                                %end; 
                            %end;  
                        %end;
                        %else %do;
                            %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,sum(_&i.&j.) as _&i.&j._d %end; %end;
                        %end;

                        %if "&Dnmtrtype."="1" %then %do;
                            %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,_&i.&j./(calculated _&i.&j._d) * 100 as _&i.&j._p %end; %end; 
                        %end; 
                        %else %if "&Dnmtrtype."="2" %then %do;
                            %do i=1 %to &nGroup.; 
                                %if "&SubGrpTotal."="1" %then %do;
                                    ,sum((calculated _&i.1_d) %do j=2 %to %eval(&nSubgrp.-1); ,(calculated _&i.&j._d) %end;) as _&i.d
                                %end;
                                %else %if "&SubGrpTotal."="2" %then %do;
                                    ,sum((calculated _&i.2_d) %do j=3 %to &nSubgrp.; ,(calculated _&i.&j._d) %end;) as _&i.d
                                %end;
                                %else %do;
                                    ,sum((calculated _&i.1_d) %do j=2 %to &nSubgrp.; ,(calculated _&i.&j._d) %end;) as _&i.d
                                %end;
                            %end;
                            %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,_&i.&j./(calculated _&i.d) * 100 as _&i.&j._p %end; %end; 
                        %end;
                        %else %if "&Dnmtrtype."="3" %then %do;
                            %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,_&i.&j./&&__Grpnsubj&i.. * 100 as _&i.&j._p %end; %end; 
                        %end;
                        from ___report_rtf_03
                            group by &Sqlby.
                                order by &sqlby., _ltopn
                ;
            quit;
        %end;
        %else %if "&Dnmtrtype."="4" %then %do;
            proc sql undo_policy=none;
                create table ___report_rtf_04 as
                    select distinct *
                        %do i=1 %to &nGroup.; 
                            %if "&SubGrpTotal."="1" %then %do;
                                ,sum(_&i.1 %do j=2 %to %eval(&nSubgrp.-1); ,_&i.&j. %end;) as _&i.d
                            %end;
                            %else %if "&SubGrpTotal."="2" %then %do;
                                ,sum(_&i.2 %do j=3 %to &nSubgrp.; ,_&i.&j. %end;) as _&i.d
                            %end;
                            %else %do;
                                ,sum(_&i.1 %do j=2 %to &nSubgrp.; ,_&i.&j. %end;) as _&i.d
                            %end;
                        %end;
                        %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,_&i.&j./(calculated _&i.d) * 100 as _&i.&j._p %end; %end; 
                        from ___report_rtf_03
                            order by &sqlby., _ltopn
                ;
            quit;
        %end;
    %end;
    %else %do;
        proc sort data=___report_rtf_03 out=___report_rtf_04;
            by &by. _ltopn;
        run;
    %end;

    data ___report_rtf_05;
        length _ltop $&Ltoplen.;
        set ___report_rtf_04 end=last;
        by &by. _ltopn;
        %if %length(&Ltopvar.)>0 %then %do;
            _ltop = "&Preblank."||strip(&Var.);
        %end;
        %else %do;
            _ltop = strip(&Var.);
        %end;

        %do i=1 %to &nGroup.; 
            %do j=1 %to &nSubgrp.; 
                %if &Dnmtrtype.>0 %then %do;
                    _&i.&j._value = strip(put(_&i.&j.,best.-l)) ||"("||strip(coalescec(put(_&i.&j._p,32.&prec.-l),"&_precblank.")) ||")";

                    ** Denominator does not output percentage *;
                    %if "&Dnmtrtype."="1" %then %do;
                        if &VAR.="&Totvarname." then _&i.&j._value = put(_&i.&j.,best.-l);
                    %end;
                    %else %if "&Dnmtrtype."="2" %then %do;
                        %if "&SubGrpTotal."="2" and &j.=1 %then %do;
                            if &VAR.="&Totvarname." then _&i.&j._value = put(_&i.&j.,best.-l);
                        %end;
                        %else %if "&SubGrpTotal."="1" and &j.=&nSubgrp. %then %do;
/*                            if &VAR.="&Totvarname." then _&i.&j._value = put(_&i.&j.,best.-l);*/
                        %end;
                    %end;
                    %else %if "&Dnmtrtype."="4" %then %do;
                        %if "&SubGrpTotal."="2" and &j.=1 %then %do;
                            _&i.&j._value = put(_&i.&j.,best.-l);
                        %end;
                        %else %if "&SubGrpTotal."="1" and &j.=&nSubgrp. %then %do;
                            _&i.&j._value = put(_&i.&j.,best.-l);
                        %end;
                    %end;
                %end;
                %else %do;
                    _&i.&j._value = put(_&i.&j.,best.-l);
                %end;
            %end;
        %end; ;

        array a(*) %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.;  _&i.&j._value %end; %end; ;
        ** Display percent for zero or not *;
        %if %symexist(display_zero_percent) %then %do;
            %if "&display_zero_percent."="0" %then %do;
                do i=1 to dim(a);
                    a(i)=prxchange("s/\A0\([[:ascii:]]+\)/0/i",-1,a(i));
                end;
            %end;
        %end;

        %if %symexist(display_100_percent) %then %do;
            do i=1 to dim(a);
                a(i)=prxchange("s/\(100.(0*)\)/(&display_100_percent.)/i",-1,a(i));
            end;
        %end;
        output;

        ** Add ablank line in the behind for each by *;
        if last.&Lstbyvar. then do;
            _ltop="";
            _ltopn=9999;
            _ObsFlag_="Add ablank line in the behind for each by";
            call missing(_NAME_ %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,_&i.&j._value %end; %end; );
            output;
            call missing(_Ltopn,_ObsFlag_);
        end;

        ** Add ltopvar for each by *;
        %if %length(&Ltopvar.)>0 %then %do;
            if last.&Ltopvar. then do;
                _ltop=&Ltopvar.;
                _ltopn=-1;
                _ObsFlag_="Add Ltopvar";
                call missing(_NAME_ %do i=1 %to &nGroup.; %do j=1 %to &nSubgrp.; ,_&i.&j._value %end; %end; );
                output; 
                call missing(_Ltopn,_ObsFlag_);
            end;
        %end;
    run;

    ** Create var_seq *;
    proc sort data = ___report_rtf_05 out= _table ; by &by. _ltopn; run;

    data ___table_rtf;
        set  _table;
    run;

    proc sort data = ___table_rtf ;
        by  &By.  ;
    run;

**--------------------------------------------------------------------------------
 | Step 5: Report by macro report5
 ---------------------------------------------------------------------------------;
    %report:

	data ___table_rtf1;
		set ___table_rtf;
		%if %index((&Sqlby) , &Group.) = 0 %then &Groupn. =1;;
		keep _character_ &by _ltopn    %if %index((&Sqlby) , &Group.) = 0 %then   &Groupn.;;
	run;
	data ___table_rtf2;
		set ___table_rtf1;
		where missing(_ObsFlag_);
		%do n=1 %to &__Grouplast;
			&Group&n=catx('/',of _&n.:);
		%end;
		%do n=1 %to &__Grouplast;
			if &Group.="&&__Group&n" then do;
			%do j=1 %to &nvar;
					_ngc&j.=_&n.&j._value;
			%end;
			end;
		%end;
	run;

** ___table_rtf_list listvar列数据集 ;
	data ___table_rtf_list;		if _n_=0;	run;
%if %length(&nlistvars.)>0 %then %do;
			%local  Listvarnameby;
			%let nlistvarsad1=%eval(&nlistvars.+1);
	%do i=1 %to &nlistvars;
		%if %length(&Listvarnameby.) = 0 %then %do;
			%let Listvarnameby = %qcmpres(&&Listvarname&i..) ;
		%end;
		%else %let Listvarnameby = &Listvarnameby. %qcmpres(&&Listvarname&i..) ;
		proc sort data=___table_rtf2 out=___table_rtf_list&i. nodupkey ;
			by &Listvarnameby;
		quit;
		data ___table_rtf_list&i.;
			length _text1 $200;
			set ___table_rtf_list&i.;
			_Vvaluelabeln_=-10+&i.;	_text1=%if &i ^=1 %then repeat("  ",&i.-2)|| ;&&Listvarname&i.;
		run;
		data ___table_rtf_list;
			set ___table_rtf_list ___table_rtf_list&i. ;
		run;
	%end;
	proc sort data=___table_rtf_list ;
		by &by ;
	quit;
%end;

	data ___table_rtf3;
		length _text1 $200;
		set ___table_rtf2;
				_text1=repeat("  ",&nlistvars+1.-2)||_ltop;
	run;
	data &Outds._sort;
		set ___table_rtf_list(keep= _text1 &by   _ltopn) ___table_rtf3;
	run;
	proc sort data=&Outds._sort ;
		by &by    _ltopn;
	quit;
	data &Outds.;
		set &Outds._sort;
		keep _text1 _ngc:;
	;
	run;

	%if "&Debug." ^= "1" %then %do;
		proc datasets nolist nodetails NoWarn lib=work;
		delete ___:  _table
		%if "&Endline." ^= "0" %then %do;
			&Outds._sort
		%end;
		/memtype=data;
		quit;
	%end;

    options mcompilenote=&_mcompilenote. validvarname=&_validvarname.;

	%exit:
	ods exclude none;
%mend;

