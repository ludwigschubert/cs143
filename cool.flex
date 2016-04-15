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

// indicates the number of characters read
int string_length = 0;

/*
 * char* string is pointer to beginning of input string
 * char* string_buf_ptr is assumed to be pointing to write location in string_buf[]
 * int string_length is assumed to be up-to-date with the length of string stored in string_buf[]
 */
bool append_to_string_buf(char* string) {
  if (string == NULL) return false;
  int append_length = strlen(string);
  if (string_length + append_length < MAX_STR_CONST) {
    strcpy(string_buf_ptr, string);
    string_buf_ptr += append_length;
    return true;
  } else {
    return false;
  }
}

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
OPERATORS  [+\-*/~<>.,:;(){}@]

COMMENT_BEGIN  "(*"
COMMENT_END    "*)"
COMMENT_LINE   --[^\n]*
COMMENT_BODY 	([^\*\(\n]|\([^\*]|\*[^\)\*])*

QUOTE               \"
STRING_ESCAPE_SLASH \\
STRING_NULL         \0
STRING_NEWLINE      \n
STRING_BODY         [^\\\n\0]*

ANY_CHAR .

/*
 *  States (+ INITIAL)
 *  %s: inclusive, i.e. rules with no start conditions will also be active
 *  %x: exclusive, i.e. rules with no start conditions will not also be active
 */

%x COMMENT
%x STRING
%x STRING_ESCAPE
%x STRING_OVERFLOW

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
    cool_yylval.error_msg = "Comment was not closed before EOF; comments cannot cross file borders.";
    return (ERROR);
  }

  {COMMENT_END} {
    comment_level--;
    if (comment_level == 0) BEGIN(INITIAL);
  }

}


{COMMENT_END} {
  cool_yylval.error_msg = "Comment was closed outside of a comment";
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

   /*
    *  String constants (C syntax)
    *  Escape sequence \c is accepted for all characters c. Except for
    *  \n \t \b \f, the result is c.
    */

  {QUOTE} {
    string_buf_ptr = string_buf;
    string_length = 0;
    BEGIN(STRING);
    printf("Began string!");
  }

}

<STRING>{

  STRING_ESCAPE_SLASH {
    printf("Found STRING_ESCAPE_SLASH!");
    BEGIN(STRING_ESCAPE);
  }

  STRING_BODY {
    printf("Found STRING BODY: %s", yytext);
    if(!append_to_string_buf(yytext)) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
  }

  /*
   *  Error cases
   */

  STRING_NULL {
    cool_yylval.error_msg = "Unescaped NULL character in string.";
    return (ERROR);
  }

  STRING_NEWLINE {
    cool_yylval.error_msg = "Unescaped Newline in string.";
    return (ERROR);
  }

}

<STRING_ESCAPE>{

  /*
   * TODO: refactor append_to_string_buf to handle these cases?
   */

  STRING_NEWLINE {
    curr_lineno++;
    if(!append_to_string_buf("\n")) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
    BEGIN(STRING);
  }

  n {
    printf("Found newline character!");
    if(append_to_string_buf("\n")) {
      BEGIN(STRING);
    } else {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };

  }

  t {
    if(!append_to_string_buf("\t")) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
    BEGIN(STRING);
  }

  b {
    if(!append_to_string_buf("\b")) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
    BEGIN(STRING);
  }

  f {
    if(!append_to_string_buf("\f")) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
    BEGIN(STRING);
  }

  \\ {
    if(!append_to_string_buf("\\")) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
    BEGIN(STRING);
  }

  . {
    if(!append_to_string_buf(yytext)) {
      BEGIN(STRING_OVERFLOW);
      cool_yylval.error_msg = "String is too long.";
      return (ERROR);
    };
    BEGIN(STRING);
  }

  <<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "String was not closed before EOF; EOFs can not be escaped.";
    return (ERROR);
  }

}

<STRING_OVERFLOW>{
  ANY_CHAR { }
}

<STRING,STRING_OVERFLOW>{

  QUOTE {
    BEGIN(INITIAL);
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return (STR_CONST);

  }

  <<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "String was not closed before EOF; strings cannot cross file borders.";
    return (ERROR);
  }

}

 /*
  *  Catch all other characters
  */

ANY_CHAR {
  cool_yylval.error_msg = yytext;
  return (ERROR);
}

%%
