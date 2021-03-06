/*
 [The "BSD licence"]
 Copyright (c) 2005-2007 Terence Parr
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote products
    derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/** ANTLR v3 grammar written in ANTLR v3 with AST construction */
grammar ANTLRv3Grammar;

options {
  ASTLabelType = CommonTree;
  language = Ruby;
  output = AST;
}

tokens {
	DOC_COMMENT;
	PARSER;	
  LEXER;
  RULE;
  BLOCK;
  OPTIONAL;
  CLOSURE;
  POSITIVE_CLOSURE;
  SYNPRED;
  RANGE;
  CHAR_RANGE;
  EPSILON;
  ALT;
  EOR;
  EOB;
  EOA; // end of alt
  ID;
  ARG;
  ARGLIST;
  RET='returns';
  LEXER_GRAMMAR;
  PARSER_GRAMMAR;
  TREE_GRAMMAR;
  COMBINED_GRAMMAR;
  LABEL; // $x used in rewrite rules
  TEMPLATE;
  SCOPE='scope';
  SEMPRED;
  GATED_SEMPRED; // {p}? =>
  SYN_SEMPRED; // (...) =>   it's a manually-specified synpred converted to sempred
  BACKTRACK_SEMPRED; // auto backtracking mode syn pred converted to sempred
  FRAGMENT='fragment';
  TREE_BEGIN='^(';
  ROOT='^';
  BANG='!';
  RANGE='..';
  REWRITE='->';
  AT='@';
  LABEL_ASSIGN='=';
  LIST_LABEL_ASSIGN='+=';
}

@members {
	attr_reader :grammar_type
}

grammar_def
    : DOC_COMMENT?
      ( h=grammar_head { top = $h.tree }
      | {
          @grammar_type = COMBINED_GRAMMAR
          top = @adaptor.create( @grammar_type, 'grammar' )
          name_node = @adaptor.create( ID, '<unknown>' )
          @adaptor.add_child( top, name_node )
        }
      )
      options_spec? tokens_spec? attr_scope* action*
    	rule*
    	EOF
    -> ^( { top } DOC_COMMENT? options_spec? tokens_spec? attr_scope* action* rule* )
    ;

grammar_head
    : DOC_COMMENT?
    	(	'lexer'  { @grammar_type = LEXER_GRAMMAR }    // pure lexer
    	| 'parser' { @grammar_type = PARSER_GRAMMAR } // pure parser
    	| 'tree'   { @grammar_type = TREE_GRAMMAR }    // a tree parser
    	|		       { @grammar_type = COMBINED_GRAMMAR } // merged parser/lexer
    	)
    	g='grammar' n=id ';'
    -> ^( { @adaptor.create( @grammar_type, $g ) } $n )
    ;

tokens_spec
	:	TOKENS token_spec+ '}' -> ^(TOKENS token_spec+)
	;

token_spec
	:	TOKEN_REF
		(	'=' (lit=STRING_LITERAL|lit=CHAR_LITERAL)	-> ^('=' TOKEN_REF $lit)
		|												-> TOKEN_REF
		)
		';'
	;

attr_scope
	:	'scope' id ACTION -> ^('scope' id ACTION)
	;

/** Match stuff like @parser::members {int i;} */
action
	:	'@' (action_scope_name '::')? id ACTION -> ^('@' action_scope_name? id ACTION)
	;

/** Sometimes the scope names will collide with keywords; allow them as
 *  ids for action scopes.
 */
action_scope_name
	:	id
	|	l='lexer'	  -> ID[$l]
  | p='parser'	-> ID[$p]
	;

options_spec
	:	OPTIONS (option ';')+ '}' -> ^(OPTIONS option+)
	;

option
    :   id '=' option_value -> ^('=' id option_value)
 	;
 	
option_value
    :   qid
    |   STRING_LITERAL
    |   CHAR_LITERAL
    |   INT
    |	s='*' -> STRING_LITERAL[$s]  // used for k=*
    ;

rule
scope {
  name;
}
	:	DOC_COMMENT?
		( modifier=('protected'|'public'|'private'|'fragment') )?
		id { $rule::name = $id.text }
		'!'?
		( arg=ARG_ACTION )?
		( 'returns' rt=ARG_ACTION  )?
		throws_spec? options_spec? rule_scope_spec? rule_action*
		':'	alt_list	';'
		exception_group?
	    -> ^( RULE id {$modifier ? @adaptor.create($modifier) : nil} ^(ARG[$arg] $arg)? ^('returns' $rt)?
	    	  throws_spec? options_spec? rule_scope_spec? rule_action*
	    	  alt_list
	    	  exception_group?
	    	  EOR["EOR"]
	    	)
	;

/** Match stuff like @init {int i;} */
rule_action
	:	'@' id ACTION -> ^('@' id ACTION)
	;

throws_spec
	:	'throws' id ( ',' id )* -> ^('throws' id+)
	;

rule_scope_spec
	:	'scope' ACTION -> ^('scope' ACTION)
	|	'scope' id (',' id)* ';' -> ^('scope' id+)
	|	'scope' ACTION
		'scope' id (',' id)* ';'
		-> ^('scope' ACTION id+ )
	;

block
    :   lp='('
		( (opts=options_spec)? ':' )?
		altpair ( '|' altpair )*
        rp=')'
        -> ^( BLOCK[$lp,"BLOCK"] options_spec? altpair+ EOB[$rp,"EOB"] )
    ;

altpair : alternative rewrite ;

alt_list
@init {
  block_root = @adaptor.create(BLOCK, @input.look(-1), "BLOCK");
}
    :   altpair ( '|' altpair )* -> ^( {block_root} altpair+ EOB["eob"] )
    ;

alternative
@init {
	first_token = @input.look(1)
	prev_token = @input.look(-1)
}
    :   element+ -> ^(ALT[first_token,"ALT"] element+ EOA["EOA"])
    | -> ^(ALT[prev_token,"ALT"] EPSILON[prev_token,"EPSILON"] EOA["EOA"])
    ;

exception_group
	:	( exception_handler )+ ( finally_clause )?
	|	finally_clause
  ;

exception_handler
  : 'catch' ARG_ACTION ACTION -> ^('catch' ARG_ACTION ACTION)
  ;

finally_clause
  : 'finally' ACTION -> ^('finally' ACTION)
  ;

element
	:	id (labelOp='='|labelOp='+=') atom
		(	ebnf_suffix	-> ^( ebnf_suffix ^(BLOCK["BLOCK"] ^(ALT["ALT"] ^($labelOp id atom) EOA["EOA"]) EOB["EOB"]))
		|				-> ^($labelOp id atom)
		)
	|	id (labelOp='='|labelOp='+=') block
		(	ebnf_suffix	-> ^( ebnf_suffix ^(BLOCK["BLOCK"] ^(ALT["ALT"] ^($labelOp id block) EOA["EOA"]) EOB["EOB"]))
		|				-> ^($labelOp id block)
		)
	|	atom
		(	ebnf_suffix	-> ^( ebnf_suffix ^(BLOCK["BLOCK"] ^(ALT["ALT"] atom EOA["EOA"]) EOB["EOB"]) )
		|				-> atom
		)
	|	ebnf
	|   ACTION
	|   SEMPRED ( g='=>' -> GATED_SEMPRED[$g] | -> SEMPRED )
	|   tree_spec
		(	ebnf_suffix	-> ^( ebnf_suffix ^(BLOCK["BLOCK"] ^(ALT["ALT"] tree_spec EOA["EOA"]) EOB["EOB"]) )
		|				-> tree_spec
		)
	;

atom:   terminal
	|	range 
		(	(op='^'|op='!')	-> ^($op range)
		|					-> range
		)
    |	not_set
		(	(op='^'|op='!')	-> ^($op not_set)
		|					-> not_set
		)
    |   RULE_REF ARG_ACTION?
		(	(op='^'|op='!')	-> ^($op RULE_REF ARG_ACTION?)
		|					-> ^(RULE_REF ARG_ACTION?)
		)
    ;

not_set
	:	'~'
		(	not_terminal element_options?	-> ^('~' not_terminal element_options?)
		|	block element_options?		-> ^('~' block element_options?)
		)
	;

not_terminal
	:   CHAR_LITERAL
	|	TOKEN_REF
	|	STRING_LITERAL
	;
	
element_options
	:	'<' qid '>'					 -> ^(OPTIONS qid)
	|	'<' option (';' option)* '>' -> ^(OPTIONS option+)
	;

element_option
	:	id '=' option_value -> ^('=' id option_value)
	;
	
tree_spec
	:	'^(' element ( element )+ ')' -> ^(TREE_BEGIN element+)
	;

range!
	:	c1=CHAR_LITERAL RANGE c2=CHAR_LITERAL element_options?
		-> ^(CHAR_RANGE[$c1,".."] $c1 $c2 element_options?)
	;

terminal
    :   (	CHAR_LITERAL element_options?    	  -> ^(CHAR_LITERAL element_options?)
	    	// Args are only valid for lexer rules
		|   TOKEN_REF ARG_ACTION? element_options? -> ^(TOKEN_REF ARG_ACTION? element_options?)
		|   STRING_LITERAL element_options?		  -> ^(STRING_LITERAL element_options?)
		|   '.' element_options?		 			  -> ^('.' element_options?)
		)
		(	'^'							-> ^('^' $terminal)
		|	'!' 						-> ^('!' $terminal)
		)?
	;

/** Matches ENBF blocks (and token sets via block rule) */
ebnf
@init { first_token = @input.look(1) }
@after {
	$ebnf.tree.token.line = first_token.line
	$ebnf.tree.token.column = first_token.column
}
	:	block
		(	op='?'	-> ^(OPTIONAL[$op] block)
		|	op='*'	-> ^(CLOSURE[$op] block)
		|	op='+'	-> ^(POSITIVE_CLOSURE[$op] block)
		|   '=>'	// syntactic predicate
					-> { 
  @grammar_type == COMBINED_GRAMMAR && $rule::name[0].between?(?A, ?Z)
          }?
					   // if lexer rule in combined, leave as pred for lexer
					   ^(SYNPRED["=>"] block)
					// in real antlr tool, text for SYN_SEMPRED is predname
					-> SYN_SEMPRED
        |			-> block
		)
	;

ebnf_suffix
@init {
	op = @input.look(1)
}
	:	'?'	-> OPTIONAL[op]
  	|	'*' -> CLOSURE[op]
   	|	'+' -> POSITIVE_CLOSURE[op]
	;
	


// R E W R I T E  S Y N T A X

rewrite
@init {
	first_token = @input.look(1)
}
	:	(rew+='->' preds+=SEMPRED predicated+=rewrite_alternative)*
		rew2='->' last=rewrite_alternative
        -> ^($rew $preds $predicated)* ^($rew2 $last)
	|
	;

rewrite_alternative
options {backtrack=true;}
	:	rewrite_template
	|	rewrite_tree_alternative
  |   /* empty rewrite */ -> ^(ALT["ALT"] EPSILON["EPSILON"] EOA["EOA"])
	;
	
rewrite_tree_block
    :   lp='(' rewrite_tree_alternative ')'
    	-> ^(BLOCK[$lp,"BLOCK"] rewrite_tree_alternative EOB[$lp,"EOB"])
    ;

rewrite_tree_alternative
    :	rewrite_tree_element+ -> ^(ALT["ALT"] rewrite_tree_element+ EOA["EOA"])
    ;

rewrite_tree_element
	:	rewrite_tree_atom
	|	rewrite_tree_atom ebnf_suffix
		-> ^( ebnf_suffix ^(BLOCK["BLOCK"] ^(ALT["ALT"] rewrite_tree_atom EOA["EOA"]) EOB["EOB"]))
	|   rewrite_tree
		(	ebnf_suffix
			-> ^(ebnf_suffix ^(BLOCK["BLOCK"] ^(ALT["ALT"] rewrite_tree EOA["EOA"]) EOB["EOB"]))
		|	-> rewrite_tree
		)
	|   rewrite_tree_ebnf
	;

rewrite_tree_atom
    :   CHAR_LITERAL
	|   TOKEN_REF ARG_ACTION? -> ^(TOKEN_REF ARG_ACTION?) // for imaginary nodes
  |   RULE_REF
	|   STRING_LITERAL
	|   d='$' id -> LABEL[$d,$id.text] // reference to a label in a rewrite rule
	|	ACTION
	;

rewrite_tree_ebnf
@init {
  first_token = @input.look(1)
}
@after {
	$rewrite_tree_ebnf.tree.token.line = first_token.line
	$rewrite_tree_ebnf.tree.token.column = first_token.column
}
	:	rewrite_tree_block ebnf_suffix -> ^(ebnf_suffix rewrite_tree_block)
	;
	
rewrite_tree
	:	'^(' rewrite_tree_atom rewrite_tree_element* ')'
		-> ^(TREE_BEGIN rewrite_tree_atom rewrite_tree_element* )
	;

/** Build a tree for a template rewrite:
      ^(TEMPLATE (ID|ACTION) ^(ARGLIST ^(ARG ID ACTION) ...) )
    where ARGLIST is always there even if no args exist.
    ID can be "template" keyword.  If first child is ACTION then it's
    an indirect template ref

    -> foo(a={...}, b={...})
    -> ({string-e})(a={...}, b={...})  // e evaluates to template name
    -> {%{$ID.text}} // create literal template from string (done in ActionTranslator)
	-> {st-expr} // st-expr evaluates to ST
 */
rewrite_template
	:   // -> template(a={...},...) "..."    inline template
		id lp='(' rewrite_template_args	')'
		( str=DOUBLE_QUOTE_STRING_LITERAL | str=DOUBLE_ANGLE_STRING_LITERAL )
		-> ^(TEMPLATE[$lp,"TEMPLATE"] id rewrite_template_args $str)

	|	// -> foo(a={...}, ...)
		rewrite_template_ref

	|	// -> ({expr})(a={...}, ...)
		rewrite_indirect_template_head

	|	// -> {...}
		ACTION
	;

/** -> foo(a={...}, ...) */
rewrite_template_ref
	:	id lp='(' rewrite_template_args	')'
		-> ^(TEMPLATE[$lp,"TEMPLATE"] id rewrite_template_args)
	;

/** -> ({expr})(a={...}, ...) */
rewrite_indirect_template_head
	:	lp='(' ACTION ')' '(' rewrite_template_args ')'
		-> ^(TEMPLATE[$lp,"TEMPLATE"] ACTION rewrite_template_args)
	;

rewrite_template_args
	:	rewrite_template_arg (',' rewrite_template_arg)*
		-> ^(ARGLIST rewrite_template_arg+)
	|	-> ARGLIST
	;

rewrite_template_arg
	:   id '=' ACTION -> ^(ARG[$id.start] id ACTION)
	;

qid :	id ('.' id)* ;
	
id	:	
   TOKEN_REF -> ID[$TOKEN_REF]
	|	RULE_REF  -> ID[$RULE_REF]
	;

// L E X I C A L   R U L E S

SL_COMMENT
 	:	'//'
 	 	(	' $ANTLR ' SRC // src directive
 		|	~('\r'|'\n')*
		)
		'\r'? '\n' {$channel=HIDDEN;}
	;

ML_COMMENT
	:	'/*' {if @input.peek(1) == ?* then $type = DOC_COMMENT else $channel = HIDDEN end } .* '*/'
	;

CHAR_LITERAL
	:	'\'' LITERAL_CHAR '\''
	;

STRING_LITERAL
	:	'\'' LITERAL_CHAR LITERAL_CHAR* '\''
	;

fragment
LITERAL_CHAR
	:	ESC
	|	~('\''|'\\')
	;

DOUBLE_QUOTE_STRING_LITERAL
	:	'"' (ESC | ~('\\'|'"'))* '"'
	;

DOUBLE_ANGLE_STRING_LITERAL
	:	'<<' .* '>>'
	;

fragment
ESC	:	'\\'
		(	'n'
		|	'r'
		|	't'
		|	'b'
		|	'f'
		|	'"'
		|	'\''
		|	'\\'
		|	'>'
		|	'u' XDIGIT XDIGIT XDIGIT XDIGIT
		|	. // unknown, leave as it is
		)
	;

fragment
XDIGIT :
		'0' .. '9'
	|	'a' .. 'f'
	|	'A' .. 'F'
	;

INT	:	'0'..'9'+
	;

ARG_ACTION
	:	NESTED_ARG_ACTION
	;

fragment
NESTED_ARG_ACTION :
	'['
	(	options {greedy=false; k=1;}
	:	NESTED_ARG_ACTION
	|	ACTION_STRING_LITERAL
	|	ACTION_CHAR_LITERAL
	|	.
	)*
	']'
	//{setText(getText().substring(1, getText().length()-1));}
	;

ACTION
	:	NESTED_ACTION ( '?' { $type = SEMPRED } )?
	;

fragment
NESTED_ACTION :
	'{'
	(	options {greedy=false; k=2;}
	:	NESTED_ACTION
	|	SL_COMMENT
	|	ML_COMMENT
	|	ACTION_STRING_LITERAL
	|	ACTION_CHAR_LITERAL
	|	~ '\\'
  | '\\' .
	)*
	'}'
   ;

fragment
ACTION_CHAR_LITERAL
	:	'\'' ( ~('\\'|'\'') | '\\' . )* '\''
	;

fragment
ACTION_STRING_LITERAL
	:	'"' ( ~('\\'|'"') | '\\' . )* '"'
	;

fragment
ACTION_ESC
	:	'\\' .
	;

TOKEN_REF
	:	'A'..'Z' ('a'..'z'|'A'..'Z'|'_'|'0'..'9')*
	;

RULE_REF
	:	'a'..'z' ('a'..'z'|'A'..'Z'|'_'|'0'..'9')*
	;

/** Match the start of an options section.  Don't allow normal
 *  action processing on the {...} as it's not a action.
 */
OPTIONS
	:	'options' WS_LOOP '{'
	;
	
TOKENS
	:	'tokens' WS_LOOP '{'
	;

/** Reset the file and line information; useful when the grammar
 *  has been generated so that errors are shown relative to the
 *  original file like the old C preprocessor used to do.
 */
fragment
SRC	:	'src' ' ' file=ACTION_STRING_LITERAL ' ' line=INT
	;

WS	:	(	' '
		|	'\t'
		|	'\r'? '\n'
		)+
		{$channel=HIDDEN}
	;

fragment
WS_LOOP
	:	(	WS
		|	SL_COMMENT
		|	ML_COMMENT
		)*
	;

