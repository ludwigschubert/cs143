ASSN = 1
CLASS= cs143
CLASSDIR= /afs/ir/class/cs143
LIB= -lfl

SRC= cool.flex test.cl README 
CSRC= lextest.cc utilities.cc stringtab.cc handle_flags.cc
TSRC= mycoolc
HSRC= 
CGEN= cool-lex.cc
HGEN=
LIBS= parser semant cgen
CFIL= ${CSRC} ${CGEN}
LSRC= Makefile
OBJS= ${CFIL:.cc=.o}
OUTPUT= test.output

CPPINCLUDE= -I. -I./include -I./src

FFLAGS= -d -ocool-lex.cc

CC=g++
CFLAGS= -g -Wall -Wno-unused -Wno-write-strings ${CPPINCLUDE}
FLEX=flex ${FFLAGS}
DEPEND = ${CC} -MM ${CPPINCLUDE}

lexer: ${OBJS}
	${CC} ${CFLAGS} ${OBJS} ${LIB} -o lexer

${OUTPUT}:	lexer test.cl
	@rm -f test.output
	-./lexer test.cl >test.output 2>&1 

cool-lex.cc: cool.flex 
	${FLEX} cool.flex

dotest:	lexer test.cl
	./lexer test.cl

submit: lexer
	$(CLASSDIR)/bin/pa_submit PA1 .

clean:
	rm -f lexer ${OBJS} cool-lex.cc

# build rules

%.o : %.cc
	${CC} ${CFLAGS} -c $< -o $@

%.o : src/%.cc
	${CC} ${CFLAGS} -c $< -o $@

# extra dependencies 
