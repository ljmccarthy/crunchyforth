( native-specific code )

( halt )
words
: hlt [ $f4 1, ] ;
: halt halt ;

( port i/o )
macros
: p@ $c289 2, $ec 1, ;
: p! $c289 2, drop, $ee 1, drop, ;

( console output )
words
variable scr 0 ,
: at 80 * + 2* $b8000 + scr ! ; 0 0 at
: emit scr @ 1! 2 scr +! ;
: space 32 emit ;
: spaces for space next ;
: type for dup 1@ emit 1+ next drop ;
: cr scr @ $b8000 - 160 / 1+ 160 * $b8000 + scr ! ;
: cls $b8000 2000 $1f20 2fill ;

( text and number output )
macros
: ." postpone c" postpone count postpone type ;
words
: ." s" type ;
: . <# #? -if negate #. [char] - hold else #. then #> type ;
: hex. <# $# $# $# $# $# $# $# $# #> type ;
: hexc. <# $# $# #> type ;

( debugging )
: dumpline space dup hex. [char] : emit space space 16 for dup 1@ hexc.
           space 1+ next 16 - space space 16 type cr ;
: dump 16 for dup dumpline 16 + next drop ;
: .s depth 1024 -? +if ." OVERFLOW! " ;; then 1 -? -if ." UNDERFLOW! " ;; then
  [char] < emit dup . [char] > emit space
  for depth i - 2 + 4 * negate $0c00 + @ . space next ;

( memory browser )
: key $64 p@ 1 ? drop /if key ;; then $60 p@ $80 -? +if drop key ;; then ;
: up 16 - ;
: pgup 256 - ;
: down 16 + ;
: pgdn 256 + ;
variable actions ' up , ' pgup , ' continue , ' continue , ' continue ,
' continue , ' continue , ' continue , ' down , ' pgdn ,
: action $48 -? +if $52 -? -if $48 - 4 * actions + @ call ;; then then drop ;
: mem dup 0 2 at dump key action mem ;

cls 0 0 at ." CrunchyForth"
cr cr

: bl? $21 -? -if T ;; then $7f -? +if T ;; then F ;
: gf? $21 -? -if F ;; then $7f -? +if F ;; then T ;
: scan>bl in@ ['] bl? scanw in! ;
: scan>gf in@ ['] gf? scanw in! ;
: token scan>gf in@ drop scan>bl in@ drop strung ;
: test token type token type halt ;
\ test

$1000 mem halt
