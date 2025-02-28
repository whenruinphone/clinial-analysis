/*************************************************************************************************
File name: m-var-exist-v1-0.sas

Study:

SAS version: 9.4

Purpose: return 0 if a variable exists in a dataset
return 1 if a variable does not exist in a dataset

Macros called:

Notes:

Parameters:

inds=
Specifies the input data set.
Required.
varname=
Specifies the variable name.
Required.

Sample: %m_var_exist(data,var_length);

Date started: 13JUL2023
Date completed: 13JUL2023

**Per QA request, please update the modification history follow the format in the 1st line.**

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 13JUL2023 hao.guo create
************************************ Prepared by Highthinkmed ************************************/

%macro m_var_exist(inds /** dataset name */
,varname /** variable name need verify */
) / store;

%local errnum errmsg;
%let errnum = 0;
/**-----------------------------------------
verify macro paramerers
------------------------------------------*/
%if %length(&inds) eq 0 or %length(&varname) eq 0 %then %do;
%let errnum = 1;
%let errmsg = macro parameters(inds varname) can not be null;
%goto mexit;
%end;

%if %sysfunc(exist(&inds)) %then %do;
%let dsid = %sysfunc(open(&inds, i));
%let varnum = %sysfunc(varnum(&dsid, &varname));
%let rc = %sysfunc(close(&dsid));
&varnum
%end;
%else %do;
%let errnum = 1;
%let errmsg = data set (&inds) does not exist;
%goto mexit;
%end;

%mexit:
%if &errnum %then %do;
%put ERROR: &errmsg;
%put ERROR: exist macro(m_var_exist) because of error;
%end;

%mend m_var_exist;
