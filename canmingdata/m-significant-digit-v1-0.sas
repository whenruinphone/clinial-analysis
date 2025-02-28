/*************************************************************************************************
File name:      m-significant-digit-v1-0.sas

Study:          

SAS version:    9.4

Purpose:        Keep significant digits 

Macros called:  

Notes:          Use in data step, do not use in open code

Parameters:     var= Original variable, should be numerical
                prec= Specify the number of significant digit places, should be from 1 to 16
                newvar= Newly variable, will be character
                type= 
                    0 - Do not use scientific notation, integer part will not processed, eg: 22901.3 keep 2 diciaml will be changed to 22901.
                    1 - Use scientific notation, eg: 22901.3 keep 2 diciaml will be changed to 23000. 

Sample:         %m_significant_digit(x1, x1_3, 3, 1);

Date started:   24JUL2019
Date completed: 23OCT2019

Mod     Date            Name            Description
---     -----------     ------------    -----------------------------------------------
1.0     23AUG2023       Hao.Guo     create

************************************ Prepared by GCP Highthinkmed  ************************************/

%macro m_significant_digit(var, newvar, prec, type) / minoperator store;

    %** Check the legality of the parameters ;
    %if %sysfunc(prxmatch(%str(#^[_a-zA-Z]\w{0,31}$#), %qcmpres(&var.)))=0 %then %do;
        %put ERR%str(OR:) (&SYSMACRONAME.) Variable name is illegal, please check parameter var!;
        %goto exit;
    %end;
    %if %sysfunc(prxmatch(%str(#^[_a-zA-Z]\w{0,31}$#), %qcmpres(&newvar.)))=0 %then %do;
        %put ERR%str(OR:) (&SYSMACRONAME.) Variable name is illegal, please check parameter newvar!;
        %goto exit;
    %end;
    %if "&prec." in "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" %then %do;
    %end;
    %else %do;
        %put ERR%str(OR:) (&SYSMACRONAME.) The value of parameter prec should be ge 1 and le 16, please check!;
        %goto exit;
    %end;
    %if %length(&type.)=0 %then %let type=0;

    length &newvar &var._df $32.;
    &var._power_=.; /** Solved when type=0 & type=1 in the same data step for the same var */

    if ^missing(&var.) then do;
        %**------------------------------------------------------------------------------
            1: If greater than 1
                a): If the integer part is greater than prec, the format is 32.0
                b): If the integer part is smaller than prec, the format is 32.(prec-W), 
                    W is the integer part digit
            2: If less than 1, the fractional part is positioned to the first digit that 
                is not 0, the format is 32.(prec+D)
            3: type=1 then use scientific notation keep effective number of decimal places
        --------------------------------------------------------------------------------;
        %if "&type."="1" %then %do;
            if lengthn(scan(put(abs(&var.),32.16-l),1,'.'))>=&prec. then do;
                &var._power_=lengthn(scan(put(abs(&var.),32.16-l),1,'.'))-1;
                &var.=&var./(10**&var._power_);
            end; 
        %end;

        if abs(&var.)>=1 then do;
            if lengthn(scan(put(abs(&var.),32.16-l),1,'.'))>=&prec. then &var._df="32.0";
            else &var._df="32."||strip(put(&prec.-lengthn(scan(put(abs(&var.),32.16-l),1,'.')),best.));
        end;
        else do;
            &var._df="32."||strip(put(&prec.+findc(scan(put(abs(&var.),32.16-l),2,'.'),"123456789")-1,best.));
        end;
        &newvar.=strip(putn(&var.,&var._df));

        %**------------------------------------------------------------------------------
            1: If there is a rounding, need remove the trailing '0',
               eg: 0.0999 to 0.1000, 0.1000 should change to 0.100
            2: If remove the trailing '0' then the '.' is the trailing than should be remove,
               eg: 99.995 to 100.0, remove the trailing '0' is 100. than should be remove
               the trailing '.'.
        --------------------------------------------------------------------------------;
        if findc(&newvar.,'.') and findc(&newvar.,'123456789') then do;
            if lengthn(substr(compress(&newvar.,'-.'),findc(compress(&newvar.,'-.'),"123456789")))=&prec.+1 
                and substr(strip(reverse(strip(compress(&newvar.,'-.')))),1,1)='0' then do;
                &newvar.=strip(substr(&newvar.,1,lengthn(&newvar.)-1));
            end; 
        end;
        if substr(strip(reverse(&newvar.)),1,1)="." then &newvar.=strip(substr(&newvar.,1,lengthn(&newvar.)-1));

        if ^missing(&var._power_) then do;
            &newvar.=put(input(&newvar.,best32.)*(10**&var._power_),best32.-l);
            &var.=&var.*(10**&var._power_);
        end;

        %** Check &newvar. *;
        if abs(&var.)>0 then do;
            if lengthn(substr(&newvar.,findc(&newvar.,"123456789"),&prec.))^=&prec. then
            put "ERROR: Obs=" _n_ ", &var.=" &var. ", &newvar.="  &newvar. ", significant digit places not eq to &prec., please check!";  
        end;
    end;
    drop &var._df &var._power_;

    %exit:
%mend;