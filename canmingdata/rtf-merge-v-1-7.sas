/*************************************************************************************************
File name: rtf_merge-v1-7.sas

Study:

SAS version: 9.4

Purpose: merge rtf

Macros called: 

Notes:
	1.需要调用table._title_footnote数据集，此数据集通常在项目中生成，也可通过以下参考路径的模板和代码生成
		_title_footnote参考路径 Z:\_SAS_macro_develop\tools\merge_rtf\_title_footnote

		数据集包含以下4个变量 MainTitle,TitleNo,Type,ProgramName
		MainTitle为标题名称，如“入组情况”
		TitleNo为标题序号，如“表14.1.2.1”
		Type为TFL类型，如“table”、“figure”、“listing”
		ProgramName为TFL文件名，如“table14_1_2_1”
	2.TFL生成figure时，请不要生成导航，否则使用本宏后，图部分会有双重导航。因为本宏会重新生成导航。

Parameters: 
	FilePath  - 需要合并的文件路径，请参考Sample例子修改填写
	Mergefile - 合并后的文件路径路径及文件名，请参考Sample例子修改填写
	Encoding  - 编码环境，默认为中文简体，填任意值代表为U8

Sample: 

	Sample1 euc-cn  Simplified Chinese (EUC) encoding 
	%rtf_merge(
	FilePath=%nrstr('dir "Z:\_SAS_macro_develop\tools\merge_rtf\split2c\*.rtf" /b/s')
	,Mergefile=%str(Z:\_SAS_macro_develop\tools\merge_rtf\app_merge.rtf)
	,encoding=);

	Sample2 UTF8 encoding 
	%rtf_merge(
	FilePath=%nrstr('dir "Z:\_SAS_macro_develop\tools\merge_rtf\testu8\*.rtf" /b/s')
	,Mergefile=%str(Z:\_SAS_macro_develop\tools\merge_rtf\u8_merge.rtf)
	,encoding=1);


Date started: 18FEB2025

Date completed: 18FEB2025

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0  18FEB2025 Hao.Guo create
1.1  24FEB2025 Hao.Guo add seq 
1.2  24FEB2025 Hao.Guo 增加U8文件合并，未成功 
1.3  26FEB2025 Hao.Guo 数据集不叠加，修改为最后set到一起，提升效率 
1.4  27FEB2025 Hao.Guo 增加U8文件合并,增加Encoding=，默认值为中文简体，填任何值则作U8处理 
1.5  27FEB2025 Hao.Guo 简化参数 
1.6  27FEB2025 Hao.Guo 调整页码相关代码，使页码正确 
1.7  27FEB2025 Hao.Guo 添加相关检查 
*********************************** Prepared by Highthinkmed ************************************/


%macro   rtf_merge(FilePath=,Mergefile=,Encoding=) / store;
	%let ps1=800;
	%let ls1=256;
	%let pageyn=0;
	%let Indexyn=1;
	%let Indextitle=1;
	%if %length(&Encoding) = 0 %then %do;
		%let bkmk={\*\bkmkstart IDX}{\*\bkmkend IDX};
	%end;
	%else %do;
		%let bkmk={\upr{\*\bkmkstart IDX}{\*\ud{\*\bkmkstart IDX}}}{\*\bkmkend IDX};
	%end;
	options ps=&ps1 ls=&ls1  notes  source source2   ;
	skip 5;
	*获取指定路径下文件夹下RTF文件名称;
	filename xcl_fil pipe &FilePath.; 
	data add_rtflist;
	   infile xcl_fil truncover;
	   input fname $char1000.;
		_seq=tranwrd(tranwrd(kscan(fname,-1,'\'),'.rtf',''),'.RTF','');
		_seqc=strip(compress(_seq,'_','kd'));
		array aaa(9)  _seqc_1-_seqc_9;
		do i=1 to 9;
			aaa(i)=input(scan(_seqc,i,'_'),best.);
		end;
	run;
	*默认以文件名进行升序排别;
	proc sort data=add_rtflist  out=add_rtflist1  sortseq=linguistic(numeric_collation=on);by _seqc_: ;quit;

	*20191231 新增索引功能：分离文件名，将变量转化成RTF编码;
	****************************************************************
	add title footnote tempindexname
	****************************************************************;
	data add_rtflist1_1;
		set add_rtflist1;
		_tempindexname=tranwrd(tranwrd(kscan(fname,-1,'\'),'.rtf',''),'.RTF','');
	run;
	data _title_footnote;
		set table._title_footnote;
		where ProgramName^='';
	run;
	proc sql undo_policy=none;
	     create table add_rtflist1_2  as
	          select distinct a.*,b.MainTitle,b.TitleNo,b.type,b.ProgramName
	          from add_rtflist1_1 as a 
	          left join _title_footnote as b 
	          on lowcase(a._tempindexname)=lowcase(b.ProgramName)
	;
	quit;
	** 检查_title_footnote中有merge所需的所有tfl：;
	data add_rtflist1_2_ck1;
	set add_rtflist1_2;
		where ProgramName='';
	run;
	%if %nobs(add_rtflist1_2_ck1) > 0 %then %do;
				%put ERR%str(OR): _title_footnote.xls中没有merge所需的所有tfl, 请查看 add_rtflist1_2_ck1 数据集!!!;
				%goto exit;
	%end;
	data add_rtflist1_3;
		set add_rtflist1_2;
		MainTitle_dh=strip(TitleNo)||' '||strip(MainTitle);
		if lowcase(type)='table' then type_seq=1;
		else if lowcase(type)='figure' then type_seq=2;
		drop i ;
	run;
	%if %length(&Encoding) = 0 %then %do;
	data add_rtflist1_4;
		set add_rtflist1_3;
		do loop=1 to  klength(MainTitle_dh) ;
			y=compress(put(ksubstr(MainTitle_dh,loop,1),hex16.));
			if klength(Y)=4 then Y=strip("\'")||strip(substr(compress(Y),1,2))||strip("\'")||strip(substr(compress(Y),3,2));
			else if klength(Y)=2 then Y=strip("\'")||strip(compress(Y));
			output;
		end;
	run;
	****************************************************************
	add title footnote tempindexname end
	****************************************************************;
	proc sort data=add_rtflist1_4 out=add_rtflist1_5;
		by  _seqc_: type_seq;
	quit;
	data add_rtflist1_6;
		length z $3000.;
		set add_rtflist1_5;
		retain z;
		by  _seqc_: type_seq notsorted;
		if first.type_seq then z=Y;
		else z=compress(z||Y);
		if last.type_seq then output;
	run;
	%end;
	%else %do;
	data add_rtflist1_6;
		set add_rtflist1_3;
		z=tranwrd(unicodec(MainTitle_dh,"ncr"),'&#','\u');
	run;
	%end;

	*设置索引;
	data add_rtflist1_7;
		length z $3000;
		set add_rtflist1_6;
		%if &indexyn. eq 1 %then %do;
		z="&bkmk.\pard\i0\chcbpat8\chcfpat8\ql\f1\fs0\cf8\outlinelevel1{"||compress(z)||"}\cf8\chcbpat8\par";
		%end;
		%if &indexyn. ne 1 %then %do;
		z="&bkmk.";
		%end;
	run;


	*定义filename定义路径便于合并;
	data _null_;
		set add_rtflist1_7  end=last;
	   	rtffn=strip("filename rtffn")||strip(_N_)||right(' "')||strip(fname)||strip('" lrecl=5000 ;');
	   	call execute(rtffn);
		call symput('ard_rtf'||compress(put(_n_,best.)),strip(fname));
		call symput('ind_rtf'||compress(put(_n_,best.)),strip(z));
		if last then call symputx('maxn',vvalue(_n_));
	run;
		skip 3;

%do i=1 %to &maxn.;
/*将文件导入SAS中，变成SAS数据集*/
%put  即将完成对文件：&&ard_rtf&i. 的合并！;

	data have&i. ;
		infile rtffn&i.  truncover;
		informat line $5000.;format line $5000.;length line $5000.;input line $1-5000;
		line=strip(line);
		z="&&ind_rtf&i.";
		if index(line,"&bkmk.") then line=tranwrd(line,"&bkmk.",z);
		drop z;
	run;

	*针对所以title;
	%if &Indextitle. eq 1 %then %do;
		data have&i.;
			set have&i.;
			retain fgs 0;
			if index(line,'\pard\plain\b\sb0\sa0\ql\f1\fs19\cf1{') then fgs=1+fgs;
			if fgs=1 then  line=tranwrd(line,'{\plain\tc\v\f1\fs22\b0\i0 ','{\plain\tc\v\f1\fs22\b0\i0 \outlinelevel1\');
		run;
	%end;
/*实现三个处理过程：
		1.除首个RTF外，其他RTF第一行的“{”要删除。
		2.除最后一个RTF外，其他RTF最后一行的“}”要删除。
		3.在每个俩个RTF编码间插入一行。这样一行放下面一串代码。
		\sect\sectd\linex0\endnhere\pgwsxn15840\pghsxn12240\lndscpsxn\headery1440\footery1440\marglsxn1440\margrsxn1440\margtsxn1440\margbsxn1440
*/
	%if  &i. eq 1 %then %do;
		data have1;
			set have1 end=last;
			
			if last and line^='}' then line=substr(strip(line),1,length(strip(line))-1);
			else if last and line='}' then delete;
		run;
	%end;
	%if  &i. ne 1 %then %do;
	%let ide=%sysevalf(&i - 1);
		proc sql;

		insert into have&ide.(line) values ('\sect\sectd\linex0\endnhere\pgwsxn15840\pghsxn12240\lndscpsxn\headery1440\footery1440\marglsxn1440\margrsxn1440\margtsxn1440\margbsxn1440');
		quit;
		data have&i.;
			set have&i. end=last;
			if last and line^='}' then line=substr(strip(line),1,length(strip(line))-1);
			else if last and line='}' then delete;
			if _n_=1 then line=substr(line,2);
		run;
		%if  &i. eq &maxn. %then %do;
		data have&i.;
			set have&i. end=last;
			if last then line=strip(line)||strip("}");
		run;
		%end;
	%end;
%end;
	data want;
		set have1-have&maxn.;
	run;

%put  已完成所有文件的合并！;
/*文件输出成合并完成后的RTF*/
data want;
	set want;
	line=tranwrd(line,'\sect\sectd\linex0\endnhere\sbknone\pgwsxn16837\pghsxn11905\lndscpsxn\headery720\footery1440\marglsxn1440\margrsxn1440\margtsxn720\margbsxn1440','');
	line=tranwrd(line,'}\par}{\page\par}','}}{\page}');
	line=tranwrd(line,'\pard{\par}{\pard\plain\qc{','\pard{}{\pard\plain\qc{');
	line=tranwrd(line,'}\par}','}}');
	if index(line,'\pgnrestart\') then line=compress(tranwrd(line,'\pgnrestart',' '));
run;

	data _null_;
	   set want;
	   file "&Mergefile." lrecl=5000 ;
	   put line ;
	run;
%exit:

%mend;


