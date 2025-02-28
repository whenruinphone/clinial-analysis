/*************************************************************************************************
File name:      m-sas2xpt-v2-1.sas

Study:          

SAS version:    9.4

Purpose:        transfer sas datasets to xpt file

Macros called:  %nobs %split_string

Notes:          

Parameters:     Refer to UserGuide

Sample:         %m_sas2xpt(datapath=Z:\studies, outpath=Z:\studies\newds);

Date started:   05JUN2019
Date completed: 28JUN2019

**Per QA request, please update the modification history follow the format in the 1st line.**

Mod     Date            Name            Description
---     -----------     ------------    -----------------------------------------------
1.0     05SEP2024       HAO.GUO      create
*********************************** Prepared by Highthinkmed ************************************/

%macro m_sas2xpt(
        XPT_FORMAT   = 
        ,DataPath    = 
        ,OutPath     = 
        ,RefLib      = 
        ,UnifyLength = 
        ,OutEmpty    = 
        ,Cleanup     = 
        ,Type        = 
        ,Debug       = 
    ) / store;

    %put Start Running Macro (&SYSMACRONAME v2.1);

    %**-----------------------------------------------------------------------*;
    %**    Initialization                                                     *;
    %**-----------------------------------------------------------------------*;
    %local _exitcode __globallist __paramlist __locallist __textlist LOG_ERR LOG_WARN _opt_mprint;

    %let __globallist=_forcexpt;

    %let __paramlist=XPT_FORMAT DataPath OutPath RefLib UnifyLength OutEmpty Cleanup Type Debug ;

    %let __locallist=i total ndataset _datasets_list _timestamp;

    %let __textlist=;

    %let _exitcode=0;
    %let LOG_ERR=ERR%str(OR): (&SYSMACRONAME);
    %let LOG_WARN=WARN%str(ING): (&SYSMACRONAME);
    %let _opt_mprint=option %sysfunc(getoption(mprint));

    %local &__locallist &__textlist;

    %** Set default value for GLOBAL macro variables;
    %if %symexist(_forcexpt)=0 %then %let _forcexpt=0;

    %** Set default value for macro PARAMETERS;
    %if %length(&XPT_FORMAT)=0  %then %let XPT_FORMAT  = V5;
    %if %length(&RefLib)=0      %then %let RefLib      = "SDTM" "ADAM";
    %if %length(&UnifyLength)=0 %then %let UnifyLength = 1;
    %if %length(&OutEmpty)=0    %then %let OutEmpty    = 0;
    %if %length(&Cleanup)=0     %then %let Cleanup     = 1;
    %if %length(&Type) = 0      %then %let Type        = NMPA;
    %if %length(&Debug)=0       %then %let Debug       = 0;

    %** Set default value for LOCAL macro variables & standardize macro parameter value;
    %let XPT_FORMAT=%upcase(&XPT_FORMAT);
    %let _timestamp=%sysfunc(datetime(),E8601DT.);

    %** Validate Macro Parameters;
    %if %sysfunc(prxmatch(/^(V5|V8|AUTO|XPORTV5)$/, &XPT_FORMAT))=0 %then %do;
        %put &LOG_ERR Macro Parameter XPT_FORMAT= should be one of the following: V5, V8, AUTO, XPORTV5;
        %let _exitcode=1;
    %end;

    %if %length(&DataPath)=0 %then %do;
        %put &LOG_ERR Macro Parameter DataPath= cannot be null;
        %let _exitcode=1;
    %end;
    %else %if %sysfunc(fileexist(&DataPath))=0 %then %do;
        %put &LOG_ERR Specified directory does not exist [&=DataPath];
        %let _exitcode=1;
    %end;
    %if %length(&OutPath)=0 %then %do;
        %put &LOG_ERR Macro Parameter OutPath= cannot be null;
        %let _exitcode=1;
    %end;
    %else %if %sysfunc(fileexist(&OutPath))=0 %then %do;
        %put &LOG_ERR Specified directory does not exist [&=OutPath];
        %let _exitcode=1;
    %end;

    %if %sysfunc(prxmatch(/^(NMPA|FDA)$/, &Type))=0 %then %do;
        %put &LOG_ERR Macro Parameter Type= should be one of the following: NMPA, FDA;
        %let _exitcode=1;
    %end;

    %if "&_exitcode"^="0" %then %goto EXIT;

    %** Delete Temporary Datasets **;
    proc datasets nolist nowarn lib=work memtype=data;
        delete ___:;
    quit;

    %if "&Debug"="999" %then %do;
        option mprint;
    %end;


    %**-----------------------------------------------------------------------*;
    %**  1. Get Original Metadata                                             *;
    %**-----------------------------------------------------------------------*;

    libname _insas "&DataPath" access=readonly;

    %** dataset encoding against session encoding;
    data ___encoding;
        set sashelp.vtable;
        where libname="%upcase(_insas)";

        encoding_session="&SYSENCODING";
        encoding_dataset=tranwrd(scan(encoding,1," "), "us-ascii", "wlatin1");
        if upcase(encoding_dataset)^=upcase(encoding_session) then do;
            _check=1;
            call symputx("_exitcode", "99", "L");
        end;
        keep memname memlabel nobs encoding: _check;
    run;

    %if "&_exitcode"^="0" %then %do;
        data _check_encoding; set ___encoding; run;
        %put &LOG_ERR Dataset encoding does not match SAS session encoding. Select proper SAS server;
        %goto EXIT;
    %end;

    proc contents noprint data=_insas._all_ 
        out=___content(keep=MEMNAME MEMLABEL NAME TYPE LENGTH VARNUM LABEL FORMAT INFORMAT NOBS) memtype=data;
    run;

    proc sql noprint;
        create table ___content_ds as
            select distinct MEMNAME, MEMLABEL as LABEL, NOBS
            from ___content;
    quit;

    %if %nobs(___content_ds)<=0 %then %do;
        %put &LOG_WARN No dataset to output;
        %goto EXIT;
    %end;

    %** Get variable max actual length;
    %let total=0;
    data _null_;
        set ___content end=lastobs;
        where TYPE=2 and LENGTH>200;
        call symputx("varlmem"||strip(vvalue(_n_)), strip(MEMNAME), "L");
        call symputx("varlvar"||strip(vvalue(_n_)), strip(NAME), "L");
        call symputx("pvarlen"||strip(vvalue(_n_)), strip("1"), "L");
        if lastobs then call symputx("total", strip(vvalue(_n_)), "L");
    run;

    proc sql noprint;
        %do i=1 %to &total;
            select distinct coalesce(max(length(&&varlvar&i)), 1) into: pvarlen&i trimmed
            from _insas.&&varlmem&i(keep=&&varlvar&i);
        %end;
    quit;

    data ___varlen_act;
        length Dataset Variable $50 Length 8;
        call missing(of _all_);
        %do i=1 %to &total;
            Dataset  = "&&varlmem&i";
            Variable = "&&varlvar&i";
            Length   = &&pvarlen&i;
            output;
        %end;
    run;

    %** Update actual length to content;
    proc sql noprint undo_policy=none;
        create table ___content as
            select a.*, b.Length as LENGTH_MAX
            from ___content as a
            left join ___varlen_act as b on a.MEMNAME=b.Dataset and a.NAME=b.Variable
            order by MEMNAME, VARNUM;
    quit;

    %** final output template;
    data ___exportxlsx;
        length LEVEL MEMNAME NAME LABEL FORMAT $256 LENGTH LENGTH_MAX 8
               M_NAME M_LABEL $200 M_LENGTH 8
               DELFL $50 NEEDFL 8 DATAINFO $200;
        call missing(of _all_);
        if _n_=0;
    run;

    data ___exportxlsx;
        set ___exportxlsx 
            ___content_ds(in=a) 
            ___content(in=b keep=MEMNAME NAME LABEL FORMAT LENGTH: VARNUM TYPE);
        if a then LEVEL="DATASET";
        else if b then LEVEL="VARIABLE";
    run;

    %** Derived needfl, M_NAME M_LABEL;
    data ___exportxlsx;
        set ___exportxlsx;

        %** Dataset/Variable Label;
        if length(LABEL)>40 or missing(LABEL) or kindex(LABEL,"<") or kindex(LABEL,">") then needfl=1.1;
            else if ksubstr(LABEL,1,1) in ("1","2","3","4","5","6","7","8","9","0") then needfl=1.2;
            else M_LABEL=LABEL;

        if LEVEL="DATASET" then do;
            if length(MEMNAME)>8 or find(MEMNAME, "_") then needfl=1.3;
                else M_NAME=lowcase(MEMNAME);
        end;

        if LEVEL="VARIABLE" then do;
            if length(NAME)>8 or first(NAME)="_" then needfl=1.4;
                else M_NAME=upcase(NAME);

            %** Required Variables (disabled, not nesscessary for SDTM and ADaM);
            if "1"="0" and NAME in ("STUDYID" "USUBJID" "SUBJID" "VISIT" "VISITNUM") then do;
                if NAME="VISITNUM" and TYPE=2 then needfl=99;
                else if TYPE=1 then needfl=99;

                if LABEL^=symget(cats("lbl_",NAME)) then do;
                    M_LABEL=symget(cats("lbl_",NAME));
                    needfl=2;
                end;
            end;
        end;

        %** variable length restrict 200 bytes for XPT V5;
        if LENGTH>200 and ("&XPT_FORMAT"="V5" or "&XPT_FORMAT"="XPORTV5") then do;
            if LENGTH_MAX>200 then _split=1;
            else if LENGTH_MAX<=200 then _assign=1;
        end;

        %** letter case;
        if LEVEL="VARIABLE" and NAME^=upcase(NAME) then needfl=3;
    run;

    data ___check;
        set ___exportxlsx;
        where ^missing(needfl);
    run;

    %if %nobs(___check)>0 %then %do;
        data _xpt_check; set ___check; run;
        %put &LOG_ERR Some variables are not valid for xpt file. See dataset [_xpt_check];
        %if "&_forcexpt"^="1" %then %goto EXIT;
    %end;


    %**-----------------------------------------------------------------------*;
    %**  2. Calculate the Length within the same Variable Name                *;
    %**-----------------------------------------------------------------------*;

    %** Here is not use the max actual length, it is the defined length by length statement;
    %** So, the macro parameter compress must be Y in %dsoutput;
    data ___columns_;
        length SUPP_DIFF_LEN $64.;
        set sashelp.vcolumn;
        SUPP_DIFF_LEN = "NO";
        %** For suppqual datasets, the allotted length for each column containing character (text) data 
            should be set to the maximum length of the variable used in the individual dataset. in 2022 Mar 
            from STUDY DATA TECHNICAL CONFORMANCE GUIDE by FDA;
        %if %upcase(&type) = FDA %then %do;
            if find(upcase(memname),"SUPP") then SUPP_DIFF_LEN = memname; 
        %end;   
        where memtype="DATA" and type="char" and libname in ("%upcase(_insas)" %upcase(&RefLib)) ;
    run;

    proc sql noprint;
        create table ___varlength_01 as
            select distinct libname,memname,name,length,varnum,label,format,informat,
                    count(name) as count, max(length) as maxlength
            from ___columns_
            group by SUPP_DIFF_LEN,name having count>1
            order by name, length desc;
    quit;

    proc sql noprint;
        create table ___varlength_02 as
            select distinct a.*, _split, _assign
            from ___varlength_01(where=(libname="%upcase(_insas)" and length^=maxlength)) as a
            left join ___exportxlsx(where=(_split=1 or _assign=1)) as b
                on a.memname=b.memname and a.name=b.name
            order by memname, varnum;
    quit;

    data ___varlength_03;
        set ___varlength_02;
        by memname varnum;

        where missing(_split) and missing(_assign); %** which means LENGTH>200 are excluded for V5;
        if maxlength>200 and ("&XPT_FORMAT"="V5" or "&XPT_FORMAT"="XPORTV5") then do;
            %** maxlength=200;
            _max_assign=1;
        end;

        retain _modify_length;
        length _modify_length $5000;
        if first.memname then call missing(_modify_length);

        __tmp=catt(name, " char(", strip(vvalue(maxlength)), ")");
        _modify_length=catx(",", _modify_length, __tmp);

        if last.memname then flag=1;
    run;

    data ___check;
        set ___varlength_03;
        where _max_assign=1;
    run;

    %if %nobs(___check)>0 %then %do;
        data _xpt_check; set ___check; run;
        %put &LOG_ERR Some variables in &RefLib is greater than 200. See dataset [_xpt_check];
        %if "&_forcexpt"^="1" %then %goto EXIT;
    %end;


    %**-----------------------------------------------------------------------*;
    %**  3. Modify Variable Length                                            *;
    %**-----------------------------------------------------------------------*;

    proc sql noprint;
        create table ___modifications as
            select distinct a.*, b1._modify_length, b2._split, b3._assign
            from ___content_ds as a
            left join ___varlength_03(where=(flag=1)) as b1 on a.memname=b1.memname
            left join ___exportxlsx(where=(_split=1)) as b2 on a.memname=b2.memname
            left join ___exportxlsx(where=(_assign=1)) as b3 on a.memname=b3.memname
            order by memname;
    quit;

    data ___modifications;
        set ___modifications end=lastobs;
        libname="%upcase(_insas)";

        if ^missing(_modify_length) and "&UnifyLength"="1" then libname="WORK";
        if ^missing(_split) or ^missing(_assign) then libname="WORK";

        call symputx("_DsLib_"||strip(vvalue(_n_)), strip(libname), "L");
        call symputx("_DsName_"||strip(vvalue(_n_)), strip(memname), "L");
        call symputx("_modify_length_"||strip(vvalue(_n_)), strip(_modify_length), "L");
        if lastobs then call symputx("ndataset", strip(vvalue(_n_)), "L");
    run;

    proc sql noprint;
        select MEMNAME into: _datasets_list separated by ' '
        from ___modifications where libname="WORK";
    quit;

    %** Delete dataset in WORK;
    proc datasets nolist nowarn lib=work memtype=data;
        delete ___XXXX___ &_datasets_list;
    quit;

    data ___compare_result;
        length MEMNAME $32 type $1 batch $257;
        call missing(of _all_);
        if _N_=0;
    run;

    %if "&CleanUp"="1" %then %do;
        data ___xptfile;
            rc=filename("mydir", "&OutPath");
            did=dopen("mydir");
            memcount=dnum(did);
            fname="delfile"; %** cannot use;
            do i=1 to memcount;
                xptfile=dread(did, i);
                rc=filename("delfile", cats("&OutPath","\",xptfile));
                if lowcase(scan(xptfile,-1,"."))="xpt" then rc=fdelete("delfile");
                if lowcase(scan(xptfile,-1,"."))="html" then rc=fdelete("delfile");
                if lowcase(xptfile) in ("changelog.txt", "compare-summary.txt") then rc=fdelete("delfile");
                rc=filename("delfile");
                output;
            end;
            rc=dclose(did);
        run;
    %end;

    %do i=1 %to &ndataset;
        %if "&&_DsLib_&i"^="WORK" %then %goto continue;

        proc datasets nolist lib=_insas memtype=data;
            copy out=work;
            select &&_DsName_&i;
        quit;

        %** XPT V5: Split Varibles for Length Greater than 200;
        data _null_;
            set ___exportxlsx;
            where _split=1 and memname="&&_DsName_&i";

            xcute='%nrstr(%split_string(inds='||strip(memname) 
                    ||', outds=' ||strip(memname)
                    ||', var='||strip(name)||'));';

            call execute(xcute);
        run;

        %** XPT V5: Assigned Varibles for Length Greater than 200;
        data _null_;
            set ___exportxlsx end=lastobs;
            where _assign=1 and memname="&&_DsName_&i";

            retain _assign_length;
            length _assign_length $5000;

            __tmp=catt(name, " char(200)");
            _assign_length=catx(",", _assign_length, __tmp);
            if lastobs then call symputx("_assign_length_&i", strip(_assign_length), "L");
        run;

        %if %symexist(_assign_length_&i)>0 %then %do;
            proc sql noprint;
                alter table &&_DsName_&i
                modify &&_assign_length_&i;
            quit;
        %end;

        %** Unify Variable Length;
        %if %length(&&_modify_length_&i)>0 and "&UnifyLength"="1" %then %do;
            proc sql noprint;
                alter table &&_DsName_&i
                modify &&_modify_length_&i;
            quit;
        %end;

        %** Compare with the original dataset;
        proc datasets nolist nowarn lib=work memtype=data;
            delete ___CompareVariables;
        quit;

        ods html file="%lowcase(&OutPath\&&_DsName_&i...html)";
        ods output CompareVariables = ___CompareVariables;
        %** CompareSummary CompareDatasets CompareDetails CompareDifferences;
        proc compare base = _insas.&&_DsName_&i compare = work.&&_DsName_&i nodate listall
                     out = ___diff outbase outcomp outdif outnoequal
                     criterion=0.000001 method=absolute;
        run;
        ods output close;
        ods html close;

        %if "&SYSINFO"^="16" %then %do; %** 16 means only the length is changed;
            %put &LOG_WARN Check [&&_DsName_&i];
        %end;

        data ___CompareSummary;
            length MEMNAME $32;
            set ___CompareVariables;
            MEMNAME="&&_DsName_&i";
        run;

        proc append base=___compare_result data=___CompareSummary force nowarn;
        run;

    %continue:
    %end;

    %** Export compare result to txt file;
    %if %nobs(___compare_result)>0 %then %do;
        data _null_;
            file "&OutPath\compare-summary.txt" encoding='UTF-8';

            set ___compare_result end=lastobs;
            by MEMNAME notsorted;
            log_msg=repeat("=", 79);

            if _n_=1 then do;
                put "(&SYSMACRONAME) PROC COMPARE Result";
                put "(&SYSMACRONAME) Input Data: &DataPath";
                put "(&SYSMACRONAME) Ouput Data: &OutPath";
                put "(&SYSMACRONAME) &_timestamp";
                put ;
            end;

            if first.MEMNAME then do;
                put ;
                put log_msg;
                put MEMNAME=;
                put log_msg;
                put ;
            end;

            batch=strip(batch);
            batch=prxchange('s/^WORK\./          WORK./', -1, batch);
            reclen=length(batch);
            put batch $varying257. reclen;

            if lastobs then put log_msg;
        run;
    %end;


    %**-----------------------------------------------------------------------*;
    %**    Export Length Changelog to external fiel (.txt)                    *;
    %**-----------------------------------------------------------------------*;

    data ___change_part1;
        set ___exportxlsx;
        where _split=1;

        length changelog $500;
        if _N_=1 then do;
            changelog=repeat("=", 79); output;
            changelog="Variable length is greater than 200, splited into multiple variables:"; output;
            changelog=""; output;
        end;

        changelog = strip(put(_N_,z3.))||"    "||put(cats(memname,".",name), $char20.)
            ||"Actual Length: "||strip(vvalue(LENGTH_MAX));
        output;
    run;

    data ___change_part2;
        set ___exportxlsx;
        where _assign=1;

        length changelog $500;
        if _N_=1 then do;
            changelog=repeat("=", 79); output;
            changelog="Variable length is greater than 200, assigned length as 200:"; output;
            changelog=""; output;
        end;

        changelog = strip(put(_N_,z3.))||"    "||put(cats(memname,".",name), $char20.)
                ||strip(vvalue(length))||" ==> 200    Actual Length: "||strip(vvalue(LENGTH_MAX));
        output;
    run;

    data ___change_part3;
        set ___varlength_03 end=lastobs;
        where "&UnifyLength"="1";

        length changelog $500;
        if _N_=1 then do;
            changelog=repeat("=", 79); output;
            changelog="Variable Length Changed:";output;
            changelog=""; output;
        end;

        changelog = strip(put(_N_,z3.))||"    "||put(cats(memname,".",name), $char20.)
                ||strip(vvalue(length))||" ==> "||strip(vvalue(maxlength));

        output;
    run;

    data ___changelog;
        set ___change_part1 ___change_part2 ___change_part3;
        keep changelog;
    run;

    %if %nobs(___changelog)>0 %then %do;
        data _null_;
            file "&OutPath\changelog.txt" encoding='UTF-8';

            set ___changelog end=lastobs;

            if _N_=1 then do;
                put "(&SYSMACRONAME) Variable Length Change Log";
                put "(&SYSMACRONAME) &_timestamp";
                put ;
            end;

            put changelog;

            if lastobs then do;
                log_msg=repeat("=", 79);
                put log_msg;
            end;
        run;
    %end;

    %if "&Debug"="888" %then %goto EXIT;

    %**-----------------------------------------------------------------------*;
    %**    Tranport to XPT V8 using %LOC2XPT (provided by SAS official)       *;
    %**-----------------------------------------------------------------------*;

    %if "&XPT_FORMAT"="AUTO" or "&XPT_FORMAT"="V8" or "&XPT_FORMAT"="V5" %then %do;
        option nonotes;
        option nomprint;

        data ___modifications;
            set ___modifications;

            argument='%nrstr(%loc2xpt(LIBREF='||strip(libname)||', MEMLIST='||strip(memname)||
                    ", FILESPEC='&OutPath\"||strip(lowcase(memname))||".xpt', FORMAT=&XPT_FORMAT));";

            if nobs>0 or "&OutEmpty"="1" then 
                call execute(argument);
        run;

        option notes;
        &_opt_mprint;
    %end;

    %**-----------------------------------------------------------------------*;
    %**    Tranport to XPT V5 using LIBNAME with XPORT engine                 *;
    %**-----------------------------------------------------------------------*;

    %** Same as LOC2XPT(FORMAT=V5);
    %if "&XPT_FORMAT"="XPORTV5" %then %do;
        %do i=1 %to &ndataset;
            libname _xptout xport "%lowcase(&OutPath\&&_DsName_&i...xpt)";

            proc datasets noprint library=&&_DsLib_&i memtype=data;
                copy out=_xptout;
                select &&_DsName_&i;
            quit;

            libname _xptout clear;
        %end;
    %end;


%EXIT:
    &_opt_mprint;
    %if %sysfunc(libref(_insas))=0 %then libname _insas clear; ;

    data ___vmacros;
        set sashelp.vmacro;
        where scope in ("GLOBAL", "&SYSMACRONAME");
        if prxmatch("/^(%sysfunc(tranwrd(%cmpres(&__paramlist),%str( ),|)))$/i", strip(name)) then _type="parameter";
        if prxmatch("/^(%sysfunc(tranwrd(%cmpres(&__locallist),%str( ),|)))$/i", strip(name)) then _type="local";
        if prxmatch("/^(%sysfunc(tranwrd(%cmpres(&__globallist),%str( ),|)))$/i", strip(name)) then _type="global";
        if prxmatch("/^(%sysfunc(tranwrd(%cmpres(&__textlist),%str( ),|)))$/i", strip(name)) then _type="text";

        if substr(name,1,7) in ("VARLMEM", "VARLVAR", "PVARLEN") then delete;
    run;
    proc sort data=___vmacros;
        by scope _type;
    run;

    %if "&Debug"="0" %then %do;
        proc datasets nolist nowarn lib=work memtype=data;
            delete ___: &_datasets_list;
        quit;
    %end;
%mend;
