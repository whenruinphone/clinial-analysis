%macro Separate_param(varlist = 
              ,separators = 
                 ,amounts = 
                   ,outds = _varlist
                    ,debug = ) / store;


%**************;
%** initialize ;
%**************;

     proc datasets nolist nodetails NoWarn lib=work;
        delete __separated: /memtype=data;
    quit; 

    %local i j nseparators separator0;
    %if %length(&varlist.)=0 %then %goto exit;
    %if %length(&separators.)=0 %then %goto exit;
    %if %length(&outds.)=0 %then %let outds=_varlist;

%******************;
%** get separators ;
%******************;

    %let i=1;
    %do %while(%qscan(%nrbquote(&separators.),&i.,%str( ))^=%str());
            %local separator&i. amount&i.;
            %let separator&i.=%qscan(%nrbquote(&separators.),&i.,%str( ));
            %let amount&i.=%qscan(%nrbquote(&amounts.),&i.,%str( ));
        %let i=%eval(&i.+1);
    %end;
    %let nseparators=%eval(&i.-1);

%***********************************************;
%** change the %/ to be $&i.* before separating ;
%** change // to / / ;
%***********************************************;

    data &outds.;
        length separator $50 value0 value $32767.;
        separator="";
        value0="%nrbquote(&varlist.)";
        %do i=1 %to &nseparators.;
            value0=tranwrd(value0,"%"||"&&separator&i..","*$&i.*");
            value0=tranwrd(value0,"&&separator&i..&&separator&i..","&&separator&i.. &&separator&i..");
            value0=tranwrd(value0,"&&separator&i..&&separator&i..","&&separator&i.. &&separator&i..");
        %end;
        value=value0;
    run;


%**********************************************************************;
%** loop, separate character base on pervious separated character ;
%**********************************************************************;

    %let separator0=;
    %do i=1 %to &nseparators.;
        %let j=%eval(&i.-1);
        data &outds. %if &debug.>0 %then __separated&i.; ;
            set &outds.;
            order&i.=.;
            output;
            if separator="&&separator&j.." then do;
                separator="&&separator&i..";
                _amount=&&amount&i..;
                if _amount<=0 then _amount=count(value0,strip(separator))+1;
                do i=1 to _amount;
                    order&i.=i;
                    value=scan(value0,i,strip(separator));
                    output;
                end;
                drop _amount;
            end;
        run;
        data &outds.;
            set &outds.;
            value0=value;
        run;
    %end;

%***********************************************;
%** change back the $&i.* to / after separating ;
%***********************************************;

    data &outds.;
        set &outds.;
        drop value0 i;
        %do i=1 %to &nseparators.;
            value=tranwrd(value,"*$&i.*","&&separator&i..");
        %end;
    run;

    proc sort data = &outds.;
        by %do i=1 %to &nseparators.; order&i. %end;;
    run;

    %if &Debug<1 %then %do;
         proc datasets nolist nodetails NoWarn lib=work;
            delete __separated:
                /memtype=data;
        quit; 
    %end;

%exit:
%mend;