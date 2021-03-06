/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 *  to the code in the file.  Don't remove anything that was here initially
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

// indicates the level of nesting for comments
int comment_level = 0;
// string manipulation
int strbuf_idx = 0;
%}

/*
 *  Define names for regular expressions here.
 *  Not in order, but mostly from include/cool-parse.h
 */

WHITESPACE [ \t\v\f\r]*
NEWLINE    \n

ELSE       (?i:else)
IF         (?i:if)
FI         (?i:fi)
IN         (?i:in)
INHERITS   (?i:inherits)
LET        (?i:let)
LOOP       (?i:loop)
POOL       (?i:pool)
THEN       (?i:then)
WHILE      (?i:while)
CASE       (?i:case)
ESAC       (?i:esac)
OF         (?i:of)
NEW        (?i:new)
ISVOID     (?i:isvoid)
INTEGER    [0-9]+
TRUE       t(?i:rue)
FALSE      f(?i:alse)
TYPE_ID    [A-Z][a-zA-Z0-9_]*
OBJECT_ID  [a-z][a-zA-Z0-9_]*

NOT        (?i:not)
CLASS      (?i:class)

DARROW     "=>"
LE         "<="
ASSIGN     "<-"
OPERATORS  [+\-\=*/~<>.,:;(){}@]

COMMENT_BEGIN  "(*"
COMMENT_END    "*)"
COMMENT_LINE   --[^\n]*
COMMENT_BODY 	([^\*\(\n]|\([^\*]|\*[^\)\*])*

/*
 *  States (+ INITIAL)
 *  %s: inclusive, i.e. rules with no start conditions will also be active
 *  %x: exclusive, i.e. rules with no start conditions will not also be active
 */

%x COMMENT
%x STRING

%%

 /*   comments need to be indented from here on; yeah that was obvious O_o
  *  ======================================================================
  *                            RULES SECTION
  *  ======================================================================
  */

 /*
  *  Eat Whitespace
  */

<INITIAL,COMMENT>{NEWLINE} { curr_lineno++; }
{WHITESPACE} { }

 /*
  *  Eat Comments
  */

{COMMENT_LINE} { }
{COMMENT_BEGIN} {
  if (comment_level == 0) BEGIN(COMMENT);
  comment_level++;
}

<COMMENT>{

  {COMMENT_BODY} { }

  <<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in comment";
    return (ERROR);
  }

  {COMMENT_END} {
    comment_level--;
    if (comment_level == 0) BEGIN(INITIAL);
  }

}

{COMMENT_END} {
  cool_yylval.error_msg = "Unmatched *)";
  return (ERROR);
}


<INITIAL>{

   /*
    *  Operators
    *  Single-char operators are represented by themselves
    */

  {OPERATORS} { return (int)(yytext[0]); }
  {ASSIGN}    { return (ASSIGN);         }
  {DARROW}    { return (DARROW);         }

   /*
    * Keywords are case-insensitive except for the values true and false,
    * which must begin with a lower-case letter.
    */

  {ELSE}      { return (ELSE);      }
  {IF}        { return (IF);        }
  {FI}        { return (FI);        }
  {IN}        { return (IN);        }
  {INHERITS}  { return (INHERITS);  }
  {LET}       { return (LET);       }
  {LOOP}      { return (LOOP);      }
  {POOL}      { return (POOL);      }
  {THEN}      { return (THEN);      }
  {WHILE}     { return (WHILE);     }
  {CASE}      { return (CASE);      }
  {ESAC}      { return (ESAC);      }
  {OF}        { return (OF);        }
  {NEW}       { return (NEW);       }
  {ISVOID}    { return (ISVOID);    }
  {NOT}       { return (NOT);       }
  {LE}        { return (LE);        }
  {CLASS}     { return (CLASS);     }

  {INTEGER} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
  }

  {TRUE} {
    cool_yylval.boolean = true;
    return (BOOL_CONST);
  }

  {FALSE} {
    cool_yylval.boolean = false;
    return (BOOL_CONST);
  }

   /*
    * Type and Object IDs (class & variable names)
    * Must be put after keywords so they don't create longer matches.
    */

  {TYPE_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (TYPEID);
  }

  {OBJECT_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (OBJECTID);
  }

}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *  TODO: THIS IS GONNA BE A PAIN
  */

<INITIAL>\" {
  BEGIN(STRING);
}

<STRING>{

  \" {
    BEGIN(INITIAL);
  }

  <<EOF>> {
    cool_yylval.error_msg = "EOF in string constant";
    BEGIN(INITIAL);
    return (ERROR);
  }

  [^\\\"]\n {
    cool_yylval.error_msg = "Unterminated string constant";
    BEGIN(INITIAL);
    return (ERROR);
  }

  (([^\n\0\"])|(\\[ ]*\n))*/\" {
    int string_len = strlen(yytext);
    if(string_len > MAX_STR_CONST)
    {
      cool_yylval.error_msg = "String constant too long";
      return (ERROR);
    }
    string_buf_ptr = yytext;
    strbuf_idx = 0;
    
    while(string_buf_ptr != NULL) {
      char curr_ch = *string_buf_ptr++;
      if(curr_ch==92) {
        curr_ch = *(string_buf_ptr++);
        string_len--;
        if(curr_ch == 98) {
          curr_ch = 8; // backspace ascii
        }
        else if(curr_ch == 116) {
          curr_ch = 9; // horizontal tab ascii
        }
        else if(curr_ch == 110) {
          curr_ch = 10; // newline ascii
        }
        else if(curr_ch == 102) {
          curr_ch = 12; // formfeed ascii
        }
      }
      else if(curr_ch==0) // hit null
        break;

      string_buf[strbuf_idx++] = curr_ch;
      if(strbuf_idx==MAX_STR_CONST-2) {
        break;
      }
    }
    string_buf[strbuf_idx] = 0;
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return (STR_CONST);
  }

}

<INITIAL>. {
  cool_yylval.error_msg = yytext;
  return (ERROR);
}

%%
