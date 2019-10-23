" paredit.vim:
"               Paredit mode for Slimv
" Version:      0.9.14
" Last Change:  17 Oct 2019
" Maintainer:   Tamas Kovacs <kovisoft at gmail dot com>
" License:      This file is placed in the public domain.
"               No warranty, express or implied.
"               *** ***   Use At-Your-Own-Risk!   *** ***
"
" =====================================================================
"
"  Load Once:
if &cp || exists( 'g:paredit_loaded' )
    finish
endif

let g:paredit_loaded = 1

" Needed to load filetype and indent plugins
if !exists( 'g:paredit_disable_ftplugin') || g:paredit_disable_ftplugin == 0
    filetype plugin on
endif

if !exists( 'g:paredit_disable_ftindent') || g:paredit_disable_ftindent == 0
    filetype indent on
endif

" =====================================================================
"  Global variable definitions
" =====================================================================

" Paredit mode selector
if !exists( 'g:paredit_mode' )
    let g:paredit_mode = 1
endif

" Match delimiter this number of lines before and after cursor position
if !exists( 'g:paredit_matchlines' )
    let g:paredit_matchlines = 100
endif

" Use short keymaps, i.e. J instead of <Leader>J
if !exists( 'g:paredit_shortmaps' )
    let g:paredit_shortmaps = 0
endif

" Use smart jumping to the nearest paren, curly brace, or square bracket in
" clojure
if !exists( 'g:paredit_smartjump' )
    let g:paredit_smartjump = 0
endif

" Custom <Leader> for the Paredit plugin
if !exists( 'g:paredit_leader' )
    if exists( 'mapleader' )
        let g:paredit_leader = '<leader>'
    else
        let g:paredit_leader = ','
    endif
endif

" Use 'Electric Return', i.e. add double newlines if enter pressed before a closing paren
if !exists( 'g:paredit_electric_return' )
    let g:paredit_electric_return = 1
endif

" =====================================================================
"  Other variable definitions
" =====================================================================

" Valid macro prefix characters
let s:any_macro_prefix   = "'" . '\|`\|#\|@\|\~\|,\|\^'

" Repeat count for some remapped edit functions (like 'd')
let s:count              = 0
let s:repeat             = 0

let s:yank_pos           = []

" Filetypes with [] and {} pairs balanced as well
let s:fts_balancing_all_brackets = '.*\(clojure\|hy\|scheme\|racket\|shen\|lfe\|fennel\).*'

" =====================================================================
"  General utility functions
" =====================================================================
" Buffer specific initialization
function! PareditInitBuffer()
    let b:paredit_init = 1
    " in case they are accidentally removed
    " Also define regular expressions to identify special characters used by paredit
    if &ft =~ s:fts_balancing_all_brackets
        let b:any_matched_char   = '(\|)\|\[\|\]\|{\|}\|\"'
        let b:any_matched_pair   = '()\|\[\]\|{}\|\"\"'
        let b:any_opening_char   = '(\|\[\|{'
        let b:any_closing_char   = ')\|\]\|}'
        let b:any_openclose_char = '(\|)\|\[\|\]\|{\|}'
        let b:any_wsopen_char    = '\s\|(\|\[\|{'
        let b:any_wsclose_char   = '\s\|)\|\]\|}'
    else
        let b:any_matched_char   = '(\|)\|\"'
        let b:any_matched_pair   = '()\|\"\"'
        let b:any_opening_char   = '('
        let b:any_closing_char   = ')'
        let b:any_openclose_char = '(\|)'
        let b:any_wsopen_char    = '\s\|('
        let b:any_wsclose_char   = '\s\|)'
    endif

    if g:paredit_mode
        " Paredit mode is on: add buffer specific keybindings
        inoremap <buffer> <expr>   (            PareditInsertOpening('(',')')
        inoremap <buffer> <silent> )            <C-R>=PareditInsertClosing('(',')')<CR>
        inoremap <buffer> <expr>   "            PareditInsertQuotes()
        inoremap <buffer> <expr>   <BS>         PareditBackspace(0)
        inoremap <buffer> <expr>   <C-h>        PareditBackspace(0)
        inoremap <buffer> <expr>   <Del>        PareditDel()
        if &ft =~ s:fts_balancing_all_brackets && g:paredit_smartjump
            noremap  <buffer> <silent> (            :<C-U>call PareditSmartJumpOpening(0)<CR>
            noremap  <buffer> <silent> )            :<C-U>call PareditSmartJumpClosing(0)<CR>
            vnoremap <buffer> <silent> (            <Esc>:<C-U>call PareditSmartJumpOpening(1)<CR>
            vnoremap <buffer> <silent> )            <Esc>:<C-U>call PareditSmartJumpClosing(1)<CR>
        else
            noremap  <buffer> <silent> (            :<C-U>call PareditFindOpening('(',')',0)<CR>
            noremap  <buffer> <silent> )            :<C-U>call PareditFindClosing('(',')',0)<CR>
            vnoremap <buffer> <silent> (            <Esc>:<C-U>call PareditFindOpening('(',')',1)<CR>
            vnoremap <buffer> <silent> )            <Esc>:<C-U>call PareditFindClosing('(',')',1)<CR>
        endif
        noremap  <buffer> <silent> [[           :<C-U>call PareditFindDefunBck()<CR>
        noremap  <buffer> <silent> ]]           :<C-U>call PareditFindDefunFwd()<CR>

        call RepeatableNNoRemap('x', ':<C-U>call PareditEraseFwd()')
        nnoremap <buffer> <silent> <Del>        :<C-U>call PareditEraseFwd()<CR>
        call RepeatableNNoRemap('X', ':<C-U>call PareditEraseBck()')
        nnoremap <buffer> <silent> s            :<C-U>call PareditEraseFwd()<CR>i
        call RepeatableNNoRemap('D', 'v$:<C-U>call PareditDelete(visualmode(),1)')
        nnoremap <buffer> <silent> C            v$:<C-U>call PareditChange(visualmode(),1)<CR>
        nnoremap <buffer> <silent> d            :<C-U>call PareditSetDelete(v:count)<CR>g@
        vnoremap <buffer> <silent> d            :<C-U>call PareditDelete(visualmode(),1)<CR>
        vnoremap <buffer> <silent> x            :<C-U>call PareditDelete(visualmode(),1)<CR>
        vnoremap <buffer> <silent> <Del>        :<C-U>call PareditDelete(visualmode(),1)<CR>
        nnoremap <buffer> <silent> c            :set opfunc=PareditChange<CR>g@
        vnoremap <buffer> <silent> c            :<C-U>call PareditChange(visualmode(),1)<CR>
        call RepeatableNNoRemap('dd', ':<C-U>call PareditDeleteLines()')
        nnoremap <buffer> <silent> cc           :<C-U>call PareditChangeLines()<CR>
        nnoremap <buffer> <silent> cw           :<C-U>call PareditChangeSpec('cw',1)<CR>
        nnoremap <buffer> <silent> cW           :set opfunc=PareditChange<CR>g@E
        nnoremap <buffer> <silent> ciw          :<C-U>call PareditChangeSpec('ciw',1)<CR>
        nnoremap <buffer> <silent> caw          :<C-U>call PareditChangeSpec('caw',1)<CR>
        nnoremap <buffer> <silent> cb           :<C-U>call PareditChangeSpec('cb',0)<CR>
        nnoremap <buffer> <silent> cB           :<C-U>call PareditChangeSpec('cB',0)<CR>
        nnoremap <buffer> <silent> ce           :<C-U>call PareditChangeSpec('ce',1)<CR>
        nnoremap <buffer> <silent> cE           :<C-U>call PareditChangeSpec('cE',1)<CR>
        nnoremap <buffer> <silent> ca{          :<C-U>call PareditChangeSpec('ca{',1)<CR>
        nnoremap <buffer> <silent> ci{          :<C-U>call PareditChangeSpec('ci{',1)<CR>
        nnoremap <buffer> <silent> ca}          :<C-U>call PareditChangeSpec('ca}',1)<CR>
        nnoremap <buffer> <silent> ci}          :<C-U>call PareditChangeSpec('ci}',1)<CR>
        nnoremap <buffer> <silent> ca[          :<C-U>call PareditChangeSpec('ca[',1)<CR>
        nnoremap <buffer> <silent> ci[          :<C-U>call PareditChangeSpec('ci[',1)<CR>
        nnoremap <buffer> <silent> ca]          :<C-U>call PareditChangeSpec('ca]',1)<CR>
        nnoremap <buffer> <silent> ci]          :<C-U>call PareditChangeSpec('ci]',1)<CR>
        nnoremap <buffer> <silent> ca(          :<C-U>call PareditChangeSpec('ca(',1)<CR>
        nnoremap <buffer> <silent> ci(          :<C-U>call PareditChangeSpec('ci(',1)<CR>
        nnoremap <buffer> <silent> ca)          :<C-U>call PareditChangeSpec('ca)',1)<CR>
        nnoremap <buffer> <silent> ci)          :<C-U>call PareditChangeSpec('ci)',1)<CR>
        nnoremap <buffer> <silent> ci'          :<C-U>call PareditChangeSpec("ci'",1)<CR>
        nnoremap <buffer> <silent> ca'          :<C-U>call PareditChangeSpec("ca'",1)<CR>
        nnoremap <buffer> <silent> ci"          :<C-U>call PareditChangeSpec('ci"',1)<CR>
        nnoremap <buffer> <silent> ca"          :<C-U>call PareditChangeSpec('ca"',1)<CR>
        "nnoremap <buffer> <silent> c%           :<C-U>call PareditChangeSpec('c%',1)<CR>

        " ascii (range 33 127)
        nnoremap <buffer> <silent> ct!  :<C-U>call PareditChangeSpec('ct!',1)<CR>
        nnoremap <buffer> <silent> cT!  :<C-U>call PareditChangeSpec('cT!',1)<CR>
        nnoremap <buffer> <silent> cf!  :<C-U>call PareditChangeSpec('cf!',1)<CR>
        nnoremap <buffer> <silent> cF!  :<C-U>call PareditChangeSpec('cF!',1)<CR>
        nnoremap <buffer> <silent> ct"  :<C-U>call PareditChangeSpec('ct"',1)<CR>
        nnoremap <buffer> <silent> cT"  :<C-U>call PareditChangeSpec('cT"',1)<CR>
        nnoremap <buffer> <silent> cf"  :<C-U>call PareditChangeSpec('cf"',1)<CR>
        nnoremap <buffer> <silent> cF"  :<C-U>call PareditChangeSpec('cF"',1)<CR>
        nnoremap <buffer> <silent> ct#  :<C-U>call PareditChangeSpec('ct#',1)<CR>
        nnoremap <buffer> <silent> cT#  :<C-U>call PareditChangeSpec('cT#',1)<CR>
        nnoremap <buffer> <silent> cf#  :<C-U>call PareditChangeSpec('cf#',1)<CR>
        nnoremap <buffer> <silent> cF#  :<C-U>call PareditChangeSpec('cF#',1)<CR>
        nnoremap <buffer> <silent> ct$  :<C-U>call PareditChangeSpec('ct$',1)<CR>
        nnoremap <buffer> <silent> cT$  :<C-U>call PareditChangeSpec('cT$',1)<CR>
        nnoremap <buffer> <silent> cf$  :<C-U>call PareditChangeSpec('cf$',1)<CR>
        nnoremap <buffer> <silent> cF$  :<C-U>call PareditChangeSpec('cF$',1)<CR>
        nnoremap <buffer> <silent> ct%  :<C-U>call PareditChangeSpec('ct%',1)<CR>
        nnoremap <buffer> <silent> cT%  :<C-U>call PareditChangeSpec('cT%',1)<CR>
        nnoremap <buffer> <silent> cf%  :<C-U>call PareditChangeSpec('cf%',1)<CR>
        nnoremap <buffer> <silent> cF%  :<C-U>call PareditChangeSpec('cF%',1)<CR>
        nnoremap <buffer> <silent> ct&  :<C-U>call PareditChangeSpec('ct&',1)<CR>
        nnoremap <buffer> <silent> cT&  :<C-U>call PareditChangeSpec('cT&',1)<CR>
        nnoremap <buffer> <silent> cf&  :<C-U>call PareditChangeSpec('cf&',1)<CR>
        nnoremap <buffer> <silent> cF&  :<C-U>call PareditChangeSpec('cF&',1)<CR>
        nnoremap <buffer> <silent> ct'  :<C-U>call PareditChangeSpec("ct'",1)<CR>
        nnoremap <buffer> <silent> cT'  :<C-U>call PareditChangeSpec("cT'",1)<CR>
        nnoremap <buffer> <silent> cf'  :<C-U>call PareditChangeSpec("cf'",1)<CR>
        nnoremap <buffer> <silent> cF'  :<C-U>call PareditChangeSpec("cF'",1)<CR>
        nnoremap <buffer> <silent> ct(  :<C-U>call PareditChangeSpec('ct(',1)<CR>
        nnoremap <buffer> <silent> cT(  :<C-U>call PareditChangeSpec('cT(',1)<CR>
        nnoremap <buffer> <silent> cf(  :<C-U>call PareditChangeSpec('cf(',1)<CR>
        nnoremap <buffer> <silent> cF(  :<C-U>call PareditChangeSpec('cF(',1)<CR>
        nnoremap <buffer> <silent> ct)  :<C-U>call PareditChangeSpec('ct)',1)<CR>
        nnoremap <buffer> <silent> cT)  :<C-U>call PareditChangeSpec('cT)',1)<CR>
        nnoremap <buffer> <silent> cf)  :<C-U>call PareditChangeSpec('cf)',1)<CR>
        nnoremap <buffer> <silent> cF)  :<C-U>call PareditChangeSpec('cF)',1)<CR>
        nnoremap <buffer> <silent> ct*  :<C-U>call PareditChangeSpec('ct*',1)<CR>
        nnoremap <buffer> <silent> cT*  :<C-U>call PareditChangeSpec('cT*',1)<CR>
        nnoremap <buffer> <silent> cf*  :<C-U>call PareditChangeSpec('cf*',1)<CR>
        nnoremap <buffer> <silent> cF*  :<C-U>call PareditChangeSpec('cF*',1)<CR>
        nnoremap <buffer> <silent> ct+  :<C-U>call PareditChangeSpec('ct+',1)<CR>
        nnoremap <buffer> <silent> cT+  :<C-U>call PareditChangeSpec('cT+',1)<CR>
        nnoremap <buffer> <silent> cf+  :<C-U>call PareditChangeSpec('cf+',1)<CR>
        nnoremap <buffer> <silent> cF+  :<C-U>call PareditChangeSpec('cF+',1)<CR>
        nnoremap <buffer> <silent> ct,  :<C-U>call PareditChangeSpec('ct,',1)<CR>
        nnoremap <buffer> <silent> cT,  :<C-U>call PareditChangeSpec('cT,',1)<CR>
        nnoremap <buffer> <silent> cf,  :<C-U>call PareditChangeSpec('cf,',1)<CR>
        nnoremap <buffer> <silent> cF,  :<C-U>call PareditChangeSpec('cF,',1)<CR>
        nnoremap <buffer> <silent> ct-  :<C-U>call PareditChangeSpec('ct-',1)<CR>
        nnoremap <buffer> <silent> cT-  :<C-U>call PareditChangeSpec('cT-',1)<CR>
        nnoremap <buffer> <silent> cf-  :<C-U>call PareditChangeSpec('cf-',1)<CR>
        nnoremap <buffer> <silent> cF-  :<C-U>call PareditChangeSpec('cF-',1)<CR>
        nnoremap <buffer> <silent> ct.  :<C-U>call PareditChangeSpec('ct.',1)<CR>
        nnoremap <buffer> <silent> cT.  :<C-U>call PareditChangeSpec('cT.',1)<CR>
        nnoremap <buffer> <silent> cf.  :<C-U>call PareditChangeSpec('cf.',1)<CR>
        nnoremap <buffer> <silent> cF.  :<C-U>call PareditChangeSpec('cF.',1)<CR>
        nnoremap <buffer> <silent> ct/  :<C-U>call PareditChangeSpec('ct/',1)<CR>
        nnoremap <buffer> <silent> cT/  :<C-U>call PareditChangeSpec('cT/',1)<CR>
        nnoremap <buffer> <silent> cf/  :<C-U>call PareditChangeSpec('cf/',1)<CR>
        nnoremap <buffer> <silent> cF/  :<C-U>call PareditChangeSpec('cF/',1)<CR>
        nnoremap <buffer> <silent> ct0  :<C-U>call PareditChangeSpec('ct0',1)<CR>
        nnoremap <buffer> <silent> cT0  :<C-U>call PareditChangeSpec('cT0',1)<CR>
        nnoremap <buffer> <silent> cf0  :<C-U>call PareditChangeSpec('cf0',1)<CR>
        nnoremap <buffer> <silent> cF0  :<C-U>call PareditChangeSpec('cF0',1)<CR>
        nnoremap <buffer> <silent> ct1  :<C-U>call PareditChangeSpec('ct1',1)<CR>
        nnoremap <buffer> <silent> cT1  :<C-U>call PareditChangeSpec('cT1',1)<CR>
        nnoremap <buffer> <silent> cf1  :<C-U>call PareditChangeSpec('cf1',1)<CR>
        nnoremap <buffer> <silent> cF1  :<C-U>call PareditChangeSpec('cF1',1)<CR>
        nnoremap <buffer> <silent> ct2  :<C-U>call PareditChangeSpec('ct2',1)<CR>
        nnoremap <buffer> <silent> cT2  :<C-U>call PareditChangeSpec('cT2',1)<CR>
        nnoremap <buffer> <silent> cf2  :<C-U>call PareditChangeSpec('cf2',1)<CR>
        nnoremap <buffer> <silent> cF2  :<C-U>call PareditChangeSpec('cF2',1)<CR>
        nnoremap <buffer> <silent> ct3  :<C-U>call PareditChangeSpec('ct3',1)<CR>
        nnoremap <buffer> <silent> cT3  :<C-U>call PareditChangeSpec('cT3',1)<CR>
        nnoremap <buffer> <silent> cf3  :<C-U>call PareditChangeSpec('cf3',1)<CR>
        nnoremap <buffer> <silent> cF3  :<C-U>call PareditChangeSpec('cF3',1)<CR>
        nnoremap <buffer> <silent> ct4  :<C-U>call PareditChangeSpec('ct4',1)<CR>
        nnoremap <buffer> <silent> cT4  :<C-U>call PareditChangeSpec('cT4',1)<CR>
        nnoremap <buffer> <silent> cf4  :<C-U>call PareditChangeSpec('cf4',1)<CR>
        nnoremap <buffer> <silent> cF4  :<C-U>call PareditChangeSpec('cF4',1)<CR>
        nnoremap <buffer> <silent> ct5  :<C-U>call PareditChangeSpec('ct5',1)<CR>
        nnoremap <buffer> <silent> cT5  :<C-U>call PareditChangeSpec('cT5',1)<CR>
        nnoremap <buffer> <silent> cf5  :<C-U>call PareditChangeSpec('cf5',1)<CR>
        nnoremap <buffer> <silent> cF5  :<C-U>call PareditChangeSpec('cF5',1)<CR>
        nnoremap <buffer> <silent> ct6  :<C-U>call PareditChangeSpec('ct6',1)<CR>
        nnoremap <buffer> <silent> cT6  :<C-U>call PareditChangeSpec('cT6',1)<CR>
        nnoremap <buffer> <silent> cf6  :<C-U>call PareditChangeSpec('cf6',1)<CR>
        nnoremap <buffer> <silent> cF6  :<C-U>call PareditChangeSpec('cF6',1)<CR>
        nnoremap <buffer> <silent> ct7  :<C-U>call PareditChangeSpec('ct7',1)<CR>
        nnoremap <buffer> <silent> cT7  :<C-U>call PareditChangeSpec('cT7',1)<CR>
        nnoremap <buffer> <silent> cf7  :<C-U>call PareditChangeSpec('cf7',1)<CR>
        nnoremap <buffer> <silent> cF7  :<C-U>call PareditChangeSpec('cF7',1)<CR>
        nnoremap <buffer> <silent> ct8  :<C-U>call PareditChangeSpec('ct8',1)<CR>
        nnoremap <buffer> <silent> cT8  :<C-U>call PareditChangeSpec('cT8',1)<CR>
        nnoremap <buffer> <silent> cf8  :<C-U>call PareditChangeSpec('cf8',1)<CR>
        nnoremap <buffer> <silent> cF8  :<C-U>call PareditChangeSpec('cF8',1)<CR>
        nnoremap <buffer> <silent> ct9  :<C-U>call PareditChangeSpec('ct9',1)<CR>
        nnoremap <buffer> <silent> cT9  :<C-U>call PareditChangeSpec('cT9',1)<CR>
        nnoremap <buffer> <silent> cf9  :<C-U>call PareditChangeSpec('cf9',1)<CR>
        nnoremap <buffer> <silent> cF9  :<C-U>call PareditChangeSpec('cF9',1)<CR>
        nnoremap <buffer> <silent> ct:  :<C-U>call PareditChangeSpec('ct:',1)<CR>
        nnoremap <buffer> <silent> cT:  :<C-U>call PareditChangeSpec('cT:',1)<CR>
        nnoremap <buffer> <silent> cf:  :<C-U>call PareditChangeSpec('cf:',1)<CR>
        nnoremap <buffer> <silent> cF:  :<C-U>call PareditChangeSpec('cF:',1)<CR>
        nnoremap <buffer> <silent> ct;  :<C-U>call PareditChangeSpec('ct;',1)<CR>
        nnoremap <buffer> <silent> cT;  :<C-U>call PareditChangeSpec('cT;',1)<CR>
        nnoremap <buffer> <silent> cf;  :<C-U>call PareditChangeSpec('cf;',1)<CR>
        nnoremap <buffer> <silent> cF;  :<C-U>call PareditChangeSpec('cF;',1)<CR>
        nnoremap <buffer> <silent> ct<  :<C-U>call PareditChangeSpec('ct<',1)<CR>
        nnoremap <buffer> <silent> cT<  :<C-U>call PareditChangeSpec('cT<',1)<CR>
        nnoremap <buffer> <silent> cf<  :<C-U>call PareditChangeSpec('cf<',1)<CR>
        nnoremap <buffer> <silent> cF<  :<C-U>call PareditChangeSpec('cF<',1)<CR>
        nnoremap <buffer> <silent> ct=  :<C-U>call PareditChangeSpec('ct=',1)<CR>
        nnoremap <buffer> <silent> cT=  :<C-U>call PareditChangeSpec('cT=',1)<CR>
        nnoremap <buffer> <silent> cf=  :<C-U>call PareditChangeSpec('cf=',1)<CR>
        nnoremap <buffer> <silent> cF=  :<C-U>call PareditChangeSpec('cF=',1)<CR>
        nnoremap <buffer> <silent> ct>  :<C-U>call PareditChangeSpec('ct>',1)<CR>
        nnoremap <buffer> <silent> cT>  :<C-U>call PareditChangeSpec('cT>',1)<CR>
        nnoremap <buffer> <silent> cf>  :<C-U>call PareditChangeSpec('cf>',1)<CR>
        nnoremap <buffer> <silent> cF>  :<C-U>call PareditChangeSpec('cF>',1)<CR>
        nnoremap <buffer> <silent> ct?  :<C-U>call PareditChangeSpec('ct?',1)<CR>
        nnoremap <buffer> <silent> cT?  :<C-U>call PareditChangeSpec('cT?',1)<CR>
        nnoremap <buffer> <silent> cf?  :<C-U>call PareditChangeSpec('cf?',1)<CR>
        nnoremap <buffer> <silent> cF?  :<C-U>call PareditChangeSpec('cF?',1)<CR>
        nnoremap <buffer> <silent> ct@  :<C-U>call PareditChangeSpec('ct@',1)<CR>
        nnoremap <buffer> <silent> cT@  :<C-U>call PareditChangeSpec('cT@',1)<CR>
        nnoremap <buffer> <silent> cf@  :<C-U>call PareditChangeSpec('cf@',1)<CR>
        nnoremap <buffer> <silent> cF@  :<C-U>call PareditChangeSpec('cF@',1)<CR>
        nnoremap <buffer> <silent> ctA  :<C-U>call PareditChangeSpec('ctA',1)<CR>
        nnoremap <buffer> <silent> cTA  :<C-U>call PareditChangeSpec('cTA',1)<CR>
        nnoremap <buffer> <silent> cfA  :<C-U>call PareditChangeSpec('cfA',1)<CR>
        nnoremap <buffer> <silent> cFA  :<C-U>call PareditChangeSpec('cFA',1)<CR>
        nnoremap <buffer> <silent> ctB  :<C-U>call PareditChangeSpec('ctB',1)<CR>
        nnoremap <buffer> <silent> cTB  :<C-U>call PareditChangeSpec('cTB',1)<CR>
        nnoremap <buffer> <silent> cfB  :<C-U>call PareditChangeSpec('cfB',1)<CR>
        nnoremap <buffer> <silent> cFB  :<C-U>call PareditChangeSpec('cFB',1)<CR>
        nnoremap <buffer> <silent> ctC  :<C-U>call PareditChangeSpec('ctC',1)<CR>
        nnoremap <buffer> <silent> cTC  :<C-U>call PareditChangeSpec('cTC',1)<CR>
        nnoremap <buffer> <silent> cfC  :<C-U>call PareditChangeSpec('cfC',1)<CR>
        nnoremap <buffer> <silent> cFC  :<C-U>call PareditChangeSpec('cFC',1)<CR>
        nnoremap <buffer> <silent> ctD  :<C-U>call PareditChangeSpec('ctD',1)<CR>
        nnoremap <buffer> <silent> cTD  :<C-U>call PareditChangeSpec('cTD',1)<CR>
        nnoremap <buffer> <silent> cfD  :<C-U>call PareditChangeSpec('cfD',1)<CR>
        nnoremap <buffer> <silent> cFD  :<C-U>call PareditChangeSpec('cFD',1)<CR>
        nnoremap <buffer> <silent> ctE  :<C-U>call PareditChangeSpec('ctE',1)<CR>
        nnoremap <buffer> <silent> cTE  :<C-U>call PareditChangeSpec('cTE',1)<CR>
        nnoremap <buffer> <silent> cfE  :<C-U>call PareditChangeSpec('cfE',1)<CR>
        nnoremap <buffer> <silent> cFE  :<C-U>call PareditChangeSpec('cFE',1)<CR>
        nnoremap <buffer> <silent> ctF  :<C-U>call PareditChangeSpec('ctF',1)<CR>
        nnoremap <buffer> <silent> cTF  :<C-U>call PareditChangeSpec('cTF',1)<CR>
        nnoremap <buffer> <silent> cfF  :<C-U>call PareditChangeSpec('cfF',1)<CR>
        nnoremap <buffer> <silent> cFF  :<C-U>call PareditChangeSpec('cFF',1)<CR>
        nnoremap <buffer> <silent> ctG  :<C-U>call PareditChangeSpec('ctG',1)<CR>
        nnoremap <buffer> <silent> cTG  :<C-U>call PareditChangeSpec('cTG',1)<CR>
        nnoremap <buffer> <silent> cfG  :<C-U>call PareditChangeSpec('cfG',1)<CR>
        nnoremap <buffer> <silent> cFG  :<C-U>call PareditChangeSpec('cFG',1)<CR>
        nnoremap <buffer> <silent> ctH  :<C-U>call PareditChangeSpec('ctH',1)<CR>
        nnoremap <buffer> <silent> cTH  :<C-U>call PareditChangeSpec('cTH',1)<CR>
        nnoremap <buffer> <silent> cfH  :<C-U>call PareditChangeSpec('cfH',1)<CR>
        nnoremap <buffer> <silent> cFH  :<C-U>call PareditChangeSpec('cFH',1)<CR>
        nnoremap <buffer> <silent> ctI  :<C-U>call PareditChangeSpec('ctI',1)<CR>
        nnoremap <buffer> <silent> cTI  :<C-U>call PareditChangeSpec('cTI',1)<CR>
        nnoremap <buffer> <silent> cfI  :<C-U>call PareditChangeSpec('cfI',1)<CR>
        nnoremap <buffer> <silent> cFI  :<C-U>call PareditChangeSpec('cFI',1)<CR>
        nnoremap <buffer> <silent> ctJ  :<C-U>call PareditChangeSpec('ctJ',1)<CR>
        nnoremap <buffer> <silent> cTJ  :<C-U>call PareditChangeSpec('cTJ',1)<CR>
        nnoremap <buffer> <silent> cfJ  :<C-U>call PareditChangeSpec('cfJ',1)<CR>
        nnoremap <buffer> <silent> cFJ  :<C-U>call PareditChangeSpec('cFJ',1)<CR>
        nnoremap <buffer> <silent> ctK  :<C-U>call PareditChangeSpec('ctK',1)<CR>
        nnoremap <buffer> <silent> cTK  :<C-U>call PareditChangeSpec('cTK',1)<CR>
        nnoremap <buffer> <silent> cfK  :<C-U>call PareditChangeSpec('cfK',1)<CR>
        nnoremap <buffer> <silent> cFK  :<C-U>call PareditChangeSpec('cFK',1)<CR>
        nnoremap <buffer> <silent> ctL  :<C-U>call PareditChangeSpec('ctL',1)<CR>
        nnoremap <buffer> <silent> cTL  :<C-U>call PareditChangeSpec('cTL',1)<CR>
        nnoremap <buffer> <silent> cfL  :<C-U>call PareditChangeSpec('cfL',1)<CR>
        nnoremap <buffer> <silent> cFL  :<C-U>call PareditChangeSpec('cFL',1)<CR>
        nnoremap <buffer> <silent> ctM  :<C-U>call PareditChangeSpec('ctM',1)<CR>
        nnoremap <buffer> <silent> cTM  :<C-U>call PareditChangeSpec('cTM',1)<CR>
        nnoremap <buffer> <silent> cfM  :<C-U>call PareditChangeSpec('cfM',1)<CR>
        nnoremap <buffer> <silent> cFM  :<C-U>call PareditChangeSpec('cFM',1)<CR>
        nnoremap <buffer> <silent> ctN  :<C-U>call PareditChangeSpec('ctN',1)<CR>
        nnoremap <buffer> <silent> cTN  :<C-U>call PareditChangeSpec('cTN',1)<CR>
        nnoremap <buffer> <silent> cfN  :<C-U>call PareditChangeSpec('cfN',1)<CR>
        nnoremap <buffer> <silent> cFN  :<C-U>call PareditChangeSpec('cFN',1)<CR>
        nnoremap <buffer> <silent> ctO  :<C-U>call PareditChangeSpec('ctO',1)<CR>
        nnoremap <buffer> <silent> cTO  :<C-U>call PareditChangeSpec('cTO',1)<CR>
        nnoremap <buffer> <silent> cfO  :<C-U>call PareditChangeSpec('cfO',1)<CR>
        nnoremap <buffer> <silent> cFO  :<C-U>call PareditChangeSpec('cFO',1)<CR>
        nnoremap <buffer> <silent> ctP  :<C-U>call PareditChangeSpec('ctP',1)<CR>
        nnoremap <buffer> <silent> cTP  :<C-U>call PareditChangeSpec('cTP',1)<CR>
        nnoremap <buffer> <silent> cfP  :<C-U>call PareditChangeSpec('cfP',1)<CR>
        nnoremap <buffer> <silent> cFP  :<C-U>call PareditChangeSpec('cFP',1)<CR>
        nnoremap <buffer> <silent> ctQ  :<C-U>call PareditChangeSpec('ctQ',1)<CR>
        nnoremap <buffer> <silent> cTQ  :<C-U>call PareditChangeSpec('cTQ',1)<CR>
        nnoremap <buffer> <silent> cfQ  :<C-U>call PareditChangeSpec('cfQ',1)<CR>
        nnoremap <buffer> <silent> cFQ  :<C-U>call PareditChangeSpec('cFQ',1)<CR>
        nnoremap <buffer> <silent> ctR  :<C-U>call PareditChangeSpec('ctR',1)<CR>
        nnoremap <buffer> <silent> cTR  :<C-U>call PareditChangeSpec('cTR',1)<CR>
        nnoremap <buffer> <silent> cfR  :<C-U>call PareditChangeSpec('cfR',1)<CR>
        nnoremap <buffer> <silent> cFR  :<C-U>call PareditChangeSpec('cFR',1)<CR>
        nnoremap <buffer> <silent> ctS  :<C-U>call PareditChangeSpec('ctS',1)<CR>
        nnoremap <buffer> <silent> cTS  :<C-U>call PareditChangeSpec('cTS',1)<CR>
        nnoremap <buffer> <silent> cfS  :<C-U>call PareditChangeSpec('cfS',1)<CR>
        nnoremap <buffer> <silent> cFS  :<C-U>call PareditChangeSpec('cFS',1)<CR>
        nnoremap <buffer> <silent> ctT  :<C-U>call PareditChangeSpec('ctT',1)<CR>
        nnoremap <buffer> <silent> cTT  :<C-U>call PareditChangeSpec('cTT',1)<CR>
        nnoremap <buffer> <silent> cfT  :<C-U>call PareditChangeSpec('cfT',1)<CR>
        nnoremap <buffer> <silent> cFT  :<C-U>call PareditChangeSpec('cFT',1)<CR>
        nnoremap <buffer> <silent> ctU  :<C-U>call PareditChangeSpec('ctU',1)<CR>
        nnoremap <buffer> <silent> cTU  :<C-U>call PareditChangeSpec('cTU',1)<CR>
        nnoremap <buffer> <silent> cfU  :<C-U>call PareditChangeSpec('cfU',1)<CR>
        nnoremap <buffer> <silent> cFU  :<C-U>call PareditChangeSpec('cFU',1)<CR>
        nnoremap <buffer> <silent> ctV  :<C-U>call PareditChangeSpec('ctV',1)<CR>
        nnoremap <buffer> <silent> cTV  :<C-U>call PareditChangeSpec('cTV',1)<CR>
        nnoremap <buffer> <silent> cfV  :<C-U>call PareditChangeSpec('cfV',1)<CR>
        nnoremap <buffer> <silent> cFV  :<C-U>call PareditChangeSpec('cFV',1)<CR>
        nnoremap <buffer> <silent> ctW  :<C-U>call PareditChangeSpec('ctW',1)<CR>
        nnoremap <buffer> <silent> cTW  :<C-U>call PareditChangeSpec('cTW',1)<CR>
        nnoremap <buffer> <silent> cfW  :<C-U>call PareditChangeSpec('cfW',1)<CR>
        nnoremap <buffer> <silent> cFW  :<C-U>call PareditChangeSpec('cFW',1)<CR>
        nnoremap <buffer> <silent> ctX  :<C-U>call PareditChangeSpec('ctX',1)<CR>
        nnoremap <buffer> <silent> cTX  :<C-U>call PareditChangeSpec('cTX',1)<CR>
        nnoremap <buffer> <silent> cfX  :<C-U>call PareditChangeSpec('cfX',1)<CR>
        nnoremap <buffer> <silent> cFX  :<C-U>call PareditChangeSpec('cFX',1)<CR>
        nnoremap <buffer> <silent> ctY  :<C-U>call PareditChangeSpec('ctY',1)<CR>
        nnoremap <buffer> <silent> cTY  :<C-U>call PareditChangeSpec('cTY',1)<CR>
        nnoremap <buffer> <silent> cfY  :<C-U>call PareditChangeSpec('cfY',1)<CR>
        nnoremap <buffer> <silent> cFY  :<C-U>call PareditChangeSpec('cFY',1)<CR>
        nnoremap <buffer> <silent> ctZ  :<C-U>call PareditChangeSpec('ctZ',1)<CR>
        nnoremap <buffer> <silent> cTZ  :<C-U>call PareditChangeSpec('cTZ',1)<CR>
        nnoremap <buffer> <silent> cfZ  :<C-U>call PareditChangeSpec('cfZ',1)<CR>
        nnoremap <buffer> <silent> cFZ  :<C-U>call PareditChangeSpec('cFZ',1)<CR>
        nnoremap <buffer> <silent> ct[  :<C-U>call PareditChangeSpec('ct[',1)<CR>
        nnoremap <buffer> <silent> cT[  :<C-U>call PareditChangeSpec('cT[',1)<CR>
        nnoremap <buffer> <silent> cf[  :<C-U>call PareditChangeSpec('cf[',1)<CR>
        nnoremap <buffer> <silent> cF[  :<C-U>call PareditChangeSpec('cF[',1)<CR>
        nnoremap <buffer> <silent> ct\  :<C-U>call PareditChangeSpec('ct\',1)<CR>
        nnoremap <buffer> <silent> cT\  :<C-U>call PareditChangeSpec('cT\',1)<CR>
        nnoremap <buffer> <silent> cf\  :<C-U>call PareditChangeSpec('cf\',1)<CR>
        nnoremap <buffer> <silent> cF\  :<C-U>call PareditChangeSpec('cF\',1)<CR>
        nnoremap <buffer> <silent> ct]  :<C-U>call PareditChangeSpec('ct]',1)<CR>
        nnoremap <buffer> <silent> cT]  :<C-U>call PareditChangeSpec('cT]',1)<CR>
        nnoremap <buffer> <silent> cf]  :<C-U>call PareditChangeSpec('cf]',1)<CR>
        nnoremap <buffer> <silent> cF]  :<C-U>call PareditChangeSpec('cF]',1)<CR>
        nnoremap <buffer> <silent> ct^  :<C-U>call PareditChangeSpec('ct^',1)<CR>
        nnoremap <buffer> <silent> cT^  :<C-U>call PareditChangeSpec('cT^',1)<CR>
        nnoremap <buffer> <silent> cf^  :<C-U>call PareditChangeSpec('cf^',1)<CR>
        nnoremap <buffer> <silent> cF^  :<C-U>call PareditChangeSpec('cF^',1)<CR>
        nnoremap <buffer> <silent> ct_  :<C-U>call PareditChangeSpec('ct_',1)<CR>
        nnoremap <buffer> <silent> cT_  :<C-U>call PareditChangeSpec('cT_',1)<CR>
        nnoremap <buffer> <silent> cf_  :<C-U>call PareditChangeSpec('cf_',1)<CR>
        nnoremap <buffer> <silent> cF_  :<C-U>call PareditChangeSpec('cF_',1)<CR>
        nnoremap <buffer> <silent> ct`  :<C-U>call PareditChangeSpec('ct`',1)<CR>
        nnoremap <buffer> <silent> cT`  :<C-U>call PareditChangeSpec('cT`',1)<CR>
        nnoremap <buffer> <silent> cf`  :<C-U>call PareditChangeSpec('cf`',1)<CR>
        nnoremap <buffer> <silent> cF`  :<C-U>call PareditChangeSpec('cF`',1)<CR>
        nnoremap <buffer> <silent> cta  :<C-U>call PareditChangeSpec('cta',1)<CR>
        nnoremap <buffer> <silent> cTa  :<C-U>call PareditChangeSpec('cTa',1)<CR>
        nnoremap <buffer> <silent> cfa  :<C-U>call PareditChangeSpec('cfa',1)<CR>
        nnoremap <buffer> <silent> cFa  :<C-U>call PareditChangeSpec('cFa',1)<CR>
        nnoremap <buffer> <silent> ctb  :<C-U>call PareditChangeSpec('ctb',1)<CR>
        nnoremap <buffer> <silent> cTb  :<C-U>call PareditChangeSpec('cTb',1)<CR>
        nnoremap <buffer> <silent> cfb  :<C-U>call PareditChangeSpec('cfb',1)<CR>
        nnoremap <buffer> <silent> cFb  :<C-U>call PareditChangeSpec('cFb',1)<CR>
        nnoremap <buffer> <silent> ctc  :<C-U>call PareditChangeSpec('ctc',1)<CR>
        nnoremap <buffer> <silent> cTc  :<C-U>call PareditChangeSpec('cTc',1)<CR>
        nnoremap <buffer> <silent> cfc  :<C-U>call PareditChangeSpec('cfc',1)<CR>
        nnoremap <buffer> <silent> cFc  :<C-U>call PareditChangeSpec('cFc',1)<CR>
        nnoremap <buffer> <silent> ctd  :<C-U>call PareditChangeSpec('ctd',1)<CR>
        nnoremap <buffer> <silent> cTd  :<C-U>call PareditChangeSpec('cTd',1)<CR>
        nnoremap <buffer> <silent> cfd  :<C-U>call PareditChangeSpec('cfd',1)<CR>
        nnoremap <buffer> <silent> cFd  :<C-U>call PareditChangeSpec('cFd',1)<CR>
        nnoremap <buffer> <silent> cte  :<C-U>call PareditChangeSpec('cte',1)<CR>
        nnoremap <buffer> <silent> cTe  :<C-U>call PareditChangeSpec('cTe',1)<CR>
        nnoremap <buffer> <silent> cfe  :<C-U>call PareditChangeSpec('cfe',1)<CR>
        nnoremap <buffer> <silent> cFe  :<C-U>call PareditChangeSpec('cFe',1)<CR>
        nnoremap <buffer> <silent> ctf  :<C-U>call PareditChangeSpec('ctf',1)<CR>
        nnoremap <buffer> <silent> cTf  :<C-U>call PareditChangeSpec('cTf',1)<CR>
        nnoremap <buffer> <silent> cff  :<C-U>call PareditChangeSpec('cff',1)<CR>
        nnoremap <buffer> <silent> cFf  :<C-U>call PareditChangeSpec('cFf',1)<CR>
        nnoremap <buffer> <silent> ctg  :<C-U>call PareditChangeSpec('ctg',1)<CR>
        nnoremap <buffer> <silent> cTg  :<C-U>call PareditChangeSpec('cTg',1)<CR>
        nnoremap <buffer> <silent> cfg  :<C-U>call PareditChangeSpec('cfg',1)<CR>
        nnoremap <buffer> <silent> cFg  :<C-U>call PareditChangeSpec('cFg',1)<CR>
        nnoremap <buffer> <silent> cth  :<C-U>call PareditChangeSpec('cth',1)<CR>
        nnoremap <buffer> <silent> cTh  :<C-U>call PareditChangeSpec('cTh',1)<CR>
        nnoremap <buffer> <silent> cfh  :<C-U>call PareditChangeSpec('cfh',1)<CR>
        nnoremap <buffer> <silent> cFh  :<C-U>call PareditChangeSpec('cFh',1)<CR>
        nnoremap <buffer> <silent> cti  :<C-U>call PareditChangeSpec('cti',1)<CR>
        nnoremap <buffer> <silent> cTi  :<C-U>call PareditChangeSpec('cTi',1)<CR>
        nnoremap <buffer> <silent> cfi  :<C-U>call PareditChangeSpec('cfi',1)<CR>
        nnoremap <buffer> <silent> cFi  :<C-U>call PareditChangeSpec('cFi',1)<CR>
        nnoremap <buffer> <silent> ctj  :<C-U>call PareditChangeSpec('ctj',1)<CR>
        nnoremap <buffer> <silent> cTj  :<C-U>call PareditChangeSpec('cTj',1)<CR>
        nnoremap <buffer> <silent> cfj  :<C-U>call PareditChangeSpec('cfj',1)<CR>
        nnoremap <buffer> <silent> cFj  :<C-U>call PareditChangeSpec('cFj',1)<CR>
        nnoremap <buffer> <silent> ctk  :<C-U>call PareditChangeSpec('ctk',1)<CR>
        nnoremap <buffer> <silent> cTk  :<C-U>call PareditChangeSpec('cTk',1)<CR>
        nnoremap <buffer> <silent> cfk  :<C-U>call PareditChangeSpec('cfk',1)<CR>
        nnoremap <buffer> <silent> cFk  :<C-U>call PareditChangeSpec('cFk',1)<CR>
        nnoremap <buffer> <silent> ctl  :<C-U>call PareditChangeSpec('ctl',1)<CR>
        nnoremap <buffer> <silent> cTl  :<C-U>call PareditChangeSpec('cTl',1)<CR>
        nnoremap <buffer> <silent> cfl  :<C-U>call PareditChangeSpec('cfl',1)<CR>
        nnoremap <buffer> <silent> cFl  :<C-U>call PareditChangeSpec('cFl',1)<CR>
        nnoremap <buffer> <silent> ctm  :<C-U>call PareditChangeSpec('ctm',1)<CR>
        nnoremap <buffer> <silent> cTm  :<C-U>call PareditChangeSpec('cTm',1)<CR>
        nnoremap <buffer> <silent> cfm  :<C-U>call PareditChangeSpec('cfm',1)<CR>
        nnoremap <buffer> <silent> cFm  :<C-U>call PareditChangeSpec('cFm',1)<CR>
        nnoremap <buffer> <silent> ctn  :<C-U>call PareditChangeSpec('ctn',1)<CR>
        nnoremap <buffer> <silent> cTn  :<C-U>call PareditChangeSpec('cTn',1)<CR>
        nnoremap <buffer> <silent> cfn  :<C-U>call PareditChangeSpec('cfn',1)<CR>
        nnoremap <buffer> <silent> cFn  :<C-U>call PareditChangeSpec('cFn',1)<CR>
        nnoremap <buffer> <silent> cto  :<C-U>call PareditChangeSpec('cto',1)<CR>
        nnoremap <buffer> <silent> cTo  :<C-U>call PareditChangeSpec('cTo',1)<CR>
        nnoremap <buffer> <silent> cfo  :<C-U>call PareditChangeSpec('cfo',1)<CR>
        nnoremap <buffer> <silent> cFo  :<C-U>call PareditChangeSpec('cFo',1)<CR>
        nnoremap <buffer> <silent> ctp  :<C-U>call PareditChangeSpec('ctp',1)<CR>
        nnoremap <buffer> <silent> cTp  :<C-U>call PareditChangeSpec('cTp',1)<CR>
        nnoremap <buffer> <silent> cfp  :<C-U>call PareditChangeSpec('cfp',1)<CR>
        nnoremap <buffer> <silent> cFp  :<C-U>call PareditChangeSpec('cFp',1)<CR>
        nnoremap <buffer> <silent> ctq  :<C-U>call PareditChangeSpec('ctq',1)<CR>
        nnoremap <buffer> <silent> cTq  :<C-U>call PareditChangeSpec('cTq',1)<CR>
        nnoremap <buffer> <silent> cfq  :<C-U>call PareditChangeSpec('cfq',1)<CR>
        nnoremap <buffer> <silent> cFq  :<C-U>call PareditChangeSpec('cFq',1)<CR>
        nnoremap <buffer> <silent> ctr  :<C-U>call PareditChangeSpec('ctr',1)<CR>
        nnoremap <buffer> <silent> cTr  :<C-U>call PareditChangeSpec('cTr',1)<CR>
        nnoremap <buffer> <silent> cfr  :<C-U>call PareditChangeSpec('cfr',1)<CR>
        nnoremap <buffer> <silent> cFr  :<C-U>call PareditChangeSpec('cFr',1)<CR>
        nnoremap <buffer> <silent> cts  :<C-U>call PareditChangeSpec('cts',1)<CR>
        nnoremap <buffer> <silent> cTs  :<C-U>call PareditChangeSpec('cTs',1)<CR>
        nnoremap <buffer> <silent> cfs  :<C-U>call PareditChangeSpec('cfs',1)<CR>
        nnoremap <buffer> <silent> cFs  :<C-U>call PareditChangeSpec('cFs',1)<CR>
        nnoremap <buffer> <silent> ctt  :<C-U>call PareditChangeSpec('ctt',1)<CR>
        nnoremap <buffer> <silent> cTt  :<C-U>call PareditChangeSpec('cTt',1)<CR>
        nnoremap <buffer> <silent> cft  :<C-U>call PareditChangeSpec('cft',1)<CR>
        nnoremap <buffer> <silent> cFt  :<C-U>call PareditChangeSpec('cFt',1)<CR>
        nnoremap <buffer> <silent> ctu  :<C-U>call PareditChangeSpec('ctu',1)<CR>
        nnoremap <buffer> <silent> cTu  :<C-U>call PareditChangeSpec('cTu',1)<CR>
        nnoremap <buffer> <silent> cfu  :<C-U>call PareditChangeSpec('cfu',1)<CR>
        nnoremap <buffer> <silent> cFu  :<C-U>call PareditChangeSpec('cFu',1)<CR>
        nnoremap <buffer> <silent> ctv  :<C-U>call PareditChangeSpec('ctv',1)<CR>
        nnoremap <buffer> <silent> cTv  :<C-U>call PareditChangeSpec('cTv',1)<CR>
        nnoremap <buffer> <silent> cfv  :<C-U>call PareditChangeSpec('cfv',1)<CR>
        nnoremap <buffer> <silent> cFv  :<C-U>call PareditChangeSpec('cFv',1)<CR>
        nnoremap <buffer> <silent> ctw  :<C-U>call PareditChangeSpec('ctw',1)<CR>
        nnoremap <buffer> <silent> cTw  :<C-U>call PareditChangeSpec('cTw',1)<CR>
        nnoremap <buffer> <silent> cfw  :<C-U>call PareditChangeSpec('cfw',1)<CR>
        nnoremap <buffer> <silent> cFw  :<C-U>call PareditChangeSpec('cFw',1)<CR>
        nnoremap <buffer> <silent> ctx  :<C-U>call PareditChangeSpec('ctx',1)<CR>
        nnoremap <buffer> <silent> cTx  :<C-U>call PareditChangeSpec('cTx',1)<CR>
        nnoremap <buffer> <silent> cfx  :<C-U>call PareditChangeSpec('cfx',1)<CR>
        nnoremap <buffer> <silent> cFx  :<C-U>call PareditChangeSpec('cFx',1)<CR>
        nnoremap <buffer> <silent> cty  :<C-U>call PareditChangeSpec('cty',1)<CR>
        nnoremap <buffer> <silent> cTy  :<C-U>call PareditChangeSpec('cTy',1)<CR>
        nnoremap <buffer> <silent> cfy  :<C-U>call PareditChangeSpec('cfy',1)<CR>
        nnoremap <buffer> <silent> cFy  :<C-U>call PareditChangeSpec('cFy',1)<CR>
        nnoremap <buffer> <silent> ctz  :<C-U>call PareditChangeSpec('ctz',1)<CR>
        nnoremap <buffer> <silent> cTz  :<C-U>call PareditChangeSpec('cTz',1)<CR>
        nnoremap <buffer> <silent> cfz  :<C-U>call PareditChangeSpec('cfz',1)<CR>
        nnoremap <buffer> <silent> cFz  :<C-U>call PareditChangeSpec('cFz',1)<CR>
        nnoremap <buffer> <silent> ct{  :<C-U>call PareditChangeSpec('ct{',1)<CR>
        nnoremap <buffer> <silent> cT{  :<C-U>call PareditChangeSpec('cT{',1)<CR>
        nnoremap <buffer> <silent> cf{  :<C-U>call PareditChangeSpec('cf{',1)<CR>
        nnoremap <buffer> <silent> cF{  :<C-U>call PareditChangeSpec('cF{',1)<CR>
        nnoremap <buffer> <silent> ct\|  :<C-U>call PareditChangeSpec('ct\|',1)<CR>
        nnoremap <buffer> <silent> cT\|  :<C-U>call PareditChangeSpec('cT\|',1)<CR>
        nnoremap <buffer> <silent> cf\|  :<C-U>call PareditChangeSpec('cf\|',1)<CR>
        nnoremap <buffer> <silent> cF\|  :<C-U>call PareditChangeSpec('cF\|',1)<CR>
        nnoremap <buffer> <silent> ct}  :<C-U>call PareditChangeSpec('ct}',1)<CR>
        nnoremap <buffer> <silent> cT}  :<C-U>call PareditChangeSpec('cT}',1)<CR>
        nnoremap <buffer> <silent> cf}  :<C-U>call PareditChangeSpec('cf}',1)<CR>
        nnoremap <buffer> <silent> cF}  :<C-U>call PareditChangeSpec('cF}',1)<CR>
        nnoremap <buffer> <silent> ct~  :<C-U>call PareditChangeSpec('ct~',1)<CR>
        nnoremap <buffer> <silent> cT~  :<C-U>call PareditChangeSpec('cT~',1)<CR>
        nnoremap <buffer> <silent> cf~  :<C-U>call PareditChangeSpec('cf~',1)<CR>
        nnoremap <buffer> <silent> cF~  :<C-U>call PareditChangeSpec('cF~',1)<CR>

        nnoremap <buffer> <silent> do           do
        nnoremap <buffer> <silent> dp           dp
        call RepeatableNNoRemap('p', ':<C-U>call PareditPut("p")')
        call RepeatableNNoRemap('P', ':<C-U>call PareditPut("P")')
        call RepeatableNNoRemap(g:paredit_leader . 'w(', ':<C-U>call PareditWrap("(",")")')
        execute 'vnoremap <buffer> <silent> ' . g:paredit_leader.'w(  :<C-U>call PareditWrapSelection("(",")")<CR>'
        call RepeatableNNoRemap(g:paredit_leader . 'w"', ':<C-U>call PareditWrap('."'".'"'."','".'"'."')")
        execute 'vnoremap <buffer> <silent> ' . g:paredit_leader.'w"  :<C-U>call PareditWrapSelection('."'".'"'."','".'"'."')<CR>"
        " Spliec s-expression killing backward/forward
        execute 'nmap     <buffer> <silent> ' . g:paredit_leader.'<Up>    d[(:<C-U>call PareditSplice()<CR>'
        execute 'nmap     <buffer> <silent> ' . g:paredit_leader.'<Down>  d])%:<C-U>call PareditSplice()<CR>'
        call RepeatableNNoRemap(g:paredit_leader . 'I', ':<C-U>call PareditRaise()')
        if &ft =~ s:fts_balancing_all_brackets
            inoremap <buffer> <expr>   [            PareditInsertOpening('[',']')
            inoremap <buffer> <silent> ]            <C-R>=PareditInsertClosing('[',']')<CR>
            inoremap <buffer> <expr>   {            PareditInsertOpening('{','}')
            inoremap <buffer> <silent> }            <C-R>=PareditInsertClosing('{','}')<CR>
            call RepeatableNNoRemap(g:paredit_leader . 'w[', ':<C-U>call PareditWrap("[","]")')
            execute 'vnoremap <buffer> <silent> ' . g:paredit_leader.'w[  :<C-U>call PareditWrapSelection("[","]")<CR>'
            call RepeatableNNoRemap(g:paredit_leader . 'w{', ':<C-U>call PareditWrap("{","}")')
            execute 'vnoremap <buffer> <silent> ' . g:paredit_leader.'w{  :<C-U>call PareditWrapSelection("{","}")<CR>'
        endif

        if g:paredit_shortmaps
            " Shorter keymaps: old functionality of KEY is remapped to <Leader>KEY
            call RepeatableNNoRemap('<', ':<C-U>call PareditMoveLeft()')
            call RepeatableNNoRemap('>', ':<C-U>call PareditMoveRight()')
            call RepeatableNNoRemap('O', ':<C-U>call PareditSplit()')
            call RepeatableNNoRemap('J', ':<C-U>call PareditJoin()')
            call RepeatableNNoRemap('W', ':<C-U>call PareditWrap("(",")")')
            vnoremap <buffer> <silent> W            :<C-U>call PareditWrapSelection('(',')')<CR>
            call RepeatableNNoRemap('S', ':<C-U>call PareditSplice()')
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'<  :<C-U>normal! <<CR>'
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'>  :<C-U>normal! ><CR>'
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'O  :<C-U>normal! O<CR>'
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'J  :<C-U>normal! J<CR>'
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'W  :<C-U>normal! W<CR>'
            execute 'vnoremap <buffer> <silent> ' . g:paredit_leader.'W  :<C-U>normal! W<CR>'
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'S  :<C-U>normal! S<CR>'
        else
            " Longer keymaps with <Leader> prefix
            nnoremap <buffer> <silent> S            V:<C-U>call PareditChange(visualmode(),1)<CR>
            call RepeatableNNoRemap(g:paredit_leader . '<', ':<C-U>call PareditMoveLeft()')
            call RepeatableNNoRemap(g:paredit_leader . '>', ':<C-U>call PareditMoveRight()')
            call RepeatableNNoRemap(g:paredit_leader . 'O', ':<C-U>call PareditSplit()')
            call RepeatableNNoRemap(g:paredit_leader . 'J', ':<C-U>call PareditJoin()')
            call RepeatableNNoRemap(g:paredit_leader . 'W', ':<C-U>call PareditWrap("(",")")')
            execute 'vnoremap <buffer> <silent> ' . g:paredit_leader.'W  :<C-U>call PareditWrapSelection("(",")")<CR>'
            call RepeatableNNoRemap(g:paredit_leader . 'S', ':<C-U>call PareditSplice()')
        endif

        if !exists( 'g:slimv_loaded' )
            execute 'nnoremap <buffer> <silent> ' . g:paredit_leader.'(  :<C-U>call PareditToggle()<CR>'
        endif

        if g:paredit_electric_return && mapcheck( "<CR>", "i" ) == ""
            " Do not override any possible mapping for <Enter>
            inoremap <buffer> <expr>   <CR>         PareditEnter()
        endif
    else
        " Paredit mode is off: remove keybindings
        silent! iunmap <buffer> (
        silent! iunmap <buffer> )
        silent! iunmap <buffer> "
        silent! iunmap <buffer> <BS>
        silent! iunmap <buffer> <C-h>
        silent! iunmap <buffer> <Del>
        silent! unmap  <buffer> (
        silent! unmap  <buffer> )
        silent! unmap  <buffer> [[
        silent! unmap  <buffer> ]]
        silent! unmap  <buffer> x
        silent! unmap  <buffer> <Del>
        silent! unmap  <buffer> X
        silent! unmap  <buffer> s
        silent! unmap  <buffer> D
        silent! unmap  <buffer> C
        silent! unmap  <buffer> d
        silent! unmap  <buffer> c
        silent! unmap  <buffer> dd
        silent! unmap  <buffer> cc
        silent! unmap  <buffer> cw
        silent! unmap  <buffer> cW
        silent! unmap  <buffer> cb
        silent! unmap  <buffer> ciw
        silent! unmap  <buffer> caw

        silent! unmap <buffer> cB
        silent! unmap <buffer> ce
        silent! unmap <buffer> cE
        silent! unmap <buffer> ca{
        silent! unmap <buffer> ci{
        silent! unmap <buffer> ca}
        silent! unmap <buffer> ci}
        silent! unmap <buffer> ca[
        silent! unmap <buffer> ci[
        silent! unmap <buffer> ca]
        silent! unmap <buffer> ci]
        silent! unmap <buffer> ca(
        silent! unmap <buffer> ci(
        silent! unmap <buffer> ca)
        silent! unmap <buffer> ci)
        silent! unmap <buffer> ci'
        silent! unmap <buffer> ca'
        silent! unmap <buffer> ci"
        silent! unmap <buffer> ca"
        "silent! unmap <buffer> c%

        silent! unmap <buffer> ct!
        silent! unmap <buffer> cT!
        silent! unmap <buffer> cf!
        silent! unmap <buffer> cF!
        silent! unmap <buffer> ct"
        silent! unmap <buffer> cT"
        silent! unmap <buffer> cf"
        silent! unmap <buffer> cF"
        silent! unmap <buffer> ct#
        silent! unmap <buffer> cT#
        silent! unmap <buffer> cf#
        silent! unmap <buffer> cF#
        silent! unmap <buffer> ct$
        silent! unmap <buffer> cT$
        silent! unmap <buffer> cf$
        silent! unmap <buffer> cF$
        silent! unmap <buffer> ct%
        silent! unmap <buffer> cT%
        silent! unmap <buffer> cf%
        silent! unmap <buffer> cF%
        silent! unmap <buffer> ct&
        silent! unmap <buffer> cT&
        silent! unmap <buffer> cf&
        silent! unmap <buffer> cF&
        silent! unmap <buffer> ct'
        silent! unmap <buffer> cT'
        silent! unmap <buffer> cf'
        silent! unmap <buffer> cF'
        silent! unmap <buffer> ct(
        silent! unmap <buffer> cT(
        silent! unmap <buffer> cf(
        silent! unmap <buffer> cF(
        silent! unmap <buffer> ct)
        silent! unmap <buffer> cT)
        silent! unmap <buffer> cf)
        silent! unmap <buffer> cF)
        silent! unmap <buffer> ct*
        silent! unmap <buffer> cT*
        silent! unmap <buffer> cf*
        silent! unmap <buffer> cF*
        silent! unmap <buffer> ct+
        silent! unmap <buffer> cT+
        silent! unmap <buffer> cf+
        silent! unmap <buffer> cF+
        silent! unmap <buffer> ct,
        silent! unmap <buffer> cT,
        silent! unmap <buffer> cf,
        silent! unmap <buffer> cF,
        silent! unmap <buffer> ct-
        silent! unmap <buffer> cT-
        silent! unmap <buffer> cf-
        silent! unmap <buffer> cF-
        silent! unmap <buffer> ct.
        silent! unmap <buffer> cT.
        silent! unmap <buffer> cf.
        silent! unmap <buffer> cF.
        silent! unmap <buffer> ct/
        silent! unmap <buffer> cT/
        silent! unmap <buffer> cf/
        silent! unmap <buffer> cF/
        silent! unmap <buffer> ct0
        silent! unmap <buffer> cT0
        silent! unmap <buffer> cf0
        silent! unmap <buffer> cF0
        silent! unmap <buffer> ct1
        silent! unmap <buffer> cT1
        silent! unmap <buffer> cf1
        silent! unmap <buffer> cF1
        silent! unmap <buffer> ct2
        silent! unmap <buffer> cT2
        silent! unmap <buffer> cf2
        silent! unmap <buffer> cF2
        silent! unmap <buffer> ct3
        silent! unmap <buffer> cT3
        silent! unmap <buffer> cf3
        silent! unmap <buffer> cF3
        silent! unmap <buffer> ct4
        silent! unmap <buffer> cT4
        silent! unmap <buffer> cf4
        silent! unmap <buffer> cF4
        silent! unmap <buffer> ct5
        silent! unmap <buffer> cT5
        silent! unmap <buffer> cf5
        silent! unmap <buffer> cF5
        silent! unmap <buffer> ct6
        silent! unmap <buffer> cT6
        silent! unmap <buffer> cf6
        silent! unmap <buffer> cF6
        silent! unmap <buffer> ct7
        silent! unmap <buffer> cT7
        silent! unmap <buffer> cf7
        silent! unmap <buffer> cF7
        silent! unmap <buffer> ct8
        silent! unmap <buffer> cT8
        silent! unmap <buffer> cf8
        silent! unmap <buffer> cF8
        silent! unmap <buffer> ct9
        silent! unmap <buffer> cT9
        silent! unmap <buffer> cf9
        silent! unmap <buffer> cF9
        silent! unmap <buffer> ct:
        silent! unmap <buffer> cT:
        silent! unmap <buffer> cf:
        silent! unmap <buffer> cF:
        silent! unmap <buffer> ct;
        silent! unmap <buffer> cT;
        silent! unmap <buffer> cf;
        silent! unmap <buffer> cF;
        silent! unmap <buffer> ct<
        silent! unmap <buffer> cT<
        silent! unmap <buffer> cf<
        silent! unmap <buffer> cF<
        silent! unmap <buffer> ct=
        silent! unmap <buffer> cT=
        silent! unmap <buffer> cf=
        silent! unmap <buffer> cF=
        silent! unmap <buffer> ct>
        silent! unmap <buffer> cT>
        silent! unmap <buffer> cf>
        silent! unmap <buffer> cF>
        silent! unmap <buffer> ct?
        silent! unmap <buffer> cT?
        silent! unmap <buffer> cf?
        silent! unmap <buffer> cF?
        silent! unmap <buffer> ct@
        silent! unmap <buffer> cT@
        silent! unmap <buffer> cf@
        silent! unmap <buffer> cF@
        silent! unmap <buffer> ctA
        silent! unmap <buffer> cTA
        silent! unmap <buffer> cfA
        silent! unmap <buffer> cFA
        silent! unmap <buffer> ctB
        silent! unmap <buffer> cTB
        silent! unmap <buffer> cfB
        silent! unmap <buffer> cFB
        silent! unmap <buffer> ctC
        silent! unmap <buffer> cTC
        silent! unmap <buffer> cfC
        silent! unmap <buffer> cFC
        silent! unmap <buffer> ctD
        silent! unmap <buffer> cTD
        silent! unmap <buffer> cfD
        silent! unmap <buffer> cFD
        silent! unmap <buffer> ctE
        silent! unmap <buffer> cTE
        silent! unmap <buffer> cfE
        silent! unmap <buffer> cFE
        silent! unmap <buffer> ctF
        silent! unmap <buffer> cTF
        silent! unmap <buffer> cfF
        silent! unmap <buffer> cFF
        silent! unmap <buffer> ctG
        silent! unmap <buffer> cTG
        silent! unmap <buffer> cfG
        silent! unmap <buffer> cFG
        silent! unmap <buffer> ctH
        silent! unmap <buffer> cTH
        silent! unmap <buffer> cfH
        silent! unmap <buffer> cFH
        silent! unmap <buffer> ctI
        silent! unmap <buffer> cTI
        silent! unmap <buffer> cfI
        silent! unmap <buffer> cFI
        silent! unmap <buffer> ctJ
        silent! unmap <buffer> cTJ
        silent! unmap <buffer> cfJ
        silent! unmap <buffer> cFJ
        silent! unmap <buffer> ctK
        silent! unmap <buffer> cTK
        silent! unmap <buffer> cfK
        silent! unmap <buffer> cFK
        silent! unmap <buffer> ctL
        silent! unmap <buffer> cTL
        silent! unmap <buffer> cfL
        silent! unmap <buffer> cFL
        silent! unmap <buffer> ctM
        silent! unmap <buffer> cTM
        silent! unmap <buffer> cfM
        silent! unmap <buffer> cFM
        silent! unmap <buffer> ctN
        silent! unmap <buffer> cTN
        silent! unmap <buffer> cfN
        silent! unmap <buffer> cFN
        silent! unmap <buffer> ctO
        silent! unmap <buffer> cTO
        silent! unmap <buffer> cfO
        silent! unmap <buffer> cFO
        silent! unmap <buffer> ctP
        silent! unmap <buffer> cTP
        silent! unmap <buffer> cfP
        silent! unmap <buffer> cFP
        silent! unmap <buffer> ctQ
        silent! unmap <buffer> cTQ
        silent! unmap <buffer> cfQ
        silent! unmap <buffer> cFQ
        silent! unmap <buffer> ctR
        silent! unmap <buffer> cTR
        silent! unmap <buffer> cfR
        silent! unmap <buffer> cFR
        silent! unmap <buffer> ctS
        silent! unmap <buffer> cTS
        silent! unmap <buffer> cfS
        silent! unmap <buffer> cFS
        silent! unmap <buffer> ctT
        silent! unmap <buffer> cTT
        silent! unmap <buffer> cfT
        silent! unmap <buffer> cFT
        silent! unmap <buffer> ctU
        silent! unmap <buffer> cTU
        silent! unmap <buffer> cfU
        silent! unmap <buffer> cFU
        silent! unmap <buffer> ctV
        silent! unmap <buffer> cTV
        silent! unmap <buffer> cfV
        silent! unmap <buffer> cFV
        silent! unmap <buffer> ctW
        silent! unmap <buffer> cTW
        silent! unmap <buffer> cfW
        silent! unmap <buffer> cFW
        silent! unmap <buffer> ctX
        silent! unmap <buffer> cTX
        silent! unmap <buffer> cfX
        silent! unmap <buffer> cFX
        silent! unmap <buffer> ctY
        silent! unmap <buffer> cTY
        silent! unmap <buffer> cfY
        silent! unmap <buffer> cFY
        silent! unmap <buffer> ctZ
        silent! unmap <buffer> cTZ
        silent! unmap <buffer> cfZ
        silent! unmap <buffer> cFZ
        silent! unmap <buffer> ct[
        silent! unmap <buffer> cT[
        silent! unmap <buffer> cf[
        silent! unmap <buffer> cF[
        silent! unmap <buffer> ct\
        silent! unmap <buffer> cT\
        silent! unmap <buffer> cf\
        silent! unmap <buffer> cF\
        silent! unmap <buffer> ct]
        silent! unmap <buffer> cT]
        silent! unmap <buffer> cf]
        silent! unmap <buffer> cF]
        silent! unmap <buffer> ct^
        silent! unmap <buffer> cT^
        silent! unmap <buffer> cf^
        silent! unmap <buffer> cF^
        silent! unmap <buffer> ct_
        silent! unmap <buffer> cT_
        silent! unmap <buffer> cf_
        silent! unmap <buffer> cF_
        silent! unmap <buffer> ct`
        silent! unmap <buffer> cT`
        silent! unmap <buffer> cf`
        silent! unmap <buffer> cF`
        silent! unmap <buffer> cta
        silent! unmap <buffer> cTa
        silent! unmap <buffer> cfa
        silent! unmap <buffer> cFa
        silent! unmap <buffer> ctb
        silent! unmap <buffer> cTb
        silent! unmap <buffer> cfb
        silent! unmap <buffer> cFb
        silent! unmap <buffer> ctc
        silent! unmap <buffer> cTc
        silent! unmap <buffer> cfc
        silent! unmap <buffer> cFc
        silent! unmap <buffer> ctd
        silent! unmap <buffer> cTd
        silent! unmap <buffer> cfd
        silent! unmap <buffer> cFd
        silent! unmap <buffer> cte
        silent! unmap <buffer> cTe
        silent! unmap <buffer> cfe
        silent! unmap <buffer> cFe
        silent! unmap <buffer> ctf
        silent! unmap <buffer> cTf
        silent! unmap <buffer> cff
        silent! unmap <buffer> cFf
        silent! unmap <buffer> ctg
        silent! unmap <buffer> cTg
        silent! unmap <buffer> cfg
        silent! unmap <buffer> cFg
        silent! unmap <buffer> cth
        silent! unmap <buffer> cTh
        silent! unmap <buffer> cfh
        silent! unmap <buffer> cFh
        silent! unmap <buffer> cti
        silent! unmap <buffer> cTi
        silent! unmap <buffer> cfi
        silent! unmap <buffer> cFi
        silent! unmap <buffer> ctj
        silent! unmap <buffer> cTj
        silent! unmap <buffer> cfj
        silent! unmap <buffer> cFj
        silent! unmap <buffer> ctk
        silent! unmap <buffer> cTk
        silent! unmap <buffer> cfk
        silent! unmap <buffer> cFk
        silent! unmap <buffer> ctl
        silent! unmap <buffer> cTl
        silent! unmap <buffer> cfl
        silent! unmap <buffer> cFl
        silent! unmap <buffer> ctm
        silent! unmap <buffer> cTm
        silent! unmap <buffer> cfm
        silent! unmap <buffer> cFm
        silent! unmap <buffer> ctn
        silent! unmap <buffer> cTn
        silent! unmap <buffer> cfn
        silent! unmap <buffer> cFn
        silent! unmap <buffer> cto
        silent! unmap <buffer> cTo
        silent! unmap <buffer> cfo
        silent! unmap <buffer> cFo
        silent! unmap <buffer> ctp
        silent! unmap <buffer> cTp
        silent! unmap <buffer> cfp
        silent! unmap <buffer> cFp
        silent! unmap <buffer> ctq
        silent! unmap <buffer> cTq
        silent! unmap <buffer> cfq
        silent! unmap <buffer> cFq
        silent! unmap <buffer> ctr
        silent! unmap <buffer> cTr
        silent! unmap <buffer> cfr
        silent! unmap <buffer> cFr
        silent! unmap <buffer> cts
        silent! unmap <buffer> cTs
        silent! unmap <buffer> cfs
        silent! unmap <buffer> cFs
        silent! unmap <buffer> ctt
        silent! unmap <buffer> cTt
        silent! unmap <buffer> cft
        silent! unmap <buffer> cFt
        silent! unmap <buffer> ctu
        silent! unmap <buffer> cTu
        silent! unmap <buffer> cfu
        silent! unmap <buffer> cFu
        silent! unmap <buffer> ctv
        silent! unmap <buffer> cTv
        silent! unmap <buffer> cfv
        silent! unmap <buffer> cFv
        silent! unmap <buffer> ctw
        silent! unmap <buffer> cTw
        silent! unmap <buffer> cfw
        silent! unmap <buffer> cFw
        silent! unmap <buffer> ctx
        silent! unmap <buffer> cTx
        silent! unmap <buffer> cfx
        silent! unmap <buffer> cFx
        silent! unmap <buffer> cty
        silent! unmap <buffer> cTy
        silent! unmap <buffer> cfy
        silent! unmap <buffer> cFy
        silent! unmap <buffer> ctz
        silent! unmap <buffer> cTz
        silent! unmap <buffer> cfz
        silent! unmap <buffer> cFz
        silent! unmap <buffer> ct{
        silent! unmap <buffer> cT{
        silent! unmap <buffer> cf{
        silent! unmap <buffer> cF{
        silent! unmap <buffer> ct\|
        silent! unmap <buffer> cT\|
        silent! unmap <buffer> cf\|
        silent! unmap <buffer> cF\|
        silent! unmap <buffer> ct}
        silent! unmap <buffer> cT}
        silent! unmap <buffer> cf}
        silent! unmap <buffer> cF}
        silent! unmap <buffer> ct~
        silent! unmap <buffer> cT~
        silent! unmap <buffer> cf~
        silent! unmap <buffer> cF~

        if &ft =~ s:fts_balancing_all_brackets
            silent! iunmap <buffer> [
            silent! iunmap <buffer> ]
            silent! iunmap <buffer> {
            silent! iunmap <buffer> }
        endif
        if mapcheck( "<CR>", "i" ) == "PareditEnter()"
            " Remove only if we have added this mapping
            silent! iunmap <buffer> <CR>
        endif
    endif
endfunction

" Run the command normally but append a call to repeat#set afterwards
function! RepeatableMap(map_type, keys, command)
  let escaped_keys = substitute(a:keys, '["<]', '\\\0', "g")
  execute a:map_type . ' <silent> <buffer> ' .
        \ a:keys . ' ' . a:command .
        \ '\|silent! call repeat#set("' . escaped_keys . '")<CR>'
endfunction

function! RepeatableNMap(keys, command)
  call RepeatableMap('nmap', a:keys, a:command)
endfunction

function! RepeatableNNoRemap(keys, command)
  call RepeatableMap('nnoremap', a:keys, a:command)
endfunction

" Include all prefix and special characters in 'iskeyword'
function! s:SetKeyword()
    let old_value = &iskeyword
    if &ft =~ s:fts_balancing_all_brackets
        setlocal iskeyword+=+,-,*,/,%,<,=,>,:,$,?,!,@-@,94,~,#,\|,&
    else
        setlocal iskeyword+=+,-,*,/,%,<,=,>,:,$,?,!,@-@,94,~,#,\|,&,.,{,},[,]
    endif
    return old_value
endfunction

" General Paredit operator function
function! PareditOpfunc( func, type, visualmode )
    let sel_save = &selection
    let ve_save = &virtualedit
    set virtualedit=all
    let regname = v:register
    let save_0 = getreg( '0' )
    let oldreg = (s:repeat < s:count) ? getreg( regname ) : ''
    if s:repeat > 0
        let s:repeat = s:repeat - 1
    endif

    if a:visualmode  " Invoked from Visual mode, use '< and '> marks.
        silent exe "normal! `<" . a:type . "`>"
    elseif a:type == 'line'
        let &selection = "inclusive"
        silent exe "normal! '[V']"
    elseif a:type == 'block'
        let &selection = "inclusive"
        silent exe "normal! `[\<C-V>`]"
    else
        let &selection = "inclusive"
        silent exe "normal! `[v`]"
    endif

    if !g:paredit_mode || (a:visualmode && (a:type == 'block' || a:type == "\<C-V>"))
        " Block mode is too difficult to handle at the moment
        silent exe "normal! d"
        let putreg = oldreg . getreg( regname )
    else
        silent exe "normal! y"
        let putreg = oldreg . getreg( regname )
        if a:func == 'd'
            " Register "0 is corrupted by the above 'y' command
            call setreg( '0', save_0 )
        elseif a:visualmode && &selection == "inclusive" && len(getline("'>")) < col("'>") && len(putreg) > 0
            " Remove extra space added at the end of line when selection=inclusive, all, or onemore
            let putreg = putreg[:-2]
        endif

        " Find and keep unbalanced matched characters in the region
        let instring = s:InsideString( line("'<"), col("'<") )
        if col("'>") > 1 && !s:InsideString( line("'<"), col("'<") - 1 )
            " We are at the beginning of the string
            let instring = 0
        endif
        let matched = s:GetMatchedChars( putreg, instring, s:InsideComment( line("'<"), col("'<") ) )
        let matched = s:Unbalanced( matched )
        let matched = substitute( matched, '\s', '', 'g' )

        if matched == ''
            if a:func == 'c' && (a:type == 'v' || a:type == 'V' || a:type == 'char')
                silent exe "normal! gvc"
            else
                silent exe "normal! gvd"
            endif
        else
            silent exe "normal! gvc" . matched
            silent exe "normal! l"
            let offs = len(matched)
            if matched[0] =~ b:any_closing_char
                let offs = offs + 1
            endif
            if a:func == 'd'
                let offs = offs - 1
            elseif instring && matched == '"'
                " Keep cursor inside the double quotes
                let offs = offs + 1
            endif
            if offs > 0
                silent exe "normal! " . string(offs) . "h"
            endif
        endif
    endif

    let &selection = sel_save
    let &virtualedit = ve_save
    if a:func == 'd' && regname == '"'
        " Do not currupt the '"' register and hence the "0 register
        call setreg( '1', putreg )
    endif
    call setreg( regname, putreg )
endfunction

" Set delete mode also saving repeat count
function! PareditSetDelete( count )
    let s:count  = a:count
    let s:repeat = s:count
    set opfunc=PareditDelete
endfunction

" General delete operator handling
function! PareditDelete( type, ... )
    call PareditOpfunc( 'd', a:type, a:0 )
    if s:repeat > 0
        call feedkeys( "." )
    endif
endfunction

" General change operator handling
function! PareditChange( type, ... )
    let ve_save = &virtualedit
    set virtualedit=all
    call PareditOpfunc( 'c', a:type, a:0 )
    if len(getline('.')) == 0
        let v:lnum = line('.')
        let expr = &indentexpr
        if expr == ''
            " No special 'indentexpr', call default lisp indent
            let expr = 'lispindent(v:lnum)'
        endif
        execute "call setline( v:lnum, repeat( ' ', " . expr . " ) )"
        call cursor(v:lnum, len(getline(v:lnum))+1)
    else
        normal! l
    endif
    startinsert
    let &virtualedit = ve_save
endfunction

" Delete v:count number of lines
function! PareditDeleteLines()
    if v:count > 1
        silent exe "normal! V" . (v:count-1) . "j\<Esc>"
    else
        silent exe "normal! V\<Esc>"
    endif
    call PareditDelete(visualmode(),1)
endfunction

" Change v:count number of lines
function! PareditChangeLines()
    if v:count > 1
        silent exe "normal! V" . (v:count-1) . "j\<Esc>"
    else
        silent exe "normal! V\<Esc>"
    endif
    call PareditChange(visualmode(),1)
endfunction

" Handle special change command, e.g. cw
" Check if we may revert to its original Vim function
" This way '.' can be used to repeat the command
function! PareditChangeSpec( cmd, dir )
    let line = getline( '.' )
    if a:dir == 0
        " Changing backwards
        let c =  col( '.' ) - 2
        while c >= 0 && line[c] =~ b:any_matched_char
            " Shouldn't delete a matched character, just move left
            call feedkeys( 'h', 'n')
            let c = c - 1
        endwhile
        if c < 0 && line[0] =~ b:any_matched_char
            " Can't help, still on matched character, insert instead
            call feedkeys( 'i', 'n')
            return
        endif
    else
        " Changing forward
        let c =  col( '.' ) - 1
        while c < len(line) && line[c] =~ b:any_matched_char
            " Shouldn't delete a matched character, just move right
            call feedkeys( 'l', 'n')
            let c = c + 1
        endwhile
        if c == len(line)
            " Can't help, still on matched character, append instead
            call feedkeys( 'a', 'n')
            return
        endif
    endif

    " Safe to use Vim's built-in change function
    call feedkeys( a:cmd, 'n')
endfunction

" Paste text from put register in a balanced way
function! PareditPut( cmd )
    let regname = v:register
    let reg_save = getreg( regname )
    let putreg = reg_save

    " Find unpaired matched characters by eliminating paired ones
    let matched = s:GetMatchedChars( putreg, s:InsideString(), s:InsideComment() )
    let matched = s:Unbalanced( matched )

    if matched !~ '\S\+'
        " Register contents is balanced, perform default put function
        silent exe "normal! " . (v:count>1 ? v:count : '') . '"' . regname . a:cmd
        return
    endif

    " Replace all unpaired matched characters with a space in order to keep balance
    let i = 0
    while i < len( putreg )
        if matched[i] !~ '\s'
            let putreg = strpart( putreg, 0, i ) . ' ' . strpart( putreg, i+1 )
        endif
        let i = i + 1
    endwhile

    " Store balanced text in put register and call the appropriate put command
    call setreg( regname, putreg )
    silent exe "normal! " . (v:count>1 ? v:count : '') . '"' . regname . a:cmd
    call setreg( regname, reg_save )
endfunction

" Toggle paredit mode
function! PareditToggle()
    " Don't disable paredit if it was not initialized yet for the current buffer
    if exists( 'b:paredit_init') || g:paredit_mode == 0
        let g:paredit_mode = 1 - g:paredit_mode
    endif
    echo g:paredit_mode ? 'Paredit mode on' : 'Paredit mode off'
    call PareditInitBuffer()
endfunction

" Does the current syntax item match the given regular expression?
function! s:SynIDMatch( regexp, line, col, match_eol )
    let col  = a:col
    if a:match_eol && col > len( getline( a:line ) )
        let col = col - 1
    endif
    return synIDattr( synID( a:line, col, 0), 'name' ) =~ a:regexp
endfunction

" Expression used to check whether we should skip a match with searchpair()
function! s:SkipExpr()
    let l = line('.')
    let c = col('.')
    if synIDattr(synID(l, c, 0), "name") =~ "[Ss]tring\\|[Cc]omment\\|[Ss]pecial\\|clojureRegexp\\|clojurePattern"
        " Skip parens inside strings, comments, special elements
        return 1
    endif
    if getline(l)[c-2] == "\\" && getline(l)[c-3] != "\\"
        " Skip parens escaped by '\'
        return 1
    endif
    return 0
endfunction

" Is the current cursor position inside a comment?
function! s:InsideComment( ... )
    let l = a:0 ? a:1 : line('.')
    let c = a:0 ? a:2 : col('.')
    if &syntax == ''
        " No help from syntax engine,
        " remove strings and search for ';' up to the cursor position
        let line = strpart( getline(l), 0, c - 1 )
        let line = substitute( line, '\\"', '', 'g' )
        let line = substitute( line, '"[^"]*"', '', 'g' )
        return match( line, ';' ) >= 0
    endif
    if s:SynIDMatch( 'clojureComment', l, c, 1 )
        if strpart( getline(l), c-1, 2 ) == '#_' || strpart( getline(l), c-2, 2 ) == '#_'
            " This is a commented out clojure form of type #_(...), treat it as regular form
            return 0
        endif
    endif
    return s:SynIDMatch( '[Cc]omment', l, c, 1 )
endfunction

" Is the current cursor position inside a string?
function! s:InsideString( ... )
    let l = a:0 ? a:1 : line('.')
    let c = a:0 ? a:2 : col('.')
    if &syntax == ''
        " No help from syntax engine,
        " count quote characters up to the cursor position
        let line = strpart( getline(l), 0, c - 1 )
        let line = substitute( line, '\\"', '', 'g' )
        let quotes = substitute( line, '[^"]', '', 'g' )
        return len(quotes) % 2
    endif
    " VimClojure and vim-clojure-static define special syntax for regexps
    return s:SynIDMatch( '[Ss]tring\|clojureRegexp\|clojurePattern', l, c, 0 )
endfunction

" Is this a Slimv or VimClojure REPL buffer?
function! s:IsReplBuffer()
    if exists( 'b:slimv_repl_buffer' ) || exists( 'b:vimclojure_repl' )
        return 1
    else
        return 0
    endif
endfunction

" Get Slimv or VimClojure REPL buffer last command prompt position
" Return [0, 0] if this is not the REPL buffer
function! s:GetReplPromptPos()
    if !s:IsReplBuffer()
        return [0, 0]
    endif
    if exists( 'b:vimclojure_repl')
        let cur_pos = getpos( '.' )
        call cursor( line( '$' ), 1)
        call cursor( line( '.' ), col( '$') )
        call search( b:vimclojure_namespace . '=>', 'bcW' )
        let target_pos = getpos( '.' )[1:2]
        call setpos( '.', cur_pos )
        return target_pos
    else
        return [ b:repl_prompt_line, b:repl_prompt_col ]
    endif
endfunction

" Is the current top level form balanced, i.e all opening delimiters
" have a matching closing delimiter
function! s:IsBalanced()
    let l = line( '.' )
    let c =  col( '.' )
    let line = getline( '.' )
    if c > len(line)
        let c = len(line)
    endif
    let matchb = max( [l-g:paredit_matchlines, 1] )
    let matchf = min( [l+g:paredit_matchlines, line('$')] )
    let [prompt, cp] = s:GetReplPromptPos()
    if s:IsReplBuffer() && l >= prompt && matchb < prompt
        " Do not go before the last command prompt in the REPL buffer
        let matchb = prompt
    endif
    if line[c-1] == '('
        let p1 = searchpair( '(', '', ')', 'brnmWc', 's:SkipExpr()', matchb )
        let p2 = searchpair( '(', '', ')',  'rnmW' , 's:SkipExpr()', matchf )
    elseif line[c-1] == ')'
        let p1 = searchpair( '(', '', ')', 'brnmW' , 's:SkipExpr()', matchb )
        let p2 = searchpair( '(', '', ')',  'rnmWc', 's:SkipExpr()', matchf )
    else
        let p1 = searchpair( '(', '', ')', 'brnmW' , 's:SkipExpr()', matchb )
        let p2 = searchpair( '(', '', ')',  'rnmW' , 's:SkipExpr()', matchf )
    endif
    if p1 != p2
        " Number of opening and closing parens differ
        return 0
    endif

    if &ft =~ s:fts_balancing_all_brackets
        if line[c-1] == '['
            let b1 = searchpair( '\[', '', '\]', 'brnmWc', 's:SkipExpr()', matchb )
            let b2 = searchpair( '\[', '', '\]',  'rnmW' , 's:SkipExpr()', matchf )
        elseif line[c-1] == ']'
            let b1 = searchpair( '\[', '', '\]', 'brnmW' , 's:SkipExpr()', matchb )
            let b2 = searchpair( '\[', '', '\]',  'rnmWc', 's:SkipExpr()', matchf )
        else
            let b1 = searchpair( '\[', '', '\]', 'brnmW' , 's:SkipExpr()', matchb )
            let b2 = searchpair( '\[', '', '\]',  'rnmW' , 's:SkipExpr()', matchf )
        endif
        if b1 != b2
            " Number of opening and closing brackets differ
            return 0
        endif
        if line[c-1] == '{'
            let b1 = searchpair( '{', '', '}', 'brnmWc', 's:SkipExpr()', matchb )
            let b2 = searchpair( '{', '', '}',  'rnmW' , 's:SkipExpr()', matchf )
        elseif line[c-1] == '}'
            let b1 = searchpair( '{', '', '}', 'brnmW' , 's:SkipExpr()', matchb )
            let b2 = searchpair( '{', '', '}',  'rnmWc', 's:SkipExpr()', matchf )
        else
            let b1 = searchpair( '{', '', '}', 'brnmW' , 's:SkipExpr()', matchb )
            let b2 = searchpair( '{', '', '}',  'rnmW' , 's:SkipExpr()', matchf )
        endif
        if b1 != b2
            " Number of opening and closing curly braces differ
            return 0
        endif
    endif
    return 1
endfunction

" Filter out all non-matched characters from the region
function! s:GetMatchedChars( lines, start_in_string, start_in_comment )
    let inside_string  = a:start_in_string
    let inside_comment = a:start_in_comment
    let matched = repeat( ' ', len( a:lines ) )
    let i = 0
    while i < len( a:lines )
        if inside_string
            " We are inside a string, skip parens, wait for closing '"'
            " but skip escaped \" characters
            if a:lines[i] == '"' && a:lines[i-1] != '\'
                let matched = strpart( matched, 0, i ) . a:lines[i] . strpart( matched, i+1 )
                let inside_string = 0
            endif
        elseif inside_comment
            " We are inside a comment, skip parens, wait for end of line
            if a:lines[i] == "\n"
                let inside_comment = 0
            endif
        elseif i > 0 && a:lines[i-1] == '\' && (i < 2 || a:lines[i-2] != '\')
            " This is an escaped character, ignore it
        else
            " We are outside of strings and comments, now we shall count parens
            if a:lines[i] == '"'
                let matched = strpart( matched, 0, i ) . a:lines[i] . strpart( matched, i+1 )
                let inside_string = 1
            endif
            if a:lines[i] == ';'
                let inside_comment = 1
            endif
            if a:lines[i] =~ b:any_openclose_char
                let matched = strpart( matched, 0, i ) . a:lines[i] . strpart( matched, i+1 )
            endif
        endif
        let i = i + 1
    endwhile
    return matched
endfunction

" Find unpaired matched characters by eliminating paired ones
function! s:Unbalanced( matched )
    let matched = a:matched
    let tmp = matched
    while 1
        let matched = tmp
        let tmp = substitute( tmp, '(\(\s*\))',   ' \1 ', 'g')
        if &ft =~ s:fts_balancing_all_brackets
            let tmp = substitute( tmp, '\[\(\s*\)\]', ' \1 ', 'g')
            let tmp = substitute( tmp, '{\(\s*\)}',   ' \1 ', 'g')
        endif
        let tmp = substitute( tmp, '"\(\s*\)"',   ' \1 ', 'g')
        if tmp == matched
            " All paired chars eliminated
            let tmp = substitute( tmp, ')\(\s*\)(',   ' \1 ', 'g')
            if &ft =~ s:fts_balancing_all_brackets
                let tmp = substitute( tmp, '\]\(\s*\)\[', ' \1 ', 'g')
                let tmp = substitute( tmp, '}\(\s*\){',   ' \1 ', 'g')
            endif
            if tmp == matched
                " Also no more inverse pairs can be eliminated
                break
            endif
        endif
    endwhile
    return matched
endfunction

" Find opening matched character
function! PareditFindOpening( open, close, select )
    let open  = escape( a:open , '[]' )
    let close = escape( a:close, '[]' )
    call searchpair( open, '', close, 'bW', 's:SkipExpr()' )
    if a:select
        call searchpair( open, '', close, 'W', 's:SkipExpr()' )
        let save_ve = &ve
        set ve=all
        normal! lvh
        let &ve = save_ve
        call searchpair( open, '', close, 'bW', 's:SkipExpr()' )
        if &selection == 'inclusive'
            " Trim last character from the selection, it will be included anyway
            normal! oho
        endif
    endif
endfunction

" Find closing matched character
function! PareditFindClosing( open, close, select )
    let open  = escape( a:open , '[]' )
    let close = escape( a:close, '[]' )
    if a:select
        let line = getline( '.' )
        if line[col('.')-1] != a:open
            normal! h
        endif
        call searchpair( open, '', close, 'W', 's:SkipExpr()' )
        call searchpair( open, '', close, 'bW', 's:SkipExpr()' )
        normal! v
        call searchpair( open, '', close, 'W', 's:SkipExpr()' )
        if &selection != 'inclusive'
            normal! l
        endif
    else
        call searchpair( open, '', close, 'W', 's:SkipExpr()' )
    endif
endfunction

" Returns the nearest opening character to the cursor
" Used for smart jumping in Clojure
function! PareditSmartJumpOpening( select )
    let [paren_line, paren_col] = searchpairpos('(', '', ')', 'bWn', 's:SkipExpr()')
    let [bracket_line, bracket_col] = searchpairpos('\[', '', '\]', 'bWn', 's:SkipExpr()')
    let [brace_line, brace_col] = searchpairpos('{', '', '}', 'bWn', 's:SkipExpr()')
    let paren_score = paren_line * 10000 + paren_col
    let bracket_score = bracket_line * 10000 + bracket_col
    let brace_score = brace_line * 10000 + brace_col
    if (brace_score > paren_score || paren_score == 0) && (brace_score > bracket_score || bracket_score == 0) && brace_score != 0
	call PareditFindOpening('{','}', a:select)
    elseif (bracket_score > paren_score || paren_score == 0) && bracket_score != 0
	call PareditFindOpening('[',']', a:select)
    else
	call PareditFindOpening('(',')', a:select)
    endif
endfunction

" Returns the nearest opening character to the cursor
" Used for smart jumping in Clojure
function! PareditSmartJumpClosing( select )
    let [paren_line, paren_col] = searchpairpos('(', '', ')', 'Wn', 's:SkipExpr()')
    let [bracket_line, bracket_col] = searchpairpos('\[', '', '\]', 'Wn', 's:SkipExpr()')
    let [brace_line, brace_col] = searchpairpos('{', '', '}', 'Wn', 's:SkipExpr()')
    let paren_score = paren_line * 10000 + paren_col
    let bracket_score = bracket_line * 10000 + bracket_col
    let brace_score = brace_line * 10000 + brace_col
    if (brace_score < paren_score || paren_score == 0) && (brace_score < bracket_score || bracket_score == 0) && brace_score != 0
	call PareditFindClosing('{','}', a:select)
    elseif (bracket_score < paren_score || paren_score == 0) && bracket_score != 0
	call PareditFindClosing('[',']', a:select)
    else
	call PareditFindClosing('(',')', a:select)
    endif
endfunction

" Find defun start backwards
function! PareditFindDefunBck()
    let l = line( '.' )
    let matchb = max( [l-g:paredit_matchlines, 1] )
    let oldpos = getpos( '.' )
    let newpos = searchpairpos( '(', '', ')', 'brW', 's:SkipExpr()', matchb )
    if newpos[0] == 0
        " Already standing on a defun, find the end of the previous one
        let newpos = searchpos( ')', 'bW' )
        while newpos[0] != 0 && (s:InsideComment() || s:InsideString())
            let newpos = searchpos( ')', 'W' )
        endwhile
        if newpos[0] == 0
            " No ')' found, don't move cursor
            call setpos( '.', oldpos )
        else
            " Find opening paren
            let pairpos = searchpairpos( '(', '', ')', 'brW', 's:SkipExpr()', matchb )
            if pairpos[0] == 0
                " ')' has no matching pair
                call setpos( '.', oldpos )
            endif
        endif
    endif
endfunction

" Find defun start forward
function! PareditFindDefunFwd()
    let l = line( '.' )
    let matchf = min( [l+g:paredit_matchlines, line('$')] )
    let oldpos = getpos( '.' )
    call searchpair( '(', '', ')', 'brW', 's:SkipExpr()', matchf )
    normal! %
    let newpos = searchpos( '(', 'W' )
    while newpos[0] != 0 && (s:InsideComment() || s:InsideString())
        let newpos = searchpos( '(', 'W' )
    endwhile
    if newpos[0] == 0
        " No '(' found, don't move cursor
        call setpos( '.', oldpos )
    endif
endfunction

" Insert opening type of a paired character, like ( or [.
function! PareditInsertOpening( open, close )
    if !g:paredit_mode || s:InsideComment() || s:InsideString() || !s:IsBalanced()
        return a:open
    endif
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    if pos > 0 && line[pos-1] == '\' && (pos < 2 || line[pos-2] != '\')
        " About to enter a \( or \[
        return a:open
    elseif line[pos] !~ b:any_wsclose_char && pos < len( line )
        " Add a space after if needed
        let retval = a:open . a:close . " \<Left>\<Left>"
    else
        let retval = a:open . a:close . "\<Left>"
    endif
    if pos > 0 && line[pos-1] !~ b:any_wsopen_char && line[pos-1] !~ s:any_macro_prefix
        " Add a space before if needed
        let retval = " " . retval
    endif
    return retval
endfunction

" Re-gather electric returns up
function! s:ReGatherUp()
    if g:paredit_electric_return && getline('.') =~ '^\s*)'
        " Re-gather electric returns in the current line for ')'
        normal! k
        while getline( line('.') ) =~ '^\s*$'
            " Delete all empty lines
            normal! ddk
        endwhile
        normal! Jl
    elseif g:paredit_electric_return && getline('.') =~ '^\s*\(\]\|}\)' && &ft =~ s:fts_balancing_all_brackets
        " Re-gather electric returns in the current line for ']' and '}'
        normal! k
        while getline( line('.') ) =~ '^\s*$'
            " Delete all empty lines
            normal! ddk
        endwhile
        call setline( line('.'), substitute( line, '\s*$', '', 'g' ) )
        normal! Jxl
    endif
    " Already have the desired character, move right
    normal! l
endfunction

" Insert closing type of a paired character, like ) or ].
function! PareditInsertClosing( open, close )
    let retval = ""
    if pumvisible()
        let retval = "\<C-Y>"
    endif
    let save_ve = &ve
    set ve=all
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    if !g:paredit_mode || s:InsideComment() || s:InsideString() || !s:IsBalanced()
        call setline( line('.'), line[0 : pos-1] . a:close . line[pos : -1] )
        normal! l
        let &ve = save_ve
        return retval
    endif
    if pos > 0 && line[pos-1] == '\' && (pos < 2 || line[pos-2] != '\')
        " About to enter a \) or \]
        call setline( line('.'), line[0 : pos-1] . a:close . line[pos : -1] )
        normal! l
        let &ve = save_ve
        return retval
    elseif line[pos] == a:close
        call s:ReGatherUp()
        let &ve = save_ve
        return retval
    endif
    let open  = escape( a:open , '[]' )
    let close = escape( a:close, '[]' )
    let newpos = searchpairpos( open, '', close, 'nW', 's:SkipExpr()' )
    if g:paredit_electric_return && newpos[0] > line('.')
        " Closing paren is in a line below, check if there are electric returns to re-gather
        while getline('.') =~ '^\s*$'
            " Delete all empty lines above the cursor
            normal! ddk
        endwhile
        let oldpos = getpos( '.' )
        normal! j
        while getline('.') =~ '^\s*$'
            " Delete all empty lines below the cursor
            normal! dd
        endwhile
        let nextline = substitute( getline('.'), '\s', '', 'g' )
        call setpos( '.', oldpos )
        if len(nextline) > 0 && nextline[0] == ')'
            " Re-gather electric returns in the line of the closing ')'
            call setline( line('.'), substitute( getline('.'), '\s*$', '', 'g' ) )
            normal! Jl
            let &ve = save_ve
            return retval
        endif
        if len(nextline) > 0 && nextline[0] =~ '\]\|}' && &ft =~ s:fts_balancing_all_brackets
            " Re-gather electric returns in the line of the closing ']' or '}'
            call setline( line('.'), substitute( line, '\s*$', '', 'g' ) )
            normal! Jxl
            let &ve = save_ve
            return retval
        endif
    elseif g:paredit_electric_return && line =~ '^\s*)'
        " Re-gather electric returns in the current line
        call s:ReGatherUp()
        let &ve = save_ve
        return retval
    endif
    if searchpair( open, '', close, 'W', 's:SkipExpr()' ) > 0
        normal! l
    endif
    "TODO: indent after going to closing character
    let &ve = save_ve
    return retval
endfunction

" Insert an (opening or closing) double quote
function! PareditInsertQuotes()
    if !g:paredit_mode || s:InsideComment()
        return '"'
    endif
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    if pos > 0 && line[pos-1] == '\' && (pos < 2 || line[pos-2] != '\')
        " About to enter a \"
        return '"'
    elseif s:InsideString()
        "TODO: skip comments in search(...)
        if line[pos] == '"'
            " Standing on a ", just move to the right
            return "\<Right>"
        elseif search('[^\\]"\|^"', 'nW') == 0
            " We don't have any closing ", insert one
            return '"'
        else
            " Move to the closing "
            return "\<C-O>:call search('" . '[^\\]"\|^"' . "','eW')\<CR>\<Right>"
        endif
    else
        " Outside of string: insert a pair of ""
        return '""' . "\<Left>"
    endif
endfunction

" Handle <Enter> keypress, insert electric return if applicable
function! PareditEnter()
    if pumvisible()
        " Pressing <CR> in a pop up selects entry.
        return "\<C-Y>"
    else
        let line = getline( '.' )
        let pos = col( '.' ) - 1
        if g:paredit_electric_return && pos > 0 && line[pos] =~ b:any_closing_char && !s:InsideString() && s:IsBalanced()
            " Electric Return
            return "\<CR>\<CR>\<Up>"
        else
            " Regular Return
            return "\<CR>"
        endif
    endif
endfunction

" Handle <BS> keypress
function! PareditBackspace( repl_mode )
    let [lp, cp] = s:GetReplPromptPos()
    if a:repl_mode && line( "." ) == lp && col( "." ) <= cp
        if col( "." ) == cp
            return "\<BS> "
        else
            " No BS allowed before the previous EOF mark in the REPL
            " i.e. don't delete Lisp prompt
            return ""
        endif
    endif

    if !g:paredit_mode || s:InsideComment()
        return "\<BS>"
    endif

    let line = getline( '.' )
    let pos = col( '.' ) - 1

    if pos == 0
        " We are at the beginning of the line
        return "\<BS>"
    elseif s:InsideString() && line[pos-1] =~ b:any_openclose_char
        " Deleting a paren inside a string
        return "\<BS>"
    elseif pos > 1 && line[pos-1] =~ b:any_matched_char && line[pos-2] == '\' && (pos < 3 || line[pos-3] != '\')
        " Deleting an escaped matched character
        return "\<BS>\<BS>"
    elseif line[pos-1] !~ b:any_matched_char
        " Deleting a non-special character
        return "\<BS>"
    elseif line[pos-1] != '"' && !s:IsBalanced()
        " Current top-form is unbalanced, can't retain paredit mode
        return "\<BS>"
    endif

    if line[pos-1:pos] =~ b:any_matched_pair
        " Deleting an empty character-pair
        return "\<Right>\<BS>\<BS>"
    else
        " Character-pair is not empty, don't delete just move inside
        return "\<Left>"
    endif
endfunction

" Handle <Del> keypress
function! PareditDel()
    if !g:paredit_mode || s:InsideComment()
        return "\<Del>"
    endif

    let line = getline( '.' )
    let pos = col( '.' ) - 1

    if pos == len(line)
        " We are at the end of the line
        return "\<Del>"
    elseif line[pos] == '\' && line[pos+1] =~ b:any_matched_char && (pos < 1 || line[pos-1] != '\')
        " Deleting an escaped matched character
        return "\<Del>\<Del>"
    elseif line[pos] !~ b:any_matched_char
        " Erasing a non-special character
        return "\<Del>"
    elseif line[pos] != '"' && !s:IsBalanced()
        " Current top-form is unbalanced, can't retain paredit mode
        return "\<Del>"
    elseif pos == 0
        return "\<Right>"
    endif

    if line[pos-1:pos] =~ b:any_matched_pair
        " Erasing an empty character-pair
        return "\<Left>\<Del>\<Del>"
    else
        " Character-pair is not empty, don't erase just move inside
        return "\<Right>"
    endif
endfunction

" Initialize yank position list
function! s:InitYankPos()
    call setreg( v:register, '' )
    let s:yank_pos = []
endfunction

" Add position to the yank list
function! s:AddYankPos( pos )
    let s:yank_pos = [a:pos] + s:yank_pos
endfunction

" Remove the head of yank position list and return it
function! s:RemoveYankPos()
    if len(s:yank_pos) > 0
        let pos = s:yank_pos[0]
        let s:yank_pos = s:yank_pos[1:]
        return pos
    else
        return 0
    endif
endfunction

" Forward erasing a character in normal mode, do not check if current form balanced
function! s:EraseFwd( count, startcol )
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    let reg = ''
    let ve_save = &virtualedit
    set virtualedit=all
    let c = a:count
    while c > 0
        if line[pos] == '\' && line[pos+1] =~ b:any_matched_char && (pos < 1 || line[pos-1] != '\')
            " Erasing an escaped matched character
            let reg = reg . line[pos : pos+1]
            let line = strpart( line, 0, pos ) . strpart( line, pos+2 )
        elseif s:InsideComment() && line[pos] == ';' && a:startcol >= 0
            " Erasing the whole comment, only when erasing a block of characters
            let reg = reg . strpart( line, pos )
            let line = strpart( line, 0, pos )
        elseif s:InsideComment() || ( s:InsideString() && line[pos] != '"' )
            " Erasing any character inside string or comment
            let chars = split(strpart(line, pos), '\zs')
            if len(chars) > 0
                " Identify the character to be erased and it's length
                " The length may be >1 if this is a multi-byte character
                let ch = chars[0]
                let reg = reg . ch
                let line = strpart( line, 0, pos ) . strpart( line, pos+len(ch) )
            endif
        elseif pos > 0 && line[pos-1:pos] =~ b:any_matched_pair
            if pos > a:startcol
                " Erasing an empty character-pair
                let p2 = s:RemoveYankPos()
                let reg = strpart( reg, 0, p2 ) . line[pos-1] . strpart( reg, p2 )
                let reg = reg . line[pos]
                let line = strpart( line, 0, pos-1 ) . strpart( line, pos+1 )
                let pos = pos - 1
                normal! h
            else
                " Can't erase character-pair: it would move the cursor before startcol
                let pos = pos + 1
                normal! l
            endif
        elseif line[pos] =~ b:any_matched_char
            " Character-pair is not empty, don't erase just move inside
            call s:AddYankPos( len(reg) )
            let pos = pos + 1
            normal! l
        elseif pos < len(line) && pos >= a:startcol
            " Erasing a non-special character
            let chars = split(strpart(line, pos), '\zs')
            if len(chars) > 0
                " Identify the character to be erased and it's length
                " The length may be >1 if this is a multi-byte character
                let ch = chars[0]
                let reg = reg . ch
                let line = strpart( line, 0, pos ) . strpart( line, pos+len(ch) )
            endif
        endif
        let c = c - 1
    endwhile
    let &virtualedit = ve_save
    call setline( '.', line )
    call setreg( v:register, reg )
endfunction

" Backward erasing a character in normal mode, do not check if current form balanced
function! s:EraseBck( count )
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    let reg = ''
    let c = a:count
    while c > 0 && pos > 0
        if pos > 1 && line[pos-2] == '\' && line[pos-1] =~ b:any_matched_char && (pos < 3 || line[pos-3] != '\')
            " Erasing an escaped matched character
            let reg = reg . line[pos-2 : pos-1]
            let line = strpart( line, 0, pos-2 ) . strpart( line, pos )
            normal! h
            let pos = pos - 1
        elseif s:InsideComment() || ( s:InsideString() && line[pos-1] != '"' )
            let chars = split(strpart(line, 0, pos), '\zs')
            if len(chars) > 0
                " Identify the character to be erased and it's length
                " The length may be >1 if this is a multi-byte character
                let ch = chars[-1]
                let reg = reg . ch
                let line = strpart( line, 0, pos-len(ch) ) . strpart( line, pos )
                let pos = pos - len(ch) + 1
            endif
        elseif line[pos-1:pos] =~ b:any_matched_pair
            " Erasing an empty character-pair
            let p2 = s:RemoveYankPos()
            let reg = strpart( reg, 0, p2 ) . line[pos-1] . strpart( reg, p2 )
            let reg = reg . line[pos]
            let line = strpart( line, 0, pos-1 ) . strpart( line, pos+1 )
        elseif line[pos-1] =~ b:any_matched_char
            " Character-pair is not empty, don't erase
            call s:AddYankPos( len(reg) )
        else
            " Erasing a non-special character
            let chars = split(strpart(line, 0, pos), '\zs')
            if len(chars) > 0
                " Identify the character to be erased and it's length
                " The length may be >1 if this is a multi-byte character
                let ch = chars[-1]
                let reg = reg . ch
                let line = strpart( line, 0, pos-len(ch) ) . strpart( line, pos )
                let pos = pos - len(ch) + 1
            endif
        endif
        normal! h
        let pos = pos - 1
        let c = c - 1
    endwhile
    call setline( '.', line )
    call setreg( v:register, reg )
endfunction

" Forward erasing a character in normal mode
function! PareditEraseFwd()
    if !g:paredit_mode || !s:IsBalanced()
        if v:count > 0
            silent execute 'normal! ' . v:count . 'x'
        else
            normal! x
        endif
        return
    endif

    call s:InitYankPos()
    call s:EraseFwd( v:count1, -1 )
endfunction

" Backward erasing a character in normal mode
function! PareditEraseBck()
    if !g:paredit_mode || !s:IsBalanced()
        if v:count > 0
            silent execute 'normal! ' . v:count . 'X'
        else
            normal! X
        endif
        return
    endif

    call s:InitYankPos()
    call s:EraseBck( v:count1 )
endfunction

" Find beginning of previous element (atom or sub-expression) in a form
" skip_whitespc: skip whitespaces before the previous element
function! s:PrevElement( skip_whitespc )
    let [l0, c0] = [line( '.' ), col( '.' )]
    let symbol_pos = [0, 0]
    let symbol_end = [0, 0]

    " Move to the beginning of the prefix if any
    let line = getline( '.' )
    let c = col('.') - 1
    if c > 0 && line[c-1] =~ s:any_macro_prefix
        normal! h
    endif

    let moved = 0
    while 1
        " Go to previous character
        if !moved
            let [l1, c1] = [line( '.' ), col( '.' )]
            let save_ww = &whichwrap
            set whichwrap=
            normal! h
            let &whichwrap = save_ww
        endif
        let moved = 0
        let [l, c] = [line( '.' ), col( '.' )]

        if [l, c] == [l1, c1]
            " Beginning of line reached
            if symbol_pos != [0, 0]
                let symbol_end = [l, c]
                if !a:skip_whitespc && !s:InsideString()
                    " Newline before previous symbol
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c]
                endif
            endif
            normal! k$
            let [l, c] = [line( '.' ), col( '.' )]
            if [l, c] == [l1, c1]
                " Beginning of file reached: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
            endif
            let moved = 1
        elseif s:InsideComment()
            " Skip comments
        else
            let line = getline( '.' )
            if s:InsideString() && !(a:skip_whitespc && line[c] =~ '\s' && symbol_end != [0, 0])
                let symbol_pos = [l, c]
            elseif symbol_pos == [0, 0]
                if line[c-1] =~ b:any_closing_char
                    " Skip to the beginning of this sub-expression
                    let symbol_pos = [l, c]
                    normal! %
                    let line2 = getline( '.' )
                    let c2 = col('.') - 1
                    if c2 > 0 && line2[c2-1] =~ s:any_macro_prefix
                        normal! h
                    endif
                elseif line[c-1] =~ b:any_opening_char
                    " Opening delimiter found: stop
                    call setpos( '.', [0, l0, c0, 0] )
                    return [0, 0]
                elseif line[c-1] =~ '\S'
                    " Previous symbol starting
                    let symbol_pos = [l, c]
                endif
            else
                if line[c-1] =~ b:any_opening_char || (a:skip_whitespc && line[c-1] =~ '\S' && symbol_end != [0, 0])
                    " Previous symbol beginning reached, opening delimiter or second previous symbol starting
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c+1]
                elseif line[c-1] =~ '\s' || symbol_pos[0] != l
                    " Whitespace before previous symbol
                    let symbol_end = [l, c]
                    if !a:skip_whitespc
                        call setpos( '.', [0, l0, c0, 0] )
                        return [l, c+1]
                    endif
                endif
            endif
        endif
    endwhile
endfunction

" Find end of next element (atom or sub-expression) in a form
" skip_whitespc: skip whitespaces after the next element
function! s:NextElement( skip_whitespc )
    let [l0, c0] = [line( '.' ), col( '.' )]
    let symbol_pos = [0, 0]
    let symbol_end = [0, 0]

    while 1
        " Go to next character
        let [l1, c1] = [line( '.' ), col( '.' )]
        let save_ww = &whichwrap
        set whichwrap=
        normal! l
        let &whichwrap = save_ww
        let [l, c] = [line( '.' ), col( '.' )]

        " Skip comments
        while [l, c] == [l1, c1] || s:InsideComment()
            if symbol_pos != [0, 0]
                let symbol_end = [l, c]
                if !a:skip_whitespc && !s:InsideString()
                    " Next symbol ended with comment
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c + ([l, c] == [l1, c1])]
                endif
            endif
            normal! 0j0
            let [l, c] = [line( '.' ), col( '.' )]
            if [l, c] == [l1, c1]
                " End of file reached: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
            endif
        endwhile

        let line = getline( '.' )
        if s:InsideString() && !(a:skip_whitespc && line[c-2] =~ '\s' && symbol_end != [0, 0])
            let symbol_pos = [l, c]
        elseif symbol_pos == [0, 0]
            if line[c-1] =~ s:any_macro_prefix && line[c] =~ b:any_opening_char
                " Skip to the end of this prefixed sub-expression
                let symbol_pos = [l, c]
                normal! l%
            elseif line[c-1] =~ b:any_opening_char
                " Skip to the end of this sub-expression
                let symbol_pos = [l, c]
                normal! %
            elseif line[c-1] =~ b:any_closing_char
                " Closing delimiter found: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
            elseif line[c-1] =~ '\S'
                " Next symbol starting
                let symbol_pos = [l, c]
            endif
        else
            if line[c-1] =~ b:any_closing_char || (a:skip_whitespc && line[c-1] =~ '\S' && symbol_end != [0, 0])
                " Next symbol ended, closing delimiter or second next symbol starting
                call setpos( '.', [0, l0, c0, 0] )
                return [l, c]
            elseif line[c-1] =~ '\s' || symbol_pos[0] != l
                " Next symbol ending with whitespace
                let symbol_end = [l, c]
                if !a:skip_whitespc
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c]
                endif
            endif
        endif
    endwhile
endfunction

" Move character from [l0, c0] to [l1, c1]
" Set position to [l1, c1]
function! s:MoveChar( l0, c0, l1, c1 )
    let line = getline( a:l0 )
    let c = line[a:c0-1]
    if a:l1 == a:l0
        " Move character inside line
        if a:c1 > a:c0
            let line = strpart( line, 0, a:c0-1 ) . strpart( line, a:c0, a:c1-a:c0-1 ) . c . strpart( line, a:c1-1 )
            call setline( a:l0, line )
            call setpos( '.', [0, a:l1, a:c1-1, 0] )
        else
            let line = strpart( line, 0, a:c1-1 ) . c . strpart( line, a:c1-1, a:c0-a:c1 ) . strpart( line, a:c0 )
            call setline( a:l0, line )
            call setpos( '.', [0, a:l1, a:c1, 0] )
        endif
    else
        " Move character to another line
        let line = strpart( line, 0, a:c0-1 ) . strpart( line, a:c0 )
        call setline( a:l0, line )
        let line1 = getline( a:l1 )
        if a:c1 > 1
            let line1 = strpart( line1, 0, a:c1-1 ) . c . strpart( line1, a:c1-1 )
            call setline( a:l1, line1 )
            call setpos( '.', [0, a:l1, a:c1, 0] )
        else
            let line1 = c . line1
            call setline( a:l1, line1 )
            call setpos( '.', [0, a:l1, 1, 0] )
        endif
    endif
endfunction

" Find a paren nearby to move
function! s:FindParenNearby()
    let line = getline( '.' )
    let c0 =  col( '.' )
    if line[c0-1] !~ b:any_openclose_char
        " OK, we are not standing on a paren to move, but check if there is one nearby
        if (c0 < 2 || line[c0-2] !~ b:any_openclose_char) && line[c0] =~ b:any_openclose_char
            normal! l
        elseif c0 > 1 && line[c0-2] =~ b:any_openclose_char && line[c0] !~ b:any_openclose_char
            normal! h
        endif
    endif

    " Skip macro prefix character
    let c0 =  col( '.' )
    if line[c0-1] =~ s:any_macro_prefix && line[c0] =~ b:any_opening_char
        normal! l
    endif

    " If still not standing on a paren then find the next closing one
    if line[c0-1] !~ b:any_openclose_char
        call search(b:any_closing_char, 'W')
    endif
endfunction

" Reindent current form
function! PareditReindentForm()
    let l = line('.')
    let c = col('.')
    let old_indent = len(matchstr(getline(l), '^\s*'))
    normal! =ib
    let new_indent = len(matchstr(getline(l), '^\s*'))
    call cursor( l, c + new_indent - old_indent )
endfunction

" Move delimiter one atom or s-expression to the left
function! PareditMoveLeft()
    call s:FindParenNearby()

    let line = getline( '.' )
    let l0 = line( '.' )
    let c0 =  col( '.' )

    if line[c0-1] =~ b:any_opening_char
        let closing = 0
    elseif line[c0-1] =~ b:any_closing_char
        let closing = 1
    else
        " Can move only delimiters
        return
    endif

    let [lp, cp] = s:GetReplPromptPos()
    let [l1, c1] = s:PrevElement( closing )
    if [l1, c1] == [0, 0]
        " No previous element found
        return
    elseif [lp, cp] != [0, 0] && l0 >= lp && (l1 < lp || (l1 == lp && c1 < cp))
        " Do not go before the last command prompt in the REPL buffer
        return
    endif
    if !closing && c0 > 0 && line[c0-2] =~ s:any_macro_prefix
        call s:MoveChar( l0, c0-1, l1, c1 )
        call s:MoveChar( l0, c0 - (l0 != l1), l1, c1+1 )
        let len = 2
    else
        call s:MoveChar( l0, c0, l1, c1 )
        let len = 1
    endif
    let line = getline( '.' )
    let c =  col( '.' ) - 1
    if closing && c+1 < len(line) && line[c+1] !~ b:any_wsclose_char
        " Insert a space after if needed
        execute "normal! a "
        normal! h
    endif
    let line = getline( '.' )
    let c =  col( '.' ) - 1
    if !closing && c > 0 && line[c-len] !~ b:any_wsopen_char
        " Insert a space before if needed
        if len > 1
            execute "normal! hi "
            normal! ll
        else
            execute "normal! i "
            normal! l
        endif
    endif
    call PareditReindentForm()
endfunction

" Move delimiter one atom or s-expression to the right
function! PareditMoveRight()
    call s:FindParenNearby()

    "TODO: move ')' in '() xxx' leaves space
    let line = getline( '.' )
    let l0 = line( '.' )
    let c0 =  col( '.' )

    if line[c0-1] =~ b:any_opening_char
        let opening = 1
    elseif line[c0-1] =~ b:any_closing_char
        let opening = 0
    else
        " Can move only delimiters
        return
    endif

    let [lp, cp] = s:GetReplPromptPos()
    let [l1, c1] = s:NextElement( opening )
    if [l1, c1] == [0, 0]
        " No next element found
        return
    elseif [lp, cp] != [0, 0] && l0 < lp && l1 >= lp
        " Do not go after the last command prompt in the REPL buffer
        return
    endif
    if opening && c0 > 1 && line[c0-2] =~ s:any_macro_prefix
        call s:MoveChar( l0, c0-1, l1, c1 )
        call s:MoveChar( l0, c0-1, l1, c1 + (l0 != l1) )
        let len = 2
    else
        call s:MoveChar( l0, c0, l1, c1 )
        let len = 1
    endif
    let line = getline( '.' )
    let c =  col( '.' ) - 1
    if opening && c > 0 && line[c-len] !~ b:any_wsopen_char
        " Insert a space before if needed
        if len > 1
            execute "normal! hi "
            normal! ll
        else
            execute "normal! i "
            normal! l
        endif
    endif
    let line = getline( '.' )
    let c =  col( '.' ) - 1
    if !opening && c+1 < len(line) && line[c+1] !~ b:any_wsclose_char
        " Insert a space after if needed
        execute "normal! a "
        normal! h
    endif
    call PareditReindentForm()
endfunction

" Find closing of the innermost structure: (...) or [...] or {...}
" Return a list where first element is the closing character,
" second and third is its position (line, column)
function! s:FindClosing()
    let l = line( '.' )
    let c = col( '.' )
    let paren = ''
    let l2 = 0
    let c2 = 0

    call PareditFindClosing( '(', ')', 0 )
    let lp = line( '.' )
    let cp = col( '.' )
    if [lp, cp] != [l, c]
        " Do we have a closing ')'?
        let paren = ')'
        let l2 = lp
        let c2 = cp
    endif
    call setpos( '.', [0, l, c, 0] )

    if &ft =~ s:fts_balancing_all_brackets
        call PareditFindClosing( '[', ']', 0 )
        let lp = line( '.' )
        let cp = col( '.' )
        if [lp, cp] != [l, c] && (lp < l2 || (lp == l2 && cp < c2))
            " Do we have a ']' closer?
            let paren = ']'
            let l2 = lp
            let c2 = cp
        endif
        call setpos( '.', [0, l, c, 0] )

        call PareditFindClosing( '{', '}', 0 )
        let lp = line( '.' )
        let cp = col( '.' )
        if [lp, cp] != [l, c] && (lp < l2 || (lp == l2 && cp < c2))
            " Do we have a '}' even closer?
            let paren = '}'
            let l2 = lp
            let c2 = cp
        endif
        call setpos( '.', [0, l, c, 0] )
    endif

    return [paren, l2, c2]
endfunction

" Split list or string at the cursor position
" Current symbol will be split into the second part
function! PareditSplit()
    if !g:paredit_mode || s:InsideComment()
        return
    endif

    if s:InsideString()
        normal! i" "
    else
        " Go back to the beginning of the current symbol
        let c = col('.') - 1
        if getline('.')[c] =~ '\S'
            if c == 0 || (c > 0 && getline('.')[c-1] =~ b:any_wsopen_char)
                " OK, we are standing on the first character of the symbol
            else
                normal! b
            endif
        endif

        " First find which kind of paren is the innermost
        let [p, l, c] = s:FindClosing()
        if p !~ b:any_closing_char
            " Not found any kind of parens
            return
        endif

        " Delete all whitespaces around cursor position
        while getline('.')[col('.')-1] =~ '\s'
            normal! x
        endwhile
        while col('.') > 1 && getline('.')[col('.')-2] =~ '\s'
            normal! X
        endwhile

        if p == ')'
            normal! i) (
        elseif p == '}'
            normal! i} {
        else
            normal! i] [
        endif
    endif
endfunction

" Join two neighboring lists or strings
function! PareditJoin()
    if !g:paredit_mode || s:InsideComment() || s:InsideString()
        return
    endif

    "TODO: skip parens in comments
    let [l0, c0] = searchpos(b:any_matched_char, 'nbW')
    let [l1, c1] = searchpos(b:any_matched_char, 'ncW')
    if [l0, c0] == [0, 0] || [l1, c1] == [0, 0]
        return
    endif
    let line0 = getline( l0 )
    let line1 = getline( l1 )
    let p0 = line0[c0-1]
    let p1 = line1[c1-1]
    if (p0 == ')' && p1 == '(') || (p0 == ']' && p1 == '[') || (p0 == '}' && p1 == '{') || (p0 == '"' && p1 == '"')
        if l0 == l1
            " First list ends on the same line where the second list begins
            let line0 = strpart( line0, 0, c0-1 ) . ' ' . strpart( line0, c1 )
            call setline( l0, line0 )
        else
            " First list ends on a line different from where the second list begins
            let line0 = strpart( line0, 0, c0-1 )
            let line1 = strpart( line1, 0, c1-1 ) . strpart( line1, c1 )
            call setline( l0, line0 )
            call setline( l1, line1 )
        endif
    endif
endfunction

" Wrap current visual block in parens of the given kind
function! s:WrapSelection( open, close )
    let l0 = line( "'<" )
    let l1 = line( "'>" )
    let c0 = col( "'<" )
    let c1 = col( "'>" )
    if &selection == 'inclusive'
        let c1 = c1 + strlen(matchstr(getline(l1)[c1-1 :], '.'))
    endif
    if [l0, c0] == [0, 0] || [l1, c1] == [0, 0]
        " No selection
        return
    endif
    if l0 > l1 || (l0 == l1 && c0 > c1)
        " Swap both ends of selection to make [l0, c0] < [l1, c1]
        let [ltmp, ctmp] = [l0, c0]
        let [l0, c0] = [l1, c1]
        let [l1, c1] = [ltmp, ctmp]
    endif
    let save_ve = &ve
    set ve=all
    call setpos( '.', [0, l0, c0, 0] )
    execute "normal! i" . a:open
    call setpos( '.', [0, l1, c1 + (l0 == l1), 0] )
    execute "normal! i" . a:close
    let &ve = save_ve
endfunction

" Wrap current visual block in parens of the given kind
" Keep visual mode
function! PareditWrapSelection( open, close )
    call s:WrapSelection( a:open, a:close )
    " Always leave the cursor to the opening char's pos after
    " wrapping selection.
    if getline('.')[col('.')-1] =~ b:any_closing_char
        normal! %
    endif
endfunction

" Wrap current symbol in parens of the given kind
" If standing on a paren then wrap the whole s-expression
" Stand on the opening paren (if not wrapping in "")
function! PareditWrap( open, close )
    let isk_save = s:SetKeyword()
    let sel_save = &selection
    let line = line('.')
    let column = col('.')
    let line_content = getline(line)
    let current_char = line_content[column - 1]

    if a:open != '"' && current_char =~ b:any_openclose_char
        execute "normal! " . "v%\<Esc>"
    else
        let inside_comment = s:InsideComment(line, column)

        if current_char == '"' && !inside_comment
            let escaped_quote = line_content[column - 2] == "\\"
            if escaped_quote
                execute "normal! " . "vh\<Esc>"
            else
                let is_starting_quote = 1
                if column == 1 && line > 1
                    let endOfPreviousLine = col([line - 1, '$'])
                    if s:InsideString(line - 1, endOfPreviousLine - 1)
                        let previous_line_content = getline(line - 1)
                        if previous_line_content[endOfPreviousLine - 2] != '"'
                            let is_starting_quote = 0
                        elseif previous_line_content[endOfPreviousLine - 3] == "\\"
                            let is_starting_quote = 0
                        endif
                    endif
                elseif s:InsideString(line, column - 1)
                    if line_content[column - 2] != '"'
                        let is_starting_quote = 0
                    elseif line_content[column - 3] == "\\"
                        let is_starting_quote = 0
                    endif
                endif
                let &selection="inclusive"
                normal! v
                if is_starting_quote
                    call search( '\\\@<!"', 'W', 's:SkipExpr()' )
                else
                    call search( '\\\@<!"', 'bW', 's:SkipExpr()' )
                endif
                execute "normal! " . "\<Esc>"
            endif
        else
            execute "normal! " . "viw\<Esc>"
        endif
    endif
    call s:WrapSelection( a:open, a:close )
    if a:open != '"'
        normal! %
    else
      call cursor(line, column + 1)
    endif
    let &selection = sel_save
    let &iskeyword = isk_save
endfunction

" Splice current list into the containing list
function! PareditSplice()
    if !g:paredit_mode
        return
    endif

    " First find which kind of paren is the innermost
    let [p, l, c] = s:FindClosing()
    if p !~ b:any_closing_char
        " Not found any kind of parens
        return
    endif

    call setpos( '.', [0, l, c, 0] )
    normal! %
    let l = line( '.' )
    let c = col( '.' )
    normal! %x
    call setpos( '.', [0, l, c, 0] )
    normal! x
    if c > 1 && getline('.')[c-2] =~ s:any_macro_prefix
        normal! X
    endif
endfunction

" Raise: replace containing form with the current symbol or sub-form
function! PareditRaise()
    let isk_save = s:SetKeyword()
    let ch = getline('.')[col('.')-1]
    if ch =~ b:any_openclose_char
        " Jump to the closing char in order to find the outer
        " closing char.
        if ch =~ b:any_opening_char
            normal! %
        endif

        let [p, l, c] = s:FindClosing()
        if p =~ b:any_closing_char
            " Raise sub-form and re-indent
            exe "normal! y%d%da" . p
            if getline('.')[col('.')-1] == ' '
              normal! "0p=%
            else
              normal! "0P=%
            endif
        elseif ch =~ b:any_opening_char
            " Restore position if there is no appropriate
            " closing char.
            normal! %
        endif
    else
        let [p, l, c] = s:FindClosing()
        if p =~ b:any_closing_char
            " Raise symbol
            exe "normal! yiwda" . p
            normal! "0Pb
        endif
    endif
    let &iskeyword = isk_save
endfunction

" =====================================================================
"  Autocommands
" =====================================================================

if !exists("g:paredit_disable_lisp")
    au FileType lisp      call PareditInitBuffer()
endif

if !exists("g:paredit_disable_clojure")
    au FileType *clojure* call PareditInitBuffer()
endif

if !exists("g:paredit_disable_hy")
    au FileType hy        call PareditInitBuffer()
endif

if !exists("g:paredit_disable_scheme")
    au FileType scheme    call PareditInitBuffer()
    au FileType racket    call PareditInitBuffer()
endif

if !exists("g:paredit_disable_shen")
    au FileType shen      call PareditInitBuffer()
endif

if !exists("g:paredit_disable_lfe")
    au FileType lfe       call PareditInitBuffer()
endif

if !exists("g:paredit_disable_fennel")
    au FileType fennel    call PareditInitBuffer()
endif
