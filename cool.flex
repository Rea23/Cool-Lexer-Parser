/*
 *  The scanner definition for COOL.
 */
/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */

%{

#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int cmntsCounter = 0;

%}

/*
 * Define names for regular expressions here.
 */

DIGIT		[0-9]
NUMBER		{DIGIT}+
UPPER_LETTER	[A-Z]
LOWER_LETTER	[a-z]
LETTER		[a-zA-Z_]
TYPE 		{UPPER_LETTER}({LETTER}|{DIGIT})*
OBJECT 		{LOWER_LETTER}({LETTER}|{DIGIT})*
INVALID  	"["|"]"|"#"|"$"|"%"|"&"|"!"|"?"|"^"|"`"|"_"|"|"|[\\]
WHITESPACE 	[ \f\b\t\r]
NEWLINE		[\n]
LINECOMMENT	"--".*
DARROW		"=>"
LE		"<="
ASSIGN		"<-"

%x CMNT
%x STRNG
%x ERR_STRNG

%%

 /*
  *  Nested comments
  */
 /*
  *  The multiple-character operators.
  */

{DARROW}		return DARROW;
{LE}			return LE; 
{ASSIGN}		return ASSIGN; 

(?i:class)		return CLASS;
(?i:else)		return ELSE;
(?i:if)			return IF;
(?i:fi)			return FI;
(?i:in)			return IN;
(?i:inherits)		return INHERITS;
(?i:let)		return LET;
(?i:loop)		return LOOP;
(?i:pool)		return POOL;
(?i:then)		return THEN;
(?i:while)		return WHILE;
(?i:case)		return CASE;
(?i:esac)		return ESAC;
(?i:of)			return OF;
(?i:new)		return NEW;
(?i:isvoid)		return ISVOID;
(?i:not)		return NOT;

f(?i:alse)		{ cool_yylval.boolean = false;
			  return BOOL_CONST;
			}
t(?i:rue)		{ cool_yylval.boolean = true;
			  return BOOL_CONST;
			}

"("			return int('('); 
")"			return int(')'); 
"{"			return int('{');
"}"			return int('}');
"+"			return int('+');
"-"			return int('-');
"*"			return int('*');
"/"			return int('/');
"="			return int('=');
"."			return int('.');
","			return int(',');
";"			return int(';');
":"			return int(':');
"@"			return int('@');
"<"			return int('<');
"~"			return int('~');

{NUMBER}		{ cool_yylval.symbol = inttable.add_string(yytext);
			  return INT_CONST;
			}
 
{TYPE}			{ cool_yylval.symbol = idtable.add_string(yytext);
			  return TYPEID;
			}
{OBJECT}		{ cool_yylval.symbol = idtable.add_string(yytext);
			  return OBJECTID;
			}

{INVALID}		{ cool_yylval.error_msg = yytext;
			  return ERROR;
			}

{WHITESPACE}+		;

{NEWLINE}		curr_lineno++;

{LINECOMMENT}		;

{LINECOMMENT}{NEWLINE}	curr_lineno++;

<INITIAL>"(*"		{ cmntsCounter++;
			  BEGIN(CMNT);
			}

<CMNT>"(*"		cmntsCounter++;

<INITIAL>"*)"		{ cool_yylval.error_msg = "Unmatched *)";
			  return ERROR;
			}

<CMNT>"*)"		{ cmntsCounter--;
			  if(cmntsCounter == 0)
				BEGIN(INITIAL);
			}



<CMNT>\n		curr_lineno++;

<CMNT>{WHITESPACE}+	;

<CMNT>.			;

<CMNT><<EOF>>		{ BEGIN(INITIAL);
			   if(cmntsCounter > 0) {
				cmntsCounter = 0; 
				cool_yylval.error_msg = "EOF in comment";
				return ERROR;
			  }
			}

<INITIAL>\"		{ BEGIN(STRNG);
			  string_buf_ptr = string_buf;
			}


<STRNG>\n		{ curr_lineno++;
			  BEGIN(INITIAL);
			  cool_yylval.error_msg = "Unterminated string constant";
			  return ERROR;
			}

<STRNG><<EOF>>		{ cool_yylval.error_msg = "EOF in string constant";
			  BEGIN(INITIAL);
			  return ERROR;
			}

<STRNG>\"		{ if((string_buf_ptr - string_buf) >= MAX_STR_CONST) {
				string_buf[0] = '\0';
				cool_yylval.error_msg = "String constant too long";
				BEGIN(INITIAL);
				return (ERROR);
			  }
			  *string_buf_ptr = '\0';
			  cool_yylval.symbol = stringtable.add_string(string_buf);
			  BEGIN(INITIAL);
			  return STR_CONST;
			}


<STRNG>\0		{ cool_yylval.error_msg = "Null character in string";
			  BEGIN(ERR_STRNG);
			  return ERROR;
			}

<STRNG>\\\0		{ cool_yylval.error_msg = "String contains escaped null character";
			  string_buf[0] = '\0';
			  BEGIN(ERR_STRNG);
			  return ERROR;
			}

<STRNG>\\n		*string_buf_ptr++ = '\n';
<STRNG>\\t		*string_buf_ptr++ = '\t';
<STRNG>\\f		*string_buf_ptr++ = '\f';
<STRNG>\\b		*string_buf_ptr++ = '\b';

<STRNG>\\[^ntbf]	*string_buf_ptr++ = yytext[1];

<STRNG>.		*string_buf_ptr++ = *yytext;

<ERR_STRNG>\"		BEGIN(INITIAL);

<ERR_STRNG>\n		{ curr_lineno++;
			  BEGIN(INITIAL);
			}

<ERR_STRNG>\\\n		{ curr_lineno++;
			  BEGIN(INITIAL);
			}

<ERR_STRNG>.		;

<INITIAL>.		{ cool_yylval.error_msg = yytext;
			  return ERROR;
			}

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

%%
