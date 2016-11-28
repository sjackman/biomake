% * -*- Mode: Prolog -*- */

:- use_module(library(plmake/plmake)).

user:prolog_exception_hook(_,
                           _, _, _) :-
        backtrace(99),
        !,
        fail.

main :-
        current_prolog_flag(argv, Arguments),
        (append(_SytemArgs, [--|Args], Arguments) ; =(Arguments,Args)),
        !,
        parse_args(Args,Opts_1),
        flatten(Opts_1,Opts),
	add_assignments(Opts),
	consult_makefile(Opts),
        forall(member(goal(G),Opts),
               G),
        forall(member(rest(T),Opts),
               build(T,Opts)),
        halt.

add_assignments(Opts) :-
        forall(member(assignment(Var,Val),Opts),
	       add_assignment((Var = Val))).

consult_makefile(Opts) :-
	DefaultMakeprog = 'makespec.pro',
	DefaultGnuMakefile = 'Makefile',
	(member(makeprog(BF),Opts)
	 -> consult_makeprog(BF);
	 (member(gnu_makefile(F),Opts)
	  -> consult_gnu_makefile(F);
	  (exists_file(DefaultMakeprog)
	   -> consult_makeprog(DefaultMakeprog);
	   consult_gnu_makefile(DefaultGnuMakefile)))).

% ----------------------------------------
% OPTION PROCESSING
% ----------------------------------------

parse_args([],[]).
parse_args(Args,[Opt|Opts]) :-
        parse_arg(Args,Rest,Opt),
        !,
        parse_args(Rest,Opts).
parse_args([A|Args],[rest(A)|Opts]) :-
        parse_args(Args,Opts).

:- discontiguous parse_arg/3.
:- discontiguous arg_info/3.

parse_arg(['--debug',D|L],L,null) :- debug(D), set_prolog_flag(verbose,normal).
arg_info('--debug','TARGET','[developers] debugging messages. TARGET can be build, pattern, makeprog, makefile...').

parse_arg(['--dry-run'|L],L,dry_run(true)).
parse_arg(['-n'|L],L,dry_run(true)).
arg_info('--dry-run','','Print the commands that would be executed, but do not execute them').
arg_info('-n','','Shortcut for --dry-run').

parse_arg(['-h'|L],L,null) :-
        writeln('plmake [OPTION...] target1 target2...'),
        nl,
        writeln('Options:'),
        show_help,
        nl,
        writeln('For more info see http://github.com/cmungall/plmake'),
        nl,
        halt.
arg_info('-h','','Show help').


parse_arg(['--always-make'|L],L,always_make(true)).
parse_arg(['-B'|L],L,always_make(true)).
arg_info('--always-make','','Always build fresh target even if dependency is up to date').
arg_info('-B','','Shortcut for --always-make').

parse_arg(['-f',F|L],L,gnu_makefile(F)).
arg_info('-f','GNUMAKEFILE','Use a GNU Makefile as the build specification [incomplete]').

parse_arg(['-p',F|L],L,makeprog(F)) :- !.
arg_info('-p','MAKEPROG','Use MAKEPROG as the (Prolog) build specification [default: makespec.pro]').

parse_arg(['-l',F|L],L,
          goal( (collect_stored_targets(F,[]),
                 show_stored_targets
                ) )) :-
        ensure_loaded(library(plmake/plmake_db)),
        !.
arg_info('-l','DIRECTORY','Iterates through directory writing metadata on each file found').

parse_arg([VarEqualsVal|L],L,assignment(Var,Val)) :-
    string_codes(VarEqualsVal,C),
    phrase(makefile_assign(Var,Val),C).
arg_info('Var=Val','','Assign Makefile variables from command line').

show_help :-
    forall(arg_info(X,Args,Info),
	   format("~w ~w~n    ~w~n",[X,Args,Info])).

makefile_assign(Var,Val) --> makefile_var(Var), "=", makefile_val(Val).
makefile_var(A) --> {string_codes(":= \t\n",XL)}, atom_toks(A,XL).
makefile_val(S) --> "\"", {string_codes("\"",XL)}, string_toks(S,XL), "\"".
makefile_val(S) --> {string_codes(" ",XL)}, string_toks(S,XL).
atom_toks(A,XL) --> clist(C,XL), {C\=[], atom_chars(A,C)}.
string_toks(S,XL) --> clist(C,XL), {C\=[], string_chars(S,C)}.
clist([C|Cs],XL) --> [C], {forall(member(X,XL),C\=X)}, !, clist(Cs,XL).
clist([C|Cs],XL) --> ['\\'], [C], !, clist(Cs,XL).
clist([],_) --> [].
