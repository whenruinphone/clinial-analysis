/*************************************************************************************************
File name:      m-remove-specialchar-v1-0.sas

Study:          

SAS version:    9.4

Purpose:        Remove ASCII 0 < 32 and strip for the char vars

Macros called:  %sdtmspec_&domain.

Notes:          Use warningmsg=0 to qc compare 

Parameters:     warningmsg: display warning msg in log or not    

Sample:         %m_remove_specialchar(inds);

Date started:   13SEP2021
Date completed: 17JUN2022

Mod     Date            Name            Description
---     -----------     ------------    -----------------------------------------------
1.0     28AUG2024       GUOHAO		     create
*********************************** Prepared by Highthinkmed ************************************/
%macro m_remove_specialchar(inds, domain, warningmsg) / store;

    %local Charvars;

    %if %symexist(_domain) and %length(&domain.)=0 %then %let domain=&_domain.;
    %if %length(&warningmsg.)=0 %then %let warningmsg=0;

    %if %length(%qcmpres(&domain.))>0 %then %do;
		data sdtmspec_&domain.;
			set sdtmspec.sdtmspec_&domain.;
		run;

/*%sdtmspec_&domain.;*/
        proc sql noprint;
            select distinct VARNAME into :Charvars separated by ' '
                from sdtmspec_&domain. where strip(upcase(INCLUDE))="Y" and strip(upcase(TYPEODM))="TEXT"
            ;  
        quit;
    %end;
    %else %let Charvars=_character_;
    
    data &inds.;
        set &inds.;
        array c(*) $ &Charvars.;
        do i=1 to dim(c);
            _Vname_=vname(c(i));
            do j=0 to 31;
                length_new1=length(strip(compress(c(i),byte(j))));
                if j=0 then do;
                    %if "&warningmsg."="1" %then %do;
                        if length_new1^=length(strip(c(i))) then put "WAR%str(NING): obs=" _n_ _Vname_ "='" c(i) "', has special characters ASCII " j "has been removed!";
                    %end;
                end;
                else if j>0 then do;
                    %if "&warningmsg."="1" %then %do;
                        if length_new1^=length_new2 then put "WAR%str(NING): obs=" _n_ _Vname_ "='" c(i) "', has special characters ASCII " j "has been removed!";
                    %end;
                end;
                c(i)=strip(compress(c(i),byte(j)));
                length_new2=length(strip(compress(c(i),byte(j))));
            end;
        end;
        drop length_new1 length_new2 _Vname_ i j;
    run;  

%mend;