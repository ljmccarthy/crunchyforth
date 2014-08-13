; COMPILER CONTEXT BLOCK

struc ctx
  .mode   resd 1  ; mode (e.g. interpret, compile, postpone)
  .hp     resd 1  ; here pointer
  .hx     resd 1  ; here maximum
  .input  resd 1  ; input string
  .inmax  resd 1  ; input maximum
  .names  resd 1  ; name string
  .namec  resd 1  ; name count
  .nameh  resd 1  ; name hash
  .ierr   resd 1  ; internal error
  .lops   resd 1  ; last optimisable
  .dp     resd 1  ; dictionary pointer (may be deprecated)
  .wp     resd 1  ; word dictionary
  .mp     resd 1  ; macro dictionary
  .sbase  resd 1  ; data stack base
  .rbase  resd 1  ; return stack base
  .inner  resd 1  ; inner loop control word
endstruc


struc simpledict
  .count  resd 1  ; number of words
  .max    resd 1  ; maximum words
  .keys   resd 1  ; keys (names) array pointer
  .vals   resd 1  ; values (addresses) array pointer
endstruc


; INTERNAL ERROR CODES

%define IERR_OK   0  ; OK
%define IERR_FULL 1  ; Dictionary Table Full
%define IERR_NAN  2  ; Not A Number
%define IERR_EOIS 3  ; End Of Input String
%define IERR_EOCH 4  ; End Of Code Heap
