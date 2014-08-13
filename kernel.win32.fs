( win32-specific code )
words
: halt halt ;

( temporary zero-terminated strings )
variable zbuf 1024 allot
variable zp zbuf ,
: zstring dup >r zp @ swap 1copy 0 r@ zp @ + 1! zp @ r> over + 1+ zp ! ;
: zflush zbuf zp ! ;

( dynamic library linking )
variable args 0 ,
: library text zstring >r dup dll variable , zflush ;
: function text zstring >r @ >r dup sym
  token name here word define 0 args ! zflush ;
: int postpone >r 4 args +! ;
: char* postpone zstring postpone >r 4 args +! ;
: stdcall dup, call, postpone ; ;
: stdcallz dup, call, postpone zflush postpone ; ;
: cdecl dup, call, $c481 2, args @ , postpone ; ;

library "kernel32.dll" kernel32
kernel32 function "FreeConsole" FreeConsole stdcall
kernel32 function "ExitProcess" ExitProcess int stdcall
kernel32 function "GetStdHandle" GetStdHandle int stdcall
kernel32 function "WriteConsoleA" WriteConsole int int int int int stdcall

: bye 0 ExitProcess ; bye

11 negate GetStdHandle halt

: type >r >r [ 11 negate GetStdHandle lit, ] r> r> 0 0 WriteConsole ;

halt
text "Hello, World" type
