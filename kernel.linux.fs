( linux-specific code )

( bye )
words
: bye 0 1 1 syscall ;
: halt halt ;

( console output )
variable ch 0 1,
: emit ch 1! 1 ch 1 3 4 syscall drop ;
: cr 10 emit ;
: space 32 emit ;
: spaces for space next ;
: type >r >r 1 r> r> 3 4 syscall drop ;

( text and number output )
macros
: ." postpone c" postpone count postpone type ;
words
: ." s" type ;
: . <# #? -if negate #. [char] - hold else #. then #> type space ;
: hex. <# $# $# $# $# $# $# $# $# #> type ;
: hexc. <# $# $# #> type ;

( debugging )
: $. [char] $ emit hex. ;
: esi. [ $f189 2, ] dup [ $c889 2, ] $. ;
: esp. dup [ $e089 2, ] 4 + $. ;
: dumpline space dup hex. [char] : emit space space 16 for dup 1@ hexc.
space 1+ next 16 - space space 16 type cr ;
: dump cr 16 for dup dumpline 16 + next drop ;

: usage
  ." gtForth for Linux Luke McCarthy July 2004" cr space space
  ." syntax:  gtforth (forth file) [heap size in blocks]" cr space space
  ." example: gtforth myprogram.fs 500" cr space space
  ." if no heap size is given, 256KB is allocated by default" cr ;

: -strlen over 1@ #? drop /if ;; then 1+ swap 1+ swap -strlen ; 
: strlen dup 0 -strlen nip ;
: arg. argv for dup @ strlen type cr 4 + next ;

: pause 0 29 syscall ;

\ in@ hex. space hex. cr
arg. cr usage $4000 dump bye
