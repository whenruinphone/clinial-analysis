/*************************************************************************************************
File name: aecount-v1-7.sas

Study:

SAS version: 9.4

Purpose:   Generate Adverse Events Table

Macros called:  %nobs %m_var_exist %m_var_type

Notes:

Parameters: Refer to UserGuide

Sample: 

Date started: 06SEP2023

Date completed: 06SEP2023

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 06SEP2023 Hao.Guo create
1.1 27NOV2023 Hao.Guo add sortway=TOTAL/ TRT/ ALPHA
1.2 14JUN2024 Hao.Guo change the datasetname when Norecord /Norecord=chinses when _rtffmt.=CH
1.3 10OCT2024 Hao.Guo add SubSocDesc=2
1.4 20DEC2024 Hao.Guo add pvalue
1.5 24DEC2024 Hao.Guo add PreBlank= Chgltop=
1.6 06JAN2025 Hao.Guo CHAGNE FORM PVALUE6.3 TO PVALUE12.3
1.7 17JAN2025 Hao.Guo 1.add length 2.change the usubjid to &Casevar.
*********************************** Prepared by Highthinkmed ************************************/
%macro aecount(
         Dataset=
        ,Cond=
        ,Popn=
        ,Casevar=

        ,Group=
        ,Groupn=
        ,CtGroup=
        ,FullGroup=
        
        ,SubGrp=         /** Sub-Category  */
        ,SubGrpn=
        ,SubGrpOrder=    /** descending */
        ,SubSocDesc=   1
        ,FullSubGrp=
        ,SubGrpWorst=1  /** 0-no , 1-Just Worst */

        ,VarList=      
        ,SortWay=        /** TOTAL, TRT, ALPHA */
		,SocSortWay=
        ,Prec=
		,Alpha=
		,pvaluetype=
		,PreBlank=
		,CHGLTOP =

        /** parameter used in report */
        ,Endline=1
        ,Debug=0
		,OutDs=
    ) / store;

	ods exclude all;
    %put Running Macro (&SYSMACRONAME. V1.6);

    **----------------------------------*;
    **     Initialize Macro Parameter   *;
    **----------------------------------*;
    %local mac_msg i j loop1 loop2 loop3 nColumn maxLevel nVarlist LevelVarList LevelVarList_sql Sort
          _pop_data _pop_cond _Groupnflag Sortvar neachgroup ntrtgroup CtGroupn nFullGroup GroupList
          SubGrpFlag SortSubgrpvar nFullSubGrp nSubGrp neachSubGrp SubGrpList SortSub 
          SortWayGroupn OrderList columnlist rptvarname missLevel isCompute _trttotal_flag _total_flag
          nTrtseq nFullPeriod PeriodList SortPeriod __Chisquare __Fishers LevelVarList_sort LevelVarList_sort_sql
			LevelVarList_sort_c LevelVarList_sql_b LevelVarList_sql_ab LevelVarList_sql_m
          pvaluefootnoteF pvaluefootnoteC Outtotal Norecord
		SubGrpLabel ColumnStyle SubGrpTotal SubGrpDisplay UncodedPos Patients Events Percentage Overall PreBlank ;

    %** Global Macro Variables Used: _Rtffmt _Encoding escapechar _footnote_ _title_);
    %if %symexist(_Encoding)=0 %then %let _Encoding=%upcase(&SYSENCODING);

    %** set default value ;
    %if %length(&Casevar.)=0          %then %let    Casevar=usubjid;
    %if %length(&Group.)=0            %then %let    Group=trt01p;
    %if %length(&SortWay.)=0          %then %let    SortWay=TOTAL;
    %if %length(&Prec.)=0             %then %let    Prec=1;
    %if %length(&ColumnStyle)=0       %then %Let    ColumnStyle=nSubj(pSubj)|nEvent;
    %if %length(&Outtotal.)=0         %then %let    Outtotal=1;
    %if %length(&PreBlank.)=0         %then %let    PreBlank=%str(  );
    %if %length(&EndLine.)=0          %then %let    EndLine=1;
    %if %length(&Debug.)=0            %then %let    Debug=0;
    %if %length(&Percentage.)=0       %then %Let    Percentage=%str(%%);
    %if %length(&SubGrpLabel.)=0      %then %let    SubGrpLabel=//\c;
    %if %length(&SubSocDesc.)=0      %then %let    SubSocDesc=1;
    %if %length(&OutDs.)=0          %then %let    OutDs=_table_rtf;
    %if %length(&Norecord.)=0   %then %let Norecord=No adverse event was reported;
    %if &_rtffmt.=CH   %then %let Norecord=无记录;

    data _null_;
        array _ChineseLabel[*] $5000  Patients Events Overall ;
        Patients=byte(192)||byte(253)||byte(202)||byte(253);
        Events=byte(192)||byte(253)||byte(180)||byte(206);
        Overall=byte(186)||byte(207)||byte(188)||byte(198);

        do i = 1 to dim(_ChineseLabel);
            %if "&_Encoding"="UTF-8" %then %do;
                _ChineseLabel[i] = kcvt(_ChineseLabel[i], "EUC-CN", "UTF-8");
            %end;
            if symget(vname(_ChineseLabel[i]))="" then 
                call symputx(vname(_ChineseLabel[i]),strip(_ChineseLabel[i]),"l");
        end;
    run;

    %** Add SubGrpWorst for Just Use the Worst Type when Calculate the Number of Subject ?;
    %if %length(&SubGrpWorst.)=0 %then %let SubGrpWorst = 1;;

    %** check required macro parameter ;
    %if %length(&Dataset.)=0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) The parameter dataset can not be null, please check!;
        %goto exit;
    %end;
    %if %sysfunc(exist(&Dataset.))=0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) The dataset &Dataset. do not exist, please check the parameter Dataset!;
        %goto exit;
    %end;

    %if %length(&Varlist.)=0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) The parameter Varlist can not be null, please check!;
        %goto exit;
    %end;

    ** delete temporary datasets;
    proc datasets nolist nodetails NoWarn lib=work;
        delete ___: _table /memtype=data;
    quit; 

    **-------------------------------------------------------------*;
    **    create report column according to ColumnStyle=           *;
    **-------------------------------------------------------------*;
    %let i = 1;
    %do %while (%qscan(&ColumnStyle, &i , |) ne %str( ));
        %local column&i columnLabel&i;
        %let column&i = %qscan(&ColumnStyle, &i , |);
        %let j = 1;
        %do %while (%qscan(&&column&i, &j) ne %str( ));
            %local stat&i._&j. statLabel&i._&j.;
            %let stat&i._&j. = %upcase(%qscan(&&column&i, &j));

            ** validate the value in ColumnStyle= ;
            %if "%str(&&stat&i._&j.)" ^= "NSUBJ" and "%str(&&stat&i._&j.)" ^= "PSUBJ"
                and "%str(&&stat&i._&j.)" ^= "NEVENT" and "%str(&&stat&i._&j.)" ^= "PEVENT"
                %then %put ERR%str(OR): (&SYSMACRONAME.) The value in ColumnStyle= is invalid. Should be one of nSubj, pSubj, nEvent, pEvent (ignore case);

            ** define column label;
            %if "%str(&&stat&i._&j.)" = "NSUBJ" %then %let statLabel&i._&j. = &Patients.;
                %else %if "%str(&&stat&i._&j.)" = "NEVENT" %then %let statLabel&i._&j. = &Events.;
                %else %if "%substr(%str(&&stat&i._&j.), 1,1)" = "P" %then %let statLabel&i._&j. = &Percentage.;

            ** define column SAS code;
            %if "%substr(%str(&&stat&i._&j.), 1,1)" = "N" %then %let stat&i._&j. = strip(put(%str(&&stat&i._&j.), ??best.));
                %else %if "%substr(%str(&&stat&i._&j.), 1,1)" = "P" %then %let stat&i._&j. = strip(put(coalesce(%str(&&stat&i._&j.), 0), ??6.&prec.));

            %let j = %eval(&j + 1);
        %end;
        %let nStat&i = %eval(&j - 1);

        %if &&nStat&i = 1 %then %let columnLabel&i = &&statLabel&i._1 ;
        %else %if &&nStat&i = 2 %then %let columnLabel&i = &&statLabel&i._1 (&&statLabel&i._2) ;

        %if %index(&&columnLabel&i,/) or %index(&&columnLabel&i,|) or %index(&&columnLabel&i,\) %then %let columnLabel&i =%sysfunc(tranwrd(%sysfunc(tranwrd(%sysfunc(tranwrd(&&columnLabel&i.,/,%str(%/))),|,%str(%|))),\,%str(%\)));

        %let i = %eval(&i + 1);
    %end;
    %let nColumn = %eval(&i - 1);

    **-----------------------------------------------------------------------------*;
    **    separate VarList= , check variables existence , mask special character   *;
    **-----------------------------------------------------------------------------*;

    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%/),%nrbquote(*$*)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%|),%nrbquote(*$$*)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%\),%nrbquote(*$$$*)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(%=),%nrbquote(*$$$$*)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(//),%nrbquote(/ /)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(/\),%nrbquote(/ \)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrbquote(\=),%nrbquote(\ =)));
    %let Varlist=%sysfunc(tranwrd(%nrbquote(&Varlist.),%nrstr(%%),%nrbquote(*$$$$$*)));

    %let i = 1;
    %let maxLevel = 0;
    %do %while (%qscan(%nrbquote(&VarList.),&i.,|) ^=%str( ));
        %local varvlmd&i. varnameList&i. nLevel&i.;
        %let varvlmd&i.     = %qscan(%nrbquote(&Varlist.),&i.,|);
        %let varnameList&i. = %qcmpres(%upcase(%qscan(%nrbquote(&&varvlmd&i..),1,/)));

        %if %index(%nrbquote(&&varnameList&i.),-) %then %do; ** Regular AE Frequency, get each level;
            %let j = 1;
            %local varname&i._lv0;
            %do %while (%qscan(%nrbquote(&&varnameList&i..),&j.,-) ^=%str( ));
                %local varname&i._lv&j.;
                %let varname&i._lv&j. = %qscan(%nrbquote(&&varnameList&i..),&j.,-);
                %if %m_var_exist(&Dataset.,  &&varname&i._lv&j. ) =0 %then %do;
                    %put  ER%STR(ROR): (&SYSMACRONAME.) Variable &&varname&i._lv&j. is not in the dataset, please check!;
                    %goto exit;
                %end;
                %let j = %eval(&j + 1);
            %end;
            %let nLevel&i. = %eval(&j-1);
            %if &maxLevel < &&nLevel&i %then %let maxLevel = &&nLevel&i;
        %end;
        %else %if "%substr(&&varnameList&i..XXXXX,1,5)"="BLANK" %then %do; ** Blank Line;
            %local varname&i._lv0;
            %let varname&i._lv0 = &&varnameList&i.;
            %if %m_var_exist(&Dataset.,&&varnameList&i.) %then %do;
                %put WARN%STR(ING): (&SYSMACRONAME.) Variable &&varname&i._lv0 prefixed to blank exists in the data set &Dataset. and is treated as an output blank line, please check the variable need or not analysis!;
            %end;
            %let nLevel&i = 0;
        %end;
        %else %do; ** Summary Item, treated as TabFreq;
            %local varname&i._lv0;
            %let varname&i._lv0 = &&varnameList&i.;
            %if %m_var_exist(&Dataset.,&&varnameList&i.)=0 %then %do;
                %put  ER%STR(ROR): (&SYSMACRONAME.) Variable &&varname&i._lv0 is not in the dataset, please check!;
                %goto exit;
            %end;
            %let nLevel&i = 0;
        %end;
        %let i = %eval(&i + 1);
    %end;
    %let nVarlist = %eval(&i-1);

    %if "&maxLevel" = "0" %then %do;
        %let LevelVarList = dummy;
        %let LevelVarList_sql = dummy;
        %let LevelVarList_sort = dummy;
        %let LevelVarList_sort_sql = dummy;
        %let LevelVarList_sort_c = ;
        %let LevelVarList_sql_b = ;
        %let LevelVarList_sql_ab = ;
        %let LevelVarList_sql_m = ;
        %let SortWay=ALPHA;
    %end;
    %else %do;
        %let LevelVarList = _LEVEL_1;
        %let LevelVarList_sql = _LEVEL_1;
        %let LevelVarList_sort = _LEVEL_sort_1;
        %let LevelVarList_sort_sql = _LEVEL_sort_1;
        %let LevelVarList_sort_c = _LEVEL_1;
        %let LevelVarList_sql_b = b._LEVEL_1;
        %let LevelVarList_sql_ab = and a._LEVEL_1=b._LEVEL_1;
        %let LevelVarList_sql_m = "_LEVEL_1";
        %do i = 2 %to &maxLevel; %let LevelVarList = &LevelVarList. _LEVEL_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sql = &LevelVarList_sql., _LEVEL_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sort = &LevelVarList_sort. _LEVEL_sort_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sort_sql = &LevelVarList_sort_sql., _LEVEL_sort_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sort_c = &LevelVarList_sort_c. _LEVEL_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sql_b = &LevelVarList_sql_b., b._LEVEL_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sql_ab = &LevelVarList_sql_ab. and a._LEVEL_&i.=b._LEVEL_&i.; %end;
        %do i = 2 %to &maxLevel; %let LevelVarList_sql_m = &LevelVarList_sql_m., "_LEVEL_&i."; %end;
    %end;

    **------------------------------------------*;
    **     Check and separate PopN=             *;
    **------------------------------------------*;
    %if %length(&popN)>0 %then %do;
        %let _pop_cond=%qscan(&popN,2,|);
        %let _pop_data=%qscan(&popN,1,|);
    %end;
    %else %if %sysfunc(exist(adam.adsl)) %then %do;
        %let _pop_cond=1;
        %let _pop_data=adam.adsl;
    %end;
    %else %do;
        %put ERR%str(OR): (&SYSMACRONAME.) Macro Parameter PopN= does not specify popN dataset and adam.adsl does not exist.;
        %goto exit;
    %end;

    %if %length(&_pop_cond.)=0 %then %let _pop_cond=1;

    %if %sysfunc(exist(&_pop_data.))=0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) The dataset &_pop_data. do not exist, please check the parameter popn!;
        %goto exit;
    %end;

    proc sql undo_policy=none;
        create table ___CheckUniqueCasevar as
            select &Casevar, count(*) as count 
            from &_pop_data
            group by &Casevar
            having count > 1;
    quit;

    %if %nobs(___CheckUniqueCasevar)>0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) &Casevar. is not unique in &_pop_data. dataset. Popn dataset should be one record per subject.;
        %goto exit;
    %end;

    **---------------------------*;
    **    Create Header          *;
    **---------------------------*;

    ** check required variable in _pop_data;
    %if %m_var_exist(&_pop_data.,&Casevar.)=0 %then %do;
        %put ERR%str(OR): The &Casevar variable that are filled in by the parameter Casevar= are not in the &_pop_data. dataset, please check!;
        %goto exit;
    %end;
    %if %m_var_exist(&_pop_data.,&Group.)=0 %then %do;
        %put ERR%str(OR): Group variable must exist in &_pop_data. dataset, please check the parameter Group=!;
        %goto exit;
    %end;
    %if %length(&Groupn.)>0 %then %do;
        %if %m_var_exist(&_pop_data.,&Groupn.)=0 %then %do;
            %put  ER%STR(ROR): (&SYSMACRONAME.) Groupn variable must exist in &_pop_data. dataset, please check the parameter Groupn!;
            %goto exit;
        %end;
    %end;

    ** check required variable in input dataset;
    %if %m_var_exist(&Dataset.,&Casevar.)=0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) The &Casevar variable that are filled in by the parameter Casevar are not in the &Dataset. dataset, please check!;
        %goto exit;
    %end;
    %if %m_var_exist(&Dataset.,&Group.)=0 %then %do;
        %put  ER%STR(ROR): (&SYSMACRONAME.) Group variable must exist in &Dataset. dataset, please check the parameter group!;
        %goto exit;
    %end;
    %if %length(&Groupn.)>0 %then %do;
        %if %m_var_exist(&Dataset.,&Groupn.)=0 %then %do;
            %put  ER%STR(ROR): (&SYSMACRONAME.) Groupn variable must exist in &_pop_data. dataset, please check the parameter Groupn!;
            %goto exit;
        %end;
    %end;

    %if %length(&Groupn.)=0 %then %do;
        %if %m_var_exist(&_pop_data.,&Group.n)>0 and %m_var_exist(&Dataset.,&Group.n)>0 %then %let Groupn = &Group.n;
    %end;

    data ___header;
        length &Group. $5000;
        set &_pop_data.;
        where %unquote(&_pop_cond.);
        _Sortvar1_=1;
        %if %length(&CtGroup.)>0 %then %do;
            if &Group.=&CtGroup. then _Sortvar1_=0;
        %end;
    run; 

    %if %nobs(___header)<=0 and %length(&FullGroup)=0 %then %do;
        %put ERR%str(OR): No record in the &_pop_data. dataset, please check!;
        %goto exit;
    %end;

    ** Recreate &Groupn. to sort The default value of the aggregate group is 98, 99. *;
    %if %length(&Groupn.)>0 %then %do;
        %let Sortvar=&Groupn.;
        %let _Groupnflag=1;
    %end;
    %else %do;
        %let Sortvar=&Group.;
        %let Groupn=&Group.n;
    %end;

    proc sort data = ___header;
        by %if "&_Groupnflag." ^= "1" %then _Sortvar1_; &Sortvar. ;
    run;

    data ___header;
        set ___header;
        by %if "&_Groupnflag."^="1" %then _Sortvar1_; &Sortvar. ;
        retain _CustomSortvar_ 0;
        if first.&Sortvar. then _CustomSortvar_=_CustomSortvar_+1;
        _orgGroupvar_=&Sortvar.;
        &Groupn.=_CustomSortvar_;
        keep &Casevar. _Sortvar1_ &Group. &Groupn. _orgGroupvar_  ;
    run;

    ** treated total *;
    data ___header_trttotal; if _n_=0; run;
    %if %length(&CtGroup.) > 0 %then %do;
        data ___header_trttotal;
            set ___header;
            where &Group. ^= &CtGroup.;
            &Groupn. = 98;
            &Group. = "Trtname_total";
            drop _orgGroupvar_ _Sortvar1_;
        run;
    %end;

    ** all total *;
    data ___header_total;
        set ___header;
        &Groupn. = 99;
        &Group. = "Totname_total";
        drop _orgGroupvar_ _Sortvar1_;
    run;

    data ___header_allgroup;
        set ___header ___header_trttotal ___header_total;
    run;

    proc sql undo_policy=none;
        create table ___header_out as
            select distinct &Group.,&Groupn.,count(distinct &Casevar.) as _grpsum_,_orgGroupvar_
                from ___header_allgroup
                    group by &Groupn. 
                        order by &Groupn. 
        ;
    quit;

    %** Add Check Header by Yunhui.Cui;
    %let empty_header = ;
    data _null_;
        set ___header_out;
        if missing(&Group.) then do;
            call symputx("empty_header","Y","L");
            put "ERR%str()OR: &Group. has empty value, please check ___HEADER_OUT data!";
        end;
		call symputx('_GRP_'||strip(put(&Groupn.,best.)),strip(put(_grpsum_,best.)),'G');
    run;
    %if "&empty_header." = "Y" %then %goto exit;;

    %** Fullgroup;
    %if %length(&FullGroup.)>0 %then %do;
        ** FullGroup(Need to list which should categories will be subject to ins data set) *;
        %let i = 1;
        %do %while(%qscan(&FullGroup.,&i.,|) ^= %str( ));
            %local FullGroup&i.;
            %let FullGroup&i.=%sysfunc(scan(&FullGroup.,&i.,|));
            %let i = %eval(&i. + 1);
        %end;
        %let nFullGroup = %eval(&i. - 1);
        data ___FullGroup;
            length &Group. $5000.;
            %do i=1 %to &nFullGroup.;
                &Group. = "&&FullGroup&i.";                    
                &Groupn. = &i.;
                output;
            %end;

            &Group. = "Trtname_total";                    
            &Groupn. = 98;
            output;
            &Group. = "Totname_total";                    
            &Groupn. = 99;
            output;
        run;

        proc sql;
            create table ___FullGroup_Check as
                select distinct *,count(&Group.) as Check_Number
                    from ___FullGroup
                    group by &Group.
            ;
        quit;

    %end;

    %if %sysfunc(exist(___FullGroup)) %then %do;
        ** Add FullGroup *;
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

    %let neachgroup=0; 
    proc sql noprint;
        select distinct count(distinct &Group.) into: neachgroup
            from ___header_out where &Groupn not in (98 99);
    quit;

    %let ntrtGroup=0;
    %if %length(&CtGroup.) > 0 %then %do;
        proc sql noprint;
            select distinct count(distinct &Group.) into: ntrtGroup
                from ___header_out where &Group. ^= &CtGroup. and &Groupn not in (98 99);
        quit;

        ** Get macro variable CtGroupn *;
        proc sql noprint;
            select distinct &Groupn. into: CtGroupn trimmed
                from ___header_out  where &Group. = &CtGroup.;
        quit;
    %end;

    ** Control group output *;
    ** 1: if need to report treated total, less than two treated group then not report treated total*;
    ** 2: if need to report all total, less than two group then not report all total and treated total*;
    data ___header_out;
        set ___header_out;
        isReport = 1;
        isCalculate = 1;
        isPvalue = 1;
        SortWay = "&SortWay";

        %if "&Outtotal."="0" %then %do;
            if &Groupn. in (98 99) then isReport = 0;  
        %end;
        %else %if "&Outtotal."="1" %then %do;
            if &ntrtgroup. <= 1 or &ntrtgroup.=&neachgroup. then do;
                if &Groupn. in (98) then isReport = 0;
            end;
            if &neachgroup. <= 1 then do;
                if &Groupn. in (99) then isReport = 0;
            end;
        %end;
        %else %if "&Outtotal."="2" %then %do;
            if &Groupn. in (99) then isReport = 0;
            if &ntrtgroup. <= 1 then do;
                if &Groupn. in (98) then isReport = 0;
            end;
        %end;
        %else %if "&Outtotal."="3" %then %do;
            if &Groupn. in (98) then isReport = 0;
            if &neachgroup. <= 1 then do;
                if &Groupn. in (99) then isReport = 0;
            end;
        %end;

        %if "%upcase(&SortWay.)" = "ALPHA" %then %do;
            if &Groupn. in (98 99) and isReport=0 then isCalculate = 0;
        %end;
        %else %if "%upcase(&SortWay.)" = "TRT" %then %do;
            if &Groupn. in (99) and isReport=0 then isCalculate = 0;
        %end;
        %else %if "%upcase(&SortWay.)" = "TOTAL" %then %do;
            if &Groupn. in (98) and isReport=0 then isCalculate = 0;
        %end;

    run;

    proc sql noprint;
        select isCalculate into: _trttotal_flag trimmed from ___header_out where &Groupn. = 98;
        select isCalculate into: _total_flag trimmed from ___header_out where &Groupn. = 99;
    quit;

    ** create macro variables used in report5;
    data _null_;
        set ___header_out end = last;
        where isReport = 1;
        retain headermaxwth 0;
        headerwth=lengthn(strip(scan(&Group.,1,"$")));
        if headermaxwth<=headerwth then headermaxwth=headerwth;
        %if "%upcase(&sortvar.)"^="%upcase(&Group.)" %then %do;
            call symputx("orggroupn"||strip(put(_n_,best.)),strip(put(_orgGroupvar_,best.)),"L");
        %end;
        call symputx("headername"||strip(put(_n_,best.)),"_ngc"||strip(put(&Groupn.,best.)),"L");
        call symputx("headerorgname"||strip(put(_n_,best.)),strip(put(&Groupn.,best.)),"L");
        call symputx("headerlabel"||strip(put(_n_,best.)),strip(&Group.),"L");
        call symputx("headersum"||strip(put(_n_,best.)),_grpsum_,"L");
        if last then do;
            call symputx("nheader",_n_,"L");
            call symputx("headerwth",headermaxwth,"L");
        end;
    run;

    proc sql noprint;
        select distinct "'"||strip(&Group.)||"'"
                     ,&Groupn.        
                into :GroupList separated by ',' 
                    ,:Sort separated by ','  
            from ___header_out where isReport = 1 order by &Groupn.;
    quit;

    **----------------------*;
    **     Sub-Category     *;
    **----------------------*;
    %if %length(&SubGrp)=0 %then %do;
        %let SubGrpFlag=0;
        %let SubGrpTotal=;
        %let SubGrpDisplay=;

        %let SubGrp=_SubGrp_;
        %let SubGrpn=_SubGrpN_;
        %let SortSub=-1;
        %let SubGrpList='_NA_';

        ** no sub-category, create a dummy dataset and go to next step; 
        data ___SubGrp_out; length &SubGrp. $5000; _SubGrp_="_NA_"; _SubGrpN_ = -1; run;
        %goto EndSubGrp;  
    %end;

    %else %if %length(&SubGrp)>0 %then %do;
        %let SubGrpFlag=1;
        %if %m_var_exist(&Dataset., &Subgrp.)=0 %then %do;
            %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Subgrp. not in dataset &Dataset., please check!;
            %goto exit;
        %end;
        %if %length(&SubGrpn)>0 %then %do;
            %if %m_var_exist(&Dataset., &Subgrpn.)=0 %then %do;
                %put ER%STR(ROR): (&SYSMACRONAME.) Variable &Subgrpn. not in dataset &Dataset., please check!;
                %goto exit;
            %end;
        %end;
        %else %if %length(&SubGrpn)=0 %then %do;
            %if %m_var_exist(&Dataset., &Subgrp.n)>0 %then %let SubGrpn = &Subgrp.n;
        %end;

        %if %length(&SubGrpTotal.)=0   %then %let SubGrpTotal=1;
        %if %length(&SubGrpDisplay.)=0 %then %let SubGrpDisplay=COLUMN;
        %if "%upcase(&SubGrpDisplay)"="MERGE" %then %do;
            %if &SubGrpTotal. ^= 1 %then %put WARN%str()ING: SubGrpTotal Must be 1 When SubGrpDisplay = MERGE, Please Modify!;;
            %let SubGrpTotal=1;
        %end;
    %end;

    ** Recreate a numeric SubGrpn variable to sort *;
    %if %length(&SubGrpn.)>0 %then %let SortSubgrpvar=&SubGrpn.; 
    %else %do;
        %let SortSubgrpvar=&SubGrp.;
        %let SubGrpn=&SubGrp.n;
    %end;

    proc sort data = &Dataset. out = ___SubGrp nodupkey;
        %if %length(&Cond) > 0 %then %do; where %unquote(&Cond.); %end; 
        by &SortSubgrpvar. &SubGrp.;
    run;

    data ___SubGrp;
        length &SubGrp. $5000;
        set ___SubGrp;
        by &SortSubgrpvar.;
        retain _CustomSortvar_ 0;
        if first.&SortSubgrpvar. then _CustomSortvar_=_CustomSortvar_+1;
        _orgSubGrpvar_ = &SortSubgrpvar.;
        &SubGrpn.=_CustomSortvar_;

        keep &SubGrp. &SubGrpn. _orgSubGrpvar_;
    run;

    data ___SubGrp_out;
        set ___SubGrp end=last;
        %** check missing SubGrp value ;
        if missing(&SubGrp.) then do;
            &Subgrp = "(未编码)";
        end;
        output;
        if last then do;
            call missing(_orgSubGrpvar_,&SubGrpn.);
            &SubGrp. = "&Overall.";
            %if "&SubGrpTotal."="0" %then %do; &SubGrpn. = -1; %end;
            %else %if "&SubGrpTotal."="1" %then %do; &SubGrpn. = 0; %end;
            %else %if "&SubGrpTotal."="2" %then %do; &SubGrpn. = 999; %end;
            output;
        end;
    run;

    %if %length(&FullSubGrp.)>0 %then %do;
        ** FullSubGrp(Need to list which should categories will be subject to ins data set) *;
        %let i = 1;
        %do %while(%qscan(&FullSubGrp.,&i.,|) ^= %str( ));
            %local FullSubGrp&i.;
            %let FullSubGrp&i.=%sysfunc(scan(&FullSubGrp.,&i.,|));
            %let i = %eval(&i. + 1);
        %end;
        %let nFullSubGrp = %eval(&i. - 1);
        data ___FullSubGrp;
            length &SubGrp. $5000.;
            %do i=1 %to &nFullSubGrp.;
                &SubGrp. = "&&FullSubGrp&i.";                    
                &SubGrpn.= &i.;
                output;
            %end;
            &SubGrp. = "&Overall.";
            %if "&SubGrpTotal."="0" %then %do; &SubGrpn. = -1; %end;
            %else %if "&SubGrpTotal."="1" %then %do; &SubGrpn. = 0; %end;
            %else %if "&SubGrpTotal."="2" %then %do; &SubGrpn. = 999; %end;
            output;
        run;
    %end;

    %if %sysfunc(exist(___FullSubGrp)) %then %do;
        ** Add FullSubGrp *;
        proc sql undo_policy=none;
            create table ___SubGrp_out as
                select distinct a.*,b._orgSubGrpvar_
                    from ___FullSubGrp as a
                        left join ___SubGrp_out as b
                            on a.&SubGrp.=b.&SubGrp.
                                order by a.&SubGrpn.
            ;
        quit;
    %end;

    %let neachSubGrp=0;
    proc sql noprint;
        select distinct count(distinct &SubGrp.) into: neachSubGrp
            from ___SubGrp_out where &SubGrpn. not in (-1 0 999);
    quit;

    ** Control SubGrp Total;
    data ___SubGrp_out;
        set ___SubGrp_out;
        isReport = 1;
        %if "&SubGrpTotal."="0" %then %do;
            if &SubGrpn. in (-1) then isReport = 0;           
        %end;
        %else %if "&SubGrpTotal."="1" or "&SubGrpTotal."="2" %then %do;
            if &neachSubGrp. <= 1 then do;
                if &SubGrpn. in (0 999) then isReport = 0;    
            end;
        %end;
    run;

    proc sort data = ___SubGrp_out; by &SubGrpn; run;
    data _null_;
        set ___SubGrp_out end = last;
        %if "%upcase(&SortSubgrpvar.)"^="%upcase(&SubGrp.)" %then %do;
            call symputx("orgSubGrpn"||strip(put(_n_,best.)),strip(put(_orgSubGrpvar_,best.)),"L");
        %end;
        call symputx("subgrporgname"||strip(put(_n_,best.)),strip(put(&SubGrpn.,best.)),"L");
        call symputx('SubGrpValue'||strip(put(_n_,best.)),strip(&SubGrp.), "L");
        if last then do;
            call symputx("neachSubGrp",_n_,"L");
        end;
    run;

    proc sql noprint;
        select distinct "'"||strip(&SubGrp.)||"'"
                     ,&SubGrpn.        
                into :SubGrpList separated by ',' 
                    ,:SortSub separated by ','  
            from ___SubGrp_out order by &SubGrpn.;
    quit;

    %if "%upcase(&SubGrpDisplay)" = "HEADER" %then %do;
        data _null_;
            set ___SubGrp_out end=last;
            where isReport = 1;
            call symputx('SubGrpHeader'||strip(put(_n_,best.)),strip(&SubGrp.), "l");
            call symputx('SubgrpName'||strip(put(_n_,best.)),strip(put(&SubGrpn.,best.)), "l");
            if last then call symputx('nSubGrp',strip(put(_n_,best.)), "l");
        run;
    %end;

%EndSubGrp:


    **----------------------------------*;
    **     Data Set Pre-proccessing     *;
    **----------------------------------*;

    ** Step _00: read input dataset and filter dataset;
    data ___condseq;
        length recpos 8;
        set &Dataset.;
        %if %length(&Cond) > 0 %then %do; where %unquote(&Cond.); %end;
        recpos = _N_;
        %if "&maxLevel"="0" %then %do; dummy=""; _lvSEQ_=.; %end; 
    run;
    %if &SYSERR. %then %do;
        %put ERR%str(OR): (&SYSMACRONAME) Possibly invalid where statement sepcified by macro parameter (Cond=&Cond.);
        %goto exit;
    %end;
    
    %if %nobs(___condseq)<=0 %then %do;
        ** No record then go to reporting *;
		%if "&Debug." ^= "1" %then %do;
			proc datasets nolist nodetails NoWarn lib=work;
			delete ___:  
			%if "&Endline." ^= "0" %then %do;
				&Outds._sort
			%end;
			/memtype=data;
			quit;
		%end;

        data &OutDs.; 
            _text1="&Norecord.";
        run;
        %goto exit;
    %end;

    ** Step _01: check Group value and SubGrp Value and Casevar;
    data ___condseq ___CheckGroup ___CheckSubGrp ;
        set ___condseq;
        _trtgroup_ = 0;
        %if %length(&CtGroup.)>0 %then %do;
            _trtgroup_=(&Group. not in (&CtGroup.) );
        %end;

        _orgGroupvar_=&Sortvar.;
        %do loop1 = 1 %to &neachgroup.;
            %if "%upcase(&Sortvar.)"="%upcase(&Group.)" %then %do;
                if &Group.="%nrbquote(&&headerlabel&loop1..)" then &Groupn.=&&headerorgname&loop1..;
            %end;  
            %else %do;
                %if %length(&&orggroupn&loop1..)>0 %then %do;
                    if _orgGroupvar_=%nrbquote(&&orggroupn&loop1..) then &Groupn.=&&headerorgname&loop1..;
                %end;
            %end;
        %end;

        %if "&SubGrpFlag" = "0" %then %do;
            &SubGrp. = "_NA_"; &SubGrpn. = -1;
        %end;

        %if "&SubGrpFlag" = "1" %then %do;
            _orgSubGrpvar_=&SortSubgrpvar.;
            %do loop1 = 1 %to &neachSubGrp.;
                %if "%upcase(&SortSubgrpvar.)"="%upcase(&SubGrp.)" %then %do;
                    if &SubGrp.="%nrbquote(&&SubGrpValue&loop1..)" then &SubGrpn.=&&subgrporgname&loop1..;
                %end;
                %else %do;
                    %if %length(&&orgSubGrpn&loop1..)>0 %then %do;
                        if _orgSubGrpvar_=%nrbquote(&&orgSubGrpn&loop1..) then &SubGrpn.=&&subgrporgname&loop1..;
                    %end;
                %end;
            %end;
        %end;
   
   
        if &Group. in (&GroupList.) and &SubGrp. in (&SubGrpList.) then output ___condseq;
        if &Group. not in (&GroupList.) then output ___CheckGroup;
        if &SubGrp. not in (&SubGrpList.) then output ___CheckSubGrp;
    run;

    %if %nobs(___CheckGroup)>0 %then %do;
        %put WARN%STR(ING): (&SYSMACRONAME.) The value of the variable &Group. in the data set &Dataset. but not exsit in the data set &_pop_data., please check the data set ___CheckGroup!;
    %end;

    %if %nobs(___CheckSubGrp)>0 %then %do;
        %put WARN%STR(ING): (&SYSMACRONAME.) The variable &SubGrp. in the data set &Dataset. have miss%str()ing value, please check the data set ___CheckSubGrp!;
    %end;

    ** Check Casevar *;
    proc sql undo_policy=none;
        create table ___CheckCasevarnotinPopn as
            select distinct &Casevar.
            from ___condseq where &Casevar. not in (select distinct &Casevar. from ___header);
    quit;
    %if %nobs(___CheckCasevarnotinPopn)>0 %then %do;
        %put ERR%STR(OR): (&SYSMACRONAME.) The subject is unique identification information does not match. Please check the data set ___CheckCasevarnotinPopn, the value in the data but not in the header!;
        %goto exit;
    %end;

    ** Step _02: Transpose analysis variables *;
    data ___condseq;
        length _Varn_ _Vlevel_ _lvSEQ_ 8 _Vname_ &Group. &SubGrp. _AESUMITEM_ _Vvaluelabel_ &LevelVarList. $ 2000;
        set ___condseq;
        array __m_b(*) table_seq;

        %do i=1 %to &nVarlist;
            _Varn_ = &i;
            _Vname_ = "%upcase(&&varnameList&i..)";
            _Vlevel_ = &&nLevel&i;
            
            call missing(_lvSEQ_, _AESUMITEM_, _Vvaluelabel_, of &LevelVarList.); 
            
            %if "%substr(&&varnameList&i..XXXXX,1,5)"^="BLANK" %then %do;
                %if %length(&&varname&i._lv0)>0 %then %do; ** AE Summation ;  
                    _AESUMITEM_ = "%qscan(%qscan(&&varvlmd&i,2,/), 2,\)";
                    _Vvaluelabel_ = scan(_AESUMITEM_,2,"=");
                    %if "%m_var_type(___condseq, &&varnameList&i..)"="N" %then %do;
                        if &&varnameList&i.. = input(strip(scan(_AESUMITEM_,1,"=")),best.) then output;
                    %end;
                    %else %if "%m_var_type(___condseq, &&varnameList&i..)"="C" %then %do;
                        if &&varnameList&i.. = strip(scan(_AESUMITEM_,1,"=")) then output;
                    %end;
                %end;

                %else %do; ** AE Frequency ;
                    %do j=1 %to &&nLevel&i;
                        _LEVEL_&j. = &&varname&i._lv&j.;
                    %end;
                    _lvSEQ_ = &&nLevel&i;
                    output;
                    %do j=&&nLevel&i %to 2 %by -1;
                        _LEVEL_&j. = ".SUBTOTAL.";
                        _lvSEQ_ = %eval(&j-1);
                        output;
                    %end;
                %end;
            %end;
        %end;
    run;

    ** Step _03: delete _NOTREPORT_ records, check uncoded records;
    data ___condseq;
        set ___condseq;

        array __m_a(*) _AESUMITEM_ _Vvaluelabel_;
        do i=1 to dim(__m_a);
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$$$*","="));
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$$*","\"));
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$*","|"));
            __m_a(i)=trim(tranwrd(__m_a(i),"*$*","/"));
            __m_a(i)=tranwrd(__m_a(i),"%'","'");
            __m_a(i)=tranwrd(__m_a(i),'%"','"');
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$$$$*","%"));
        end;

        array _LevelVarList[*] &LevelVarList.;
        do i = 1 to dim(_LevelVarList);
            if upcase(strip(_LevelVarList[i])) = "_NOTREPORT_" then delete; 
        end;

        do j = 1 to _Vlevel_;
            if missing(_LevelVarList[j]) then do;
                call symputx('missLevel', "1", "L");
                _LevelVarList[j] = "(未编码)";
            end;
        end;
        drop i j;
    run;
    
    %if "&missLevel" = "1" %then %do;
        %put WARN%str(ING): (&SYSMACRONAME) Some Level Variable have miss%str(ing) value, please check!;
    %end;

    %if "&SubGrpFlag." = "1" and "&SubGrpWorst." = "1" %then %do;
        ** Flag the worst event **;
        proc sql undo_policy=none;
          create table ___multiSubj as
            select distinct _Varn_, _Vname_, &Group., &Groupn., &LevelVarList_sql., _lvSEQ_, &Casevar.
                    ,count(*) as _multiCount, max(&SubGrpn.) as _maxSubGrpn
            from ___condseq
            group by _Varn_, _Vname_, &Group., &Groupn., &LevelVarList_sql., _lvSEQ_, &Casevar.
          ;
        quit;

        %if "&Debug"="1" %then %do; data ___condseq_debug_01; set ___condseq; run; %end;

        proc sql undo_policy=none;
          create table ___condseq as
            select b._multiCount, b._maxSubGrpn, a.*
            from ___condseq as a
            left join ___multiSubj as b on a._Varn_ = b._Varn_ and a.&Casevar. = b.&Casevar. and a.&Group. = b.&Group. and a.&Groupn. = b.&Groupn.
                    %do i = 1 %to &maxLevel.; and a._LEVEL_&i. = b._LEVEL_&i. %end;
            order by _Varn_, &Groupn, &Casevar., _lvSEQ_, recpos
          ;
        quit;

        data ___condseq;
            length _multiFlag $ 20;
            set ___condseq;
            if _maxSubGrpn ^= &SubGrpn. then _multiFlag = "Y";
            &Casevar._bk = &Casevar.;
            if _multiFlag = "Y" then call missing(&Casevar.);
        run;

        %if "&Debug"="1" %then %do; data ___condseq_debug_02; set ___condseq; run; %end;
    %end;

    %if "&SubGrpFlag."="1" %then %do;
        ** Step _04: Add SubGrp Total *;
        data ___condseq;
            set ___condseq;
            output;
            &SubGrp.  = "&Overall.";
            %if "&SubGrpTotal."="0" %then %do; &SubGrpn. = -1; %end;
            %else %if "&SubGrpTotal."="1" %then %do; &SubGrpn. = 0; %end;
            %else %if "&SubGrpTotal."="2" %then %do; &SubGrpn. = 999; %end;
            output;
        run;
    %end;

    ** Add treated total *;
    data ___condseq_trttotal; if _n_=0; run;
    %if %length(&CtGroup.)>0 and "&_trttotal_flag." = "1" %then %do;
        data ___condseq_trttotal;
            set ___condseq;
            %if %length(&CtGroup.)>0 %then %do;
                where &Group. ^= &CtGroup.;
            %end;
            &Groupn. = 98;
            &Group. = "Trtname_total";
        run;
    %end;

    ** Add all total *;
    data ___condseq_total; if _n_=0; run;
    %if ("&Outtotal."="1" or "&Outtotal."="3" or "%upcase(&SortWay.)" = "TOTAL") and "&_total_flag" = "1" %then %do;
        data ___condseq_total;
            set ___condseq;
            &Groupn. = 99;
            &Group. = "Totname_total";
        run;
    %end;

    data ___condseq_allgroup;
        set ___condseq ___condseq_trttotal ___condseq_total;
    run;

    **------------------------------------------------------------------------*;
    **    create Ltop_model for calculation                                   *;
    **    1-varnameList/2-computeline\value=label\\\/3-Blankline/4-Pvalue|    *;
    **------------------------------------------------------------------------*;
    data ___Ltop01;   
        length _Varlist_ $5000. _Varvlmd_ $1000. _Varn_ _Vlevel_ 8 _Vname_ _Vcompute_ $5000. 
               _Vvaluelabellist_ _Vvalue_ _Vvaluelabel_ $5000. _Vvaluelabeln_ 8;

        _Varlist_=symget('Varlist');
        do i=1 to count(_Varlist_,'|');
            _Varvlmd_=strip(scan(_Varlist_,i,'|'));
            _Varn_=i;

            _Vname_      = upcase(strip(scan(_Varvlmd_,1,'/')));
            _Vcompute_   = trim(scan(scan(_Varvlmd_,2,'/'),1,'\'));
            _Vblankline_ = input(scan(_Varvlmd_,3,'/'), ??best.);
            _Vmethod_    = input(scan(_Varvlmd_,4,'/'), ??best.);

            if find(_Vname_,"-") then _Vlevel_ = count(_Vname_,"-")+1;
                else _Vlevel_ = 0;
            _Vvaluelabellist_ = scan(_Varvlmd_,2,'/');

            ** List all the specified value *;
            do j=1 to count(_Varvlmd_,'=');
                _Vvaluelabeln_=j;
                _Vvaluelabellist_=strip(scan(scan(_Varvlmd_,2,'/'),j+1,'\'));
                if substr(strip(_Vvaluelabellist_),1,1)^='=' then _Vvalue_=trim(scan(_Vvaluelabellist_,1,'='));
                _Vvaluelabel_=trim(scan(_Vvaluelabellist_,2,'='));
                output;
                call missing(_Vvaluelabeln_,_Vvaluelabellist_,_Vvalue_,_Vvaluelabel_);
            end;
            if j<=_Vvaluelabeln_ or (missing(_Vvaluelabeln_) and j=1) then output;
            call missing(_Varvlmd_,_Varn_,_Vname_,_Vcompute_,_Vblankline_,_Vmethod_,_Vlevel_,_Vvalue_,_Vvaluelabel_,_Vvaluelabeln_);
        end;
        keep _Vname_ _Vcompute_ _Vblankline_ _Vmethod_ _Varn_ _Vlevel_ _Vvalue_ _Vvaluelabel_ _Vvaluelabeln_ _Vvaluelabellist_;
    run;

    data ___Ltop01_check_pvalue;
        set ___Ltop01;
        where _Vmethod_>0;
    run;

    %if %nobs(___Ltop01_check_pvalue)>0  %then %do;
        %if %length(&CtGroup.)<=0 %then %do;
            %put  ER%STR(ROR): (&SYSMACRONAME.) If need display p-value then the parameter CtGroup should not be null, please check!;
            %goto exit;
        %end;
    %end;

    ** Replace characters that conflict with delimiters and false quotes *;
    data ___Ltop01;
        set ___Ltop01;
        where _Vvaluelabeln_ < 2; ** only one equal sign;

        array __m_a(*) _Vcompute_ _Vvalue_ _Vvaluelabellist_ _Vvaluelabel_;
        do i=1 to dim(__m_a);
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$$$*","="));
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$$*","\"));
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$*","|"));
            __m_a(i)=trim(tranwrd(__m_a(i),"*$*","/"));
            __m_a(i)=tranwrd(__m_a(i),"%'","'");
            __m_a(i)=tranwrd(__m_a(i),'%"','"');
            __m_a(i)=trim(tranwrd(__m_a(i),"*$$$$$*","%"));
        end;
    run;
   
    ** get ltop from data;
    proc sql undo_policy=none;
        create table ___Ltop_fromdata as
            select distinct _Varn_, _Vname_, _lvSEQ_, _AESUMITEM_, _Vvaluelabel_, &LevelVarList_sql.
            from ___condseq_allgroup
            order by _Varn_, &LevelVarList_sql.;
    quit;

    ** get user define item;
    data  ___Ltop_user;
        set ___Ltop01;
        where find(_Vname_,"-") and find(_Vvaluelabellist_, "\");
        _Vvaluelabeln_=1;
        _Vvaluelabellist_=strip(_Vvaluelabellist_);
        do while(strip(scan(_Vvaluelabellist_,_Vvaluelabeln_,"\")) ^= "");
            _Vvaluelabel_ = scan(_Vvaluelabellist_,_Vvaluelabeln_,"\");
            output;
            _Vvaluelabeln_=_Vvaluelabeln_+1;
        end;
        keep _Varn_ _Vlevel_ _Vname_ _Vvaluelabel_ _Vvaluelabeln_;
    run;

    proc sql undo_policy=none;
        create table ___Ltop_user as
            select distinct a.*, b._lvSEQ_, &LevelVarList_sql.
            from ___Ltop_user as a
            left join ___Ltop_fromdata as b on a._Varn_ = b._Varn_ and a._Vlevel_ = b._lvSEQ_;
    quit;

    data ___Ltop_user;
        set ___Ltop_user;
        array _LevelVarList[*] &LevelVarList.;
        if _Vlevel_ = _lvSEQ_ and ^missing(_Vvaluelabel_) then _LevelVarList[_Vlevel_] = _Vvaluelabel_;
        drop _Vlevel_;
    run;

    proc sql undo_policy=none;
        create table ___Ltop_user as
            select distinct * from ___Ltop_user
            order by _Varn_, &LevelVarList_sql., _Vvaluelabeln_;
    quit;

    ** get computeline row;
    proc sql undo_policy=none;
        create table ___Ltop_Vcompute as
            select _Vcompute_, _Varn_, _Vname_, _Vvaluelabellist_ as _AESUMITEM_, _Vvaluelabel_
            from ___Ltop01 as a
            where not exists(select * from ___Ltop_fromdata as b where a._Varn_ = b._Varn_) ;
    quit;

    data ___Ltop02;
        set ___Ltop_Vcompute ___Ltop_fromdata ___Ltop_user;
    run;

    proc sql undo_policy=none;
        create table ___Ltop03 as
            select a.*, b._Vlevel_, b._Vblankline_  
            from ___Ltop02 as a
            left join ___Ltop01 as b on a._Varn_ = b._Varn_;
    quit;

    data ___Ltop04;
        set ___Ltop03;
        ** set default value for _Vblankline_, ;
        if ^missing(_Vcompute_) then _Vblankline_ = coalesce(_Vblankline_, 0);
            else if find(_Vname_,"-") then _Vblankline_ = coalesce(_Vblankline_, 1);
            
             else if ^missing(_AESUMITEM_) and missing(_Vcompute_) then _Vblankline_ = coalesce(_Vblankline_, 0);
            else _Vblankline_ = coalesce(_Vblankline_, 0);
    run;

    proc sql undo_policy=none;
        create table ___Ltop_model as
            select distinct a.*, &Group., &Groupn., _grpsum_, &SubGrp., &SubGrpn.
            from ___Ltop04 as a, ___header_out(where=(isCalculate=1)) as b, ___SubGrp_out as c
            order by _Varn_, &Groupn., &SubGrpn., &LevelVarList_sql., _lvSEQ_, _Vvaluelabeln_;
    quit;

    data ___Ltop_model;
        set ___Ltop_model;
        if substr(_Vname_,1,5)="BLANK" and &SubGrpn. not in (-1 0 999) then delete;
        if _Vcompute_ ^= "" and &SubGrpn. not in (-1 0 999) then delete;
    run;

    **-------------------------------------------*;
    **     Calculate nEvent nSubj Percentage     *;
    **-------------------------------------------*;

    ** Core Calculation **;

        ** calculate Event Sum: _eventsum_ **;
    proc sql undo_policy=none;
        create table ___eventsum as
            select distinct _Varn_, _Vname_,&Group., &Groupn.   , &SubGrp., &SubGrpn.,
                    count(*) as _eventsum_
            from ___condseq_allgroup 
            where _lvSEQ_ in (. 1)
            group by _Varn_, _Vname_, &Group.,  &SubGrp.
            order by _Varn_, &Groupn.,  &SubGrpn.;
    quit;

    %if "%upcase(&SubGrpDisplay.)" = "HEADER" %then %do;
        data ___Ltop_model;
            merge ___Ltop_model ___eventsum;
            by  _Varn_ &Groupn.   &SubGrpn.;
        run;
    %end;

    %else %do;
        data ___eventsum;
            set ___eventsum;
            where &SubGrpn. in (-1 0 999);
        run;

        data ___Ltop_model;
            merge ___Ltop_model ___eventsum(keep=_Varn_ &Groupn.   _eventsum_);
            by _Varn_ &Groupn.  ;
        run;
    %end;

    ** calculate nSubj, nEvent **;
    %let Link_Var = %str(_Varn_, _Vname_, &Group., &Groupn.   , &SubGrp., &SubGrpn., &LevelVarList_sql., _lvSEQ_);
    %let Link_Varn = %sysfunc(count(%nrbquote(&Link_Var.),%str(,)));

    data ___condseq_allgroup;
        length group_by $5000.;
        set ___condseq_allgroup;
        group_by = "";
        %do i = 1 %to &Link_Varn. + 1 ;
            %if %m_var_type(___condseq_allgroup,%scan(%nrbquote(&Link_Var.),&i.,%str(,))) = C %then %do;
                group_by = catx("/",group_by,%scan(%nrbquote(&Link_Var.),&i.,%str(,)));
            %end;
            %if %m_var_type(___condseq_allgroup,%scan(%nrbquote(&Link_Var.),&i.,%str(,))) = N %then %do;
                group_by = catx("/",group_by,put(%scan(%nrbquote(&Link_Var.),&i.,%str(,)),best.));
            %end;
        %end;
    run;

    proc sql undo_policy=none;
        create table ___report_count as
            select distinct _Varn_, _Vname_, &Group., &Groupn.   , &SubGrp., &SubGrpn., &LevelVarList_sql., _lvSEQ_,  
                    count(distinct &Casevar.) as nSubj, count(*) as nEvent, 1 as _fromdata_
            from ___condseq_allgroup 
            group by group_by 
            order by _Varn_, &Groupn. , &SubGrpn., &LevelVarList_sql., _lvSEQ_;
    quit;

    proc sort data = ___Ltop_model;
        by _Varn_ &Groupn.   &SubGrpn. &LevelVarList. _lvSEQ_;
    run;
    
    data ___report_out_1;
        merge ___Ltop_model ___report_count(drop = _fromdata_);
        by _Varn_ &Groupn.   &SubGrpn. &LevelVarList. _lvSEQ_;
    run;

    %if %length(&FullSubGrp)=0 and "%upcase(&SubGrpDisplay)" ^= "HEADER" %then %do;
        ** Follow Data **;
        proc sql undo_policy=none;
            create table ___report_out_1(where=(_fromdata_=1 or &SubGrpn. in (-1 0 999))) as
                select distinct a.*, b._fromdata_
                from ___report_out_1 as a
                left join ___report_count as b on a._Varn_ = b._Varn_ 
                    %do i = 1 %to &maxLevel.;
                    and a._LEVEL_&i. = b._LEVEL_&i.
                    %end;
                    and a._lvSEQ_ = b._lvSEQ_ and a.&SubGrpn. = b.&SubGrpn.
                order by _Varn_, &LevelVarList_sql, _lvSEQ_, &Groupn, &SubGrpn;
        quit;
    %end;

    data ___report_out_1;
        set ___report_out_1;

        _eventsum_ = coalesce(_eventsum_, 0);
        nSubj = coalesce(nSubj, 0);
        nEvent = coalesce(nEvent, 0);

        ** calculate pSubj, pEvent **;
         if _grpsum_ ^= 0 then pSubj = (nSubj/_grpsum_)*100; 
        if _eventsum_ ^= 0 then pEvent = (nEvent/_eventsum_)*100;

        ** create report column according to ColumnStyle= ,blanK contrl is row 1222;
        %do i = 1 %to &nColumn;
            %if &&nStat&i = 1 %then %do;
                _column_&i = &&stat&i._1;
            %end;
            %else %if &&nStat&i = 2 %then %do;
                _column_&i = &&stat&i._1||cats("(", &&stat&i._2, ")");
            %end;
        %end;

        array _array[*] &SubGrp.;
        _transposeLaebl = &Group.;
        do i = 1 to dim(_array);
            if _array[i] ^= "_NA_" then _transposeLaebl = catx(" #", _transposeLaebl, _array[i]);
        end;
        drop i;        
        %** NA if _eventsum_=0 or _grpsum_=0;
    run;

    ** step1: transpose ;
    %if "%upcase(&SubGrpDisplay.)" = "HEADER" %then %do;
        proc sort data = ___report_out_1;
            by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_
               &LevelVarList. _lvSEQ_ _Vvaluelabeln_ &Groupn. &Group.;
        run;

        %do i = 1 %to &nColumn;
            proc transpose data = ___report_out_1 out = ___report_out_2_col&i. prefix = _ngc suffix = _col&i. DELIMITER=_;
                by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_
                   &LevelVarList. _lvSEQ_ _Vvaluelabeln_;

                id &Groupn.  &SubGrpn.;
                idlabel _transposeLaebl;
                var _column_&i.;    
            run;
        %end;

        data ___report_out_2(drop = _name_);
            merge ___report_out_2_col:;
            by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_
               &LevelVarList. _lvSEQ_ _Vvaluelabeln_;
            call missing (&SubGrpn.);
        run;
    %end;

    %else %do;
        proc sort data = ___report_out_1;
            by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_
               &LevelVarList. _lvSEQ_ _Vvaluelabeln_ &SubGrpn. &SubGrp.;
        run;

        %do i = 1 %to &nColumn;
            proc transpose data = ___report_out_1 out = ___report_out_2_col&i. prefix = _ngc suffix = _col&i. DELIMITER=_;
                by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_
                   &LevelVarList. _lvSEQ_ _Vvaluelabeln_ &SubGrpn. &SubGrp.;
                   
                id &Groupn.  ;
                idlabel _transposeLaebl;
                var _column_&i.;    
            run;
        %end;

        data ___report_out_2(drop = _name_);
            merge ___report_out_2_col:;
            by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_
               &LevelVarList. _lvSEQ_ _Vvaluelabeln_ &SubGrpn. &SubGrp.;
        run;
    %end;

    **--------------------------------*;
    **     Sort by incidence rate     *;
    **--------------------------------*;
    data ___report_out_2;
        set ___report_out_2;
        if &SubGrpn in (-1, 0) then _SubGrpPreOrder_=.;
            else if &SubGrpn in (999) then _SubGrpPreOrder_=9;
        else _SubGrpPreOrder_=1;
    run;

    %if "&maxLevel"="0" %then %let OrderList = _Order_0;
    %if "&maxLevel"^="0" %then %let OrderList =  _Order_1 - _Order_&maxLevel.;
    %if "%upcase(&SubGrpOrder)"^="DESCENDING" %then %let SubGrpOrder=;

    %if "%upcase(&SortWay)" = "TOTAL" %then %let SortWayGroupn = 99;
    %else %if "%upcase(&SortWay)" = "TRT" %then %let SortWayGroupn = 98;
    %else %do;
        ** SortWay = ALPHA, create dummy variable and go to next step;
        data ___report_out_3;
            set ___report_out_2;
            by _Varn_ _Vname_ _Vlevel_ _AESUMITEM_ _Vvaluelabel_ _Vcompute_ _Vblankline_ &LevelVarList. _lvSEQ_ _Vvaluelabeln_ &SubGrpn;

            retain &OrderList. 0 ;
            array __m_a(*) &OrderList.;

            %if "&maxLevel"^="0" %then %do;
                if first._LEVEL_1  then _Order_1 = _Order_1  + 1 ;
                if first._LEVEL_&maxLevel. then _Order_&maxLevel. = _Order_&maxLevel. + 1 ;
            %end;
        run;
        
        proc sort data = ___report_out_3; by _Varn_ &OrderList. _SubGrpPreOrder_ &SubGrpOrder &SubGrpn; run;
        %goto EndSortWay;
    %end;

    %** Sort by Pinyin;
    data ___report_out_1;
        set ___report_out_1;
        array orgi_level[*] &LevelVarList;
        array sort_level[*] $5000 &LevelVarList_sort;
        do i = 1 to dim(orgi_level);
            sort_level[i]=kcvt(orgi_level[i], "&SYSENCODING", "EUC-CN");
        end;
    run;

    proc sql undo_policy=none;
        create table ___report_sortway as
            select distinct _Varn_, _Vname_, _Vlevel_, &Group., &SubGrp., _lvSEQ_, &LevelVarList_sort_sql, &LevelVarList_sql., _Vvaluelabeln_, pSubj
            from ___report_out_1
            where &Groupn. = &SortWayGroupn.  and &SubGrpn. in (-1 0 999) and ^missing(_lvSEQ_) 
            order by _Varn_, _Vname_, _lvSEQ_, pSubj desc, _Vvaluelabeln_, &LevelVarList_sort_sql.;
    quit;

    data ___report_out_1;
        set ___report_out_1;
        drop &LevelVarList_sort;
    run;

    data _null_;
        uncoded_en = "UNCODED";
        uncoded_gbk = byte(206)||byte(180)||byte(177)||byte(224)||byte(194)||byte(235);
        uncoded_utf = byte(230)||byte(156)||byte(170)||byte(231)||byte(188)||byte(150)||byte(231)||byte(160)||byte(129);
        call symputx('uncoded_en', uncoded_en, "L");
        call symputx('uncoded_gbk', uncoded_gbk, "L");
        call symputx('uncoded_utf', uncoded_utf, "L");
    run;

    data ___report_sortway;
        set ___report_sortway;
        by _Varn_ _Vname_ _lvSEQ_ descending pSubj _Vvaluelabeln_;
        if first._Varn_ then _sortwayOrder1_ = 0;
        if first._lvSEQ_ then _sortwayOrder1_ = 0;
        _sortwayOrder1_ + 1;
        
        ** UNCODED Records**;
        array _LevelVarList[*] &LevelVarList.;
        array _uncoded[3] $20 _temporary_ ("&uncoded_en" "&uncoded_gbk" "&uncoded_utf");
        
        do i = 1 to dim(_LevelVarList);
            if strip(upcase(_LevelVarList[i]))=_uncoded[1] or strip(upcase(_LevelVarList[i]))=_uncoded[2] or 
                strip(upcase(_LevelVarList[i]))=_uncoded[3] then do;
                %if "&UncodedPos" = "1" %then %do; _sortwayOrder_ = 0; %end;
                    %else %if "&UncodedPos" = "2" %then %do; _sortwayOrder_ = 999; %end;
                    %else %do; _sortwayOrder_ = _sortwayOrder1_; %end;
                leave;
            end;
            else _sortwayOrder_ = _sortwayOrder1_;
        end;
    run;

    proc sql undo_policy=none;
        create table ___report_out_3 as
            select distinct a.* 
                    %do j = 1 %to &maxLevel.;
                        ,b&j.._sortwayOrder_ as _Order_&j
                    %end;
            from ___report_out_2 as a

            %do j = 1 %to &maxLevel.;
                left join ___report_sortway(where=(_lvSEQ_=&j.)) as b&j. on a._Varn_ = b&j.._Varn_ 
                    %do i = 1 %to &j.; and a._LEVEL_&i. = b&j.._LEVEL_&i. %end;
            %end;

            order by _Varn_ %do j = 1 %to &maxLevel.; ,_Order_&j %end; ,_SubGrpPreOrder_, &SubGrpn. &SubGrpOrder;
    quit;

%EndSortWay:

    **----------------------------*;
    **     Adjust Output Format   *;
    **----------------------------*;
    %if "&SubGrpTotal." = "0" %then %do;
        ** SubGrpTotal = 0, delete SubGrp Total Record **;
        data ___report_out_3;
            set ___report_out_3;
            if &SubGrpn in (-1 0 999) then delete;
        run;
    %end;

    data ___report_out_4;
        length var_seq 8 _Vcompute_ $ 5000 _ltop $2000;
        set ___report_out_3;
        by _Varn_ &OrderList. _SubGrpPreOrder_ &SubGrpOrder &SubGrpn;

        array _LevelVarList[*] &LevelVarList.;

        ** create _ltop & _ltopn;
        %if "%upcase(&SubGrpDisplay.)" = "MERGE" %then %do; ** merge subgrp to ltop;
            if &SubGrpn in (-1 0 999) then do;
                if missing(_lvSEQ_) then _ltop = _Vvaluelabel_;
                    else if _lvSEQ_ = 1 then _ltop = _LevelVarList[_lvSEQ_];
                    else _ltop = repeat("&PreBlank.",_lvSEQ_ - 2)||_LevelVarList[_lvSEQ_];
            end;
            else do;
                if missing(_lvSEQ_) then _ltop = repeat("&PreBlank.",0)||&SubGrp.;
                    else _ltop = repeat("&PreBlank.",_lvSEQ_ - 1)||&SubGrp.;
            end;
        %end;

        %else %do; ** display subgrp value in a separated column;
            if first._Order_&maxLevel. then do;
                if missing(_lvSEQ_) then _ltop = _Vvaluelabel_;
                    else if _lvSEQ_ = 1 then _ltop = _LevelVarList[_lvSEQ_];
                    else _ltop = repeat("&PreBlank.",_lvSEQ_ - 2)||_LevelVarList[_lvSEQ_];
            end;
        %end;

        if _Vcompute_ ^= "" then call missing(_ltop, &SubGrp., of _ngc:);

        if substr(_Vname_,1,5) = "BLANK" then do;
            _ltop = _Vcompute_;
            call missing(_Vcompute_, &SubGrp., of _ngc:);
        end;

        ** Create var_seq for Breakvars= in report5 *;
        retain var_seq 0 ;
        
        %if "&maxLevel"="0" or "&maxLevel"="1" %then %do;
            %** Case 1. AE summary table or MaxLevel=1;
            if first._Varn_ then var_seq = var_seq + 1;
        %end;
        %else %if "&SubGrpFlag"="1" and "%upcase(&SubGrpDisplay.)"^="HEADER" %then %do;
            %** Case 2. SubGroup display in Column or Merge;
            if first._Order_&maxLevel. then var_seq = var_seq + 1;
        %end;
        %else %do;
            %** Case 3. Others;
            if first._Order_1 then var_seq = var_seq + 1;
        %end;

        %** to avoid unexpected blank line after computeline;
    run;

    ** Insert blank line *;
    proc sort data = ___report_out_4;
        by var_seq _Varn_ &OrderList. _SubGrpPreOrder_ &SubGrpOrder &SubGrpn;
    run;
    data ___report_out_5;
        set ___report_out_4;
        by var_seq _Varn_ &OrderList. _SubGrpPreOrder_ &SubGrpOrder &SubGrpn;
        output;
        if last.var_seq and _Vblankline_ = 1 then do;
            call missing(of _character_);
            output;
        end;
    run;

    data ___report_out_6;
        set ___report_out_5;
        array dis_chg(*) $ _ngc:;
        %** Display percent for zero or not *;
        %if %symexist(display_zero_percent) %then %do;
            %if "&display_zero_percent."="0" %then %do;
                do dis_i=1 to dim(dis_chg);
                    dis_chg(dis_i)=prxchange("s/\A0\([[:ascii:]]+\)/0/i",-1,dis_chg(dis_i));
                end;
            %end;
        %end;

        %if %symexist(display_100_percent) %then %do;
            do dis_i=1 to dim(dis_chg);
                dis_chg(dis_i)=prxchange("s/\(100.(0*)\)/(&display_100_percent.)/i",-1,dis_chg(dis_i));
            end;
        %end;
    run;

   

%report:

    **-------------------------------------------------------------*;
    **                        Report                               *;
    **-------------------------------------------------------------*;
	data _null_;
		set ___header_out end=eof;
		where &Groupn. not in (98 99);
		&Groupn.=_n_;
		if eof then call symputx("all_trtn",strip(put(_n_,best.)));
	run;

	data &Outds._sort;
		set ___report_out_6;
				if missing(_ltop) and ^missing(_lvSEQ_) then  _ltop=repeat("&PreBlank.",_lvSEQ_ - 1)||&SubGrp.;
				else if missing(_ltop) then  _ltop=repeat("&PreBlank.",0)||&SubGrp.;
	run;

	data ___SOC_INT_seq;
		length SOC_INT $200;
		SOC_INT="(未编码)" ; SOC_INT_n=28;output;
		SOC_INT="Infections and infestations" ; SOC_INT_n=1;output;
		SOC_INT="Neoplasms benign, malignant and unspecified (incl cysts and polyps)" ; SOC_INT_n=2;output;
		SOC_INT="Blood and lymphatic system disorders" ; SOC_INT_n=3;output;
		SOC_INT="Immune system disorders" ; SOC_INT_n=4;output;
		SOC_INT="Endocrine disorders" ; SOC_INT_n=5;output;
		SOC_INT="Metabolism and nutrition disorders" ; SOC_INT_n=6;output;
		SOC_INT="Psychiatric disorders" ; SOC_INT_n=7;output;
		SOC_INT="Nervous system disorders" ; SOC_INT_n=8;output;
		SOC_INT="Eye disorders" ; SOC_INT_n=9;output;
		SOC_INT="Ear and labyrinth disorders" ; SOC_INT_n=10;output;
		SOC_INT="Cardiac disorders" ; SOC_INT_n=11;output;
		SOC_INT="Vascular disorders" ; SOC_INT_n=12;output;
		SOC_INT="Respiratory, thoracic and mediastinal disorders" ; SOC_INT_n=13;output;
		SOC_INT="Gastrointestinal disorders" ; SOC_INT_n=14;output;
		SOC_INT="Hepatobiliary disorders" ; SOC_INT_n=15;output;
		SOC_INT="Skin and subcutaneous tissue disorders" ; SOC_INT_n=16;output;
		SOC_INT="Musculoskeletal and connective tissue disorders" ; SOC_INT_n=17;output;
		SOC_INT="Renal and urinary disorders" ; SOC_INT_n=18;output;
		SOC_INT="Pregnancy, puerperium and perinatal conditions" ; SOC_INT_n=19;output;
		SOC_INT="Reproductive system and breast disorders" ; SOC_INT_n=20;output;
		SOC_INT="Congenital, familial and genetic disorders" ; SOC_INT_n=21;output;
		SOC_INT="General disorders and administration site conditions" ; SOC_INT_n=22;output;
		SOC_INT="Investigations" ; SOC_INT_n=23;output;
		SOC_INT="Injury, poisoning and procedural complications" ; SOC_INT_n=24;output;
		SOC_INT="Surgical and medical procedures" ; SOC_INT_n=25;output;
		SOC_INT="Social circumstances" ; SOC_INT_n=26;output;
		SOC_INT="Product issues" ; SOC_INT_n=27;output;
	run;
	%if %length(&SocSortWay) > 0 %then %do;
		proc sql undo_policy=none;
		     create table ___TABLE_RTF_SORT1  as
		          select distinct a.*,b.SOC_INT_n
		          from &Outds._sort as a 
		          left join ___SOC_INT_seq as b 
		          on a._LEVEL_1=b.SOC_INT
		;
		quit;
		data ___TABLE_RTF_SORT2;
			set ___TABLE_RTF_SORT1;
			if ^missing(var_seq) then do;
				var_seq=SOC_INT_n;_Order_1=SOC_INT_n;
			end;
		run;
	    proc sort data = ___TABLE_RTF_SORT2 out=&Outds._sort;
	        by var_seq _Varn_ &OrderList. /*_Order_1 _Order_2*/ _SubGrpPreOrder_ &SubGrpOrder /*_SubGrpPreOrder_ */
				&SubGrpn /*_SubGrpN_*/;
	    run;
	%end;
****************************************************************
add pvalue :summary pvalue & soc pvalue
****************************************************************;
%let SqlSubGrp= ;
%if "&SubGrp" = "_SubGrp_" %then %let SubGrp=;;
%if %length(&SubGrp)>0 %then %do;
	%let SqlSubGrp= ,&SubGrp  ;   
%end;
%if &pvaluetype = 1 %then %do;

****************************************************************
add pvalue -summary pvalue
****************************************************************;

data ___ck_AESUMITEM;if _n_=0;run;
proc sort data=___condseq_allgroup(where=( _AESUMITEM_^='' )) out=___ck_AESUMITEM nodupkey;
	by _AESUMITEM_;
quit;
	%if %nobs(___ck_AESUMITEM)>0 %then %do;

	proc sql undo_policy=none;
	     create table ___condseq_allgroup_2_atc_re  as
	          select distinct trtan,trta,_Vvaluelabel_  &SqlSubGrp ,count(unique(&Casevar.)) as count_atc
	          from ___condseq_allgroup(where=(&groupn. not in (98 99) and _AESUMITEM_^='' )) as a 
			  group by trtan,_Vvaluelabel_ &SqlSubGrp
	;
	quit;
	proc sql undo_policy=none;
	     create table ___header_pval  as
	          select distinct a.*,b._Vvaluelabel_ %if %length(&SubGrp)>0 %then %do ;,b.&SubGrp %end;
	          from ___header_out(where=(trtan not in ( 98 99)) keep=trtan trta) as a 
	          left join ___ltop_model(where=(_Vvaluelabel_ not in ( '')) ) as b 
	          on 1
	;
	quit;
	proc sql undo_policy=none;
	     create table ___condseq_allgroup_2_atc  as
	          select distinct a.* ,coalesce(b.count_atc,0) as count_atc 
	          from ___header_pval as a 
	          left join ___condseq_allgroup_2_atc_re as b 
	          on a.trtan=b.trtan and a._Vvaluelabel_=b._Vvaluelabel_  %if %length(&SqlSubGrp)>0 %then %do ;and a.&SubGrp=b.&SubGrp %end;
	;
	quit;
	data ___condseq_allgroup_2_atc1;
		set ___condseq_allgroup_2_atc;
		if trtan=1 then do;
			count_atc_no=&_grp_1-count_atc;
			count_atc_per=count_atc/&_grp_1;
			count_atc_noper=count_atc_no/&_grp_1;
		end;
		if trtan=2 then do;
			count_atc_no=&_grp_2-count_atc;
			count_atc_per=count_atc/&_grp_2;
			count_atc_noper=count_atc_no/&_grp_2;
		end;
		vvalue='Y';
	run;
	data ___condseq_allgroup_2_atc2(rename=(count_atc_noper=count_atc_per count_atc_no=count_atc));
		set ___condseq_allgroup_2_atc1(drop=count_atc_per count_atc);
		vvalue='N';
	run;
	data ___condseq_allgroup_2_atc3;
		set ___condseq_allgroup_2_atc1(drop=count_atc_noper count_atc_no)
		___condseq_allgroup_2_atc2;
	run;
	proc sort data=___condseq_allgroup_2_atc3 ;
		by _Vvaluelabel_ &SubGrp;
	quit;
	            proc freq data=___condseq_allgroup_2_atc3 noprint;
	                by _Vvaluelabel_ &SubGrp;
					weight count_atc;
	                table vvalue * trta/expected outexpect alpha=0.05 sparse chisq fisher nowarn out=___Pvalue_Group_02_Jud_01_1;
	                output out=___Pvalue_Group_03_1(keep=_Vvaluelabel_  &SubGrp N _PCHI_ P_PCHI XP2_FISH) N chisq fisher;
	            quit;
	            %** Add condition: simple size >= 40 and Expected >= 5*;
	            proc sql undo_policy=none;
	                create table ___Pvalue_Group_02_Jud_01_2 as
	                    select distinct _Vvaluelabel_ &SqlSubGrp , sum(COUNT) as SimpleSize, int(min(EXPECTED)) as IntMinExpected
	                    from ___Pvalue_Group_02_Jud_01_1
	                    group by _Vvaluelabel_ &SqlSubGrp;
	            quit;

	            data ___Pvalue_Group_04_1;
	                merge ___Pvalue_Group_03_1 ___Pvalue_Group_02_Jud_01_2;
	                by _Vvaluelabel_ &SubGrp;
	            run;

	            data ___Pvalue_Group_05_1;
	                set ___Pvalue_Group_04_1;
	                length _pvalue_P _Chisquare_ _Fishers_ _ChisquareStat_ $100;

	                %** P-value(ChiSq) *;
					if P_PCHI>.999 then _Chisquare_='>0.999'||" 卡方检验";
					else if .<P_PCHI<.001 then _Chisquare_='<0.001'||" 卡方检验";
	                else if ^missing(P_PCHI) then _Chisquare_=compress(put(P_PCHI,pvalue12.3))||" 卡方检验";
	                %** P-value(Fisher) *;
					if XP2_FISH>.999 then _Fishers_='>0.999'||" Fisher精确概率";
					else if .<XP2_FISH<.001 then _Fishers_='<0.001'||" Fisher精确概率";
	                else if ^missing(XP2_FISH) then _Fishers_=compress(put(XP2_FISH,pvalue12.3))||" Fisher精确概率";
											if .<_PCHI_<.001 then
												_ChisquareStat_='<0.001';
											else if ^missing(_PCHI_) then 	_ChisquareStat_=compress(put(_PCHI_,32.3));

	                %** Select Method;
	                if SimpleSize>=40 and IntMinExpected>=5 then do;
	                    _pvalue_P=coalescec(_Chisquare_,"-");
						S=_ChisquareStat_;
	                end;
	                else do;
	                    _pvalue_P=coalescec(_Fishers_, "-");
						S='-';
	                end;
	            run;
	    data ___Pvalue;
	        set ___Pvalue_Group_05_1 ;
		 	p_value=strip(scan(_pvalue_P,1,''));
			_method=coalescec(strip(scan(_pvalue_P,2,'')),'-');
			s_value=coalescec(s,'-');
	       keep _Vvaluelabel_ &SubGrp p_value _method s_value;
	    run;
	%end;
****************************************************************
add pvalue - soc/pt pvalue
****************************************************************;
	%*put &=LevelVarList_sql ** &=LevelVarList_sort_c ** &=LevelVarList_sql_b ** &=LevelVarList_sql_ab;

data ___ck_socpt;if _n_=0;run;
proc sort data=___condseq_allgroup(where=( _AESUMITEM_='' )) out=___ck_socpt nodupkey;
	by _AESUMITEM_;
quit;
	%if %nobs(___ck_socpt)>0 %then %do;
	proc sql undo_policy=none;
	     create table ___condseq_allgroup_3_atc_re  as
	          select distinct trtan,trta, &LevelVarList_sql. &SqlSubGrp ,count(unique(&Casevar.)) as count_atc
	          from ___condseq_allgroup(where=(&groupn. not in (98 99) and _AESUMITEM_='' )) as a 
			  group by trtan, &LevelVarList_sql. &SqlSubGrp
	;
	quit;
	proc sql undo_policy=none;
	     create table ___header_pval_socpt  as
	          select distinct a.*,&LevelVarList_sql_b. %if %length(&SubGrp)>0 %then %do ;,b.&SubGrp %end;
	          from ___header_out(where=(trtan not in ( 98 99)) keep=trtan trta) as a 
	          left join ___ltop_model(where=( _AESUMITEM_='' )) as b 
	          on 1
	;
	quit;
	proc sql undo_policy=none;
	     create table ___condseq_allgroup_3_atc  as
	          select distinct a.*  ,coalesce(b.count_atc,0) as count_atc 
	          from ___header_pval_socpt as a 
	          left join ___condseq_allgroup_3_atc_re as b 
	          on a.trtan=b.trtan &LevelVarList_sql_ab. %if %length(&SqlSubGrp)>0 %then %do ;and a.&SubGrp=b.&SubGrp %end;
	;
	quit;

	data ___condseq_allgroup_3_atc1;
		set ___condseq_allgroup_3_atc;
		if trtan=1 then do;
			count_atc_no=&_grp_1-count_atc;
			count_atc_per=count_atc/&_grp_1;
			count_atc_noper=count_atc_no/&_grp_1;
		end;
		if trtan=2 then do;
			count_atc_no=&_grp_2-count_atc;
			count_atc_per=count_atc/&_grp_2;
			count_atc_noper=count_atc_no/&_grp_2;
		end;
		vvalue='Y';
	run;
	data ___condseq_allgroup_3_atc2(rename=(count_atc_noper=count_atc_per count_atc_no=count_atc));
		set ___condseq_allgroup_3_atc1(drop=count_atc_per count_atc);
		vvalue='N';
	run;
	data ___condseq_allgroup_3_atc3;
		set ___condseq_allgroup_3_atc1(drop=count_atc_noper count_atc_no)
		___condseq_allgroup_3_atc2;
	run;
	proc sort data=___condseq_allgroup_3_atc3 ;
		by &LevelVarList_sort_c &SubGrp;
	quit;
	            proc freq data=___condseq_allgroup_3_atc3 noprint;
	                by &LevelVarList_sort_c &SubGrp;
					weight count_atc;
	                table vvalue * trta/expected outexpect alpha=0.05 sparse chisq fisher nowarn out=___Pvalue_Group_socpt2_Jud_01_1;
	                output out=___Pvalue_Group_socpt3_1(keep=&LevelVarList_sort_c &SubGrp N _PCHI_ P_PCHI XP2_FISH) N chisq fisher;
	            quit;
	            %** Add condition: simple size >= 40 and Expected >= 5*;
	            proc sql undo_policy=none;
	                create table ___Pvalue_Group_socpt2_Jud_01_2 as
	                    select distinct &LevelVarList_sql &SqlSubGrp, sum(COUNT) as SimpleSize, int(min(EXPECTED)) as IntMinExpected
	                    from ___Pvalue_Group_socpt2_Jud_01_1
	                    group by &LevelVarList_sql &SqlSubGrp;
	            quit;

	            data ___Pvalue_Group_socpt4_1;
	                merge ___Pvalue_Group_socpt3_1 ___Pvalue_Group_socpt2_Jud_01_2;
	                by &LevelVarList_sort_c &SubGrp;
	            run;

	            data ___Pvalue_Group_socpt5_1;
	                set ___Pvalue_Group_socpt4_1;
	                length _pvalue_P _Chisquare_ _Fishers_ _ChisquareStat_ $100;

	                %** P-value(ChiSq) *;
					if P_PCHI>.999 then _Chisquare_='>0.999'||" 卡方检验";
					else if .<P_PCHI<.001 then _Chisquare_='<0.001'||" 卡方检验";
	                else if ^missing(P_PCHI) then _Chisquare_=compress(put(P_PCHI,pvalue12.3))||" 卡方检验";
	                %** P-value(Fisher) *;
					if XP2_FISH>.999 then _Fishers_='>0.999'||" Fisher精确概率";
					else if .<XP2_FISH<.001 then _Fishers_='<0.001'||" Fisher精确概率";
	                else if ^missing(XP2_FISH) then _Fishers_=compress(put(XP2_FISH,pvalue12.3))||" Fisher精确概率";
											if .<_PCHI_<.001 then
												_ChisquareStat_='<0.001';
											else if ^missing(_PCHI_) then 	_ChisquareStat_=compress(put(_PCHI_,32.3));

	                %** Select Method;
	                if SimpleSize>=40 and IntMinExpected>=5 then do;
	                    _pvalue_P=coalescec(_Chisquare_,"-");
						S=_ChisquareStat_;
	                end;
	                else do;
	                    _pvalue_P=coalescec(_Fishers_, "-");
						S='-';
	                end;
	            run;
	    data ___Pvalue_socpt;
	        set ___Pvalue_Group_socpt5_1 ;
		 	p_value=strip(scan(_pvalue_P,1,''));
			_method=coalescec(strip(scan(_pvalue_P,2,'')),'-');
			s_value=coalescec(s,'-');
	       keep &LevelVarList_sort_c &SubGrp p_value _method s_value;
	    run;
	%end;

	data ___Pvalue_set;
		length _Vvaluelabel_ &LevelVarList_sort_c &SubGrp p_value _method s_value  $5000;
		set %if %nobs(___ck_AESUMITEM)>0 %then ___Pvalue;  
				%if %nobs(___ck_socpt)>0 %then ___Pvalue_socpt ; ;
	run;

	data &Outds._sort;
        array dis_chg(*) $5000 _Vvaluelabel_ &LevelVarList_sort_c ;
		set &Outds._sort;
	run;
	%if %nobs(___Pvalue_set)>0  %then %do;
		data &Outds._sort;
			length s_value p_value  _method $2000. ;
		    if _n_=1 then do;
		       declare hash dm(dataset: "___Pvalue_set");
		            dm.defineKey( "_Vvaluelabel_" %if %length(&LevelVarList_sql_m)>0 %then %do;,&LevelVarList_sql_m %end; %if %length(&SubGrp) > 0 %then %do; ,"&SubGrp" %end; );
		            dm.defineData('p_value','_method','s_value');
		            dm.defineDone();
		            call missing(_Vvalue_);
		    end;
		    set &Outds._sort ;
		    rc1 = dm.find();
			p_value=coalescec(p_value,'-');
			_method=coalescec(_method,'-');
			s_value=coalescec(s_value,'-');
		    output;
		run;
	%end;

%end;

	data &Outds.;
		length _text1 _text2 $2000;
		set &Outds._sort;
        %if "&SubSocDesc"="0" %then %do;
			if _SubGrpPreOrder_=. and _lvSEQ_=1 then call missing(of _ngc:);
			else if _SubGrpPreOrder_=1 and _lvSEQ_=1  then delete; 
        %end;
        %else %if "&SubSocDesc"="2" %then %do;
			if _SubGrpPreOrder_=1 and _lvSEQ_=1  then delete; 
        %end;
		_text1=_ltop;
		_text2='n(%)';
		keep _text1 _text2 %do trt_n=1 %to &all_trtn ; _ngc&trt_n._col1  _ngc&trt_n._col2 %end; 
				_ngc99_col1  _ngc99_col2
	        %if %length(&CtGroup.)>0 %then %do;
	            _ngc98_col1  _ngc98_col2
	        %end;
	        %if %length(&pvaluetype.)>0 %then %do;
	            p_value  _method s_value
	        %end;
	;
	run;

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
	** Change _ltop or define some special format for the study *;
        %if %length(&Chgltop.)>0 %then %do;
            %unquote(&Chgltop.)
        %end;
%mend;
