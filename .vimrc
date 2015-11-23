set nocompatible
set tabstop=4
set expandtab
set hlsearch
set incsearch
set ambiwidth=double
highlight Comment ctermfg=darkcyan

set encoding=utf-8
set fileencodings=utf-8,iso-2022-jp,cp932,sjis,euc-jp
syntax on
"vmap // <C-V>0I//<Esc>

"===================================-
" plugin settings
"===================================-
"------------------------------------
" Ichange.vim
"------------------------------------
let g:Ichange#before_indent = 1
let g:Ichange#after_indent = 2
map <C-I> <Plug>(change_indent)
vmap <C-I> :Ichange<CR>

"command! -range=% -nargs=* Ghl call grephl#hl(expand("%"))

"""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" vim-monster
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
setlocal omnifunc=monster#omnifunc
imap <C-O> <C-X><C-O>
"let g:monster#debug#enable = 1
let g:monster#completion#rcodetools#show_info = 0

"------------------------------------
" unite.vim
" https://github.com/Shougo/unite.vim.git
" https://github.com/Shougo/vimproc.git
" https://github.com/Shougo/vimshell.git
"------------------------------------
let g:unite_enable_start_insert=0

" バッファ一覧
noremap <C-U><C-B> :Unite buffer<CR>
" ファイル一覧
noremap <C-U><C-F> :UniteWithBufferDir -buffer-name=files file<CR>
" 最近使ったファイルの一覧
noremap <C-U><C-R> :Unite file_mru<CR>
" レジスタ一覧
noremap <C-U><C-Y> :Unite -buffer-name=register register<CR>
" ファイルとバッファ
noremap <C-U><C-U> :Unite buffer file_mru<CR>
" 全部
noremap <C-U><C-A> :Unite UniteWithBufferDir -buffer-name=files buffer file_mru bookmark file<CR>
" ESCキーを2回押すと終了する
au FileType unite nnoremap <silent> <buffer> <ESC><ESC> :q<CR>
au FileType unite inoremap <silent> <buffer> <ESC><ESC> <ESC>:q<CR>

"------------------------------------
" vimfiler.vim
" https://github.com/Shougo/vimfiler.git
"------------------------------------
"noremap :e :VimFiler -split -simple -winwidth=35 -no-quit
noremap <C-E> :VimFiler -split -simple -winwidth=35 -no-quit<CR>
let g:vimfiler_safe_mode_by_default=0
let g:vimfiler_as_default_explorer=1


"------------------------------------
" yanktmp.vim
" http://www.vim.org/scripts/script.php?script_id=1598
"------------------------------------
map <silent> sy :call YanktmpYank()<CR>
map <silent> sp :call YanktmpPaste_p()<CR>
map <silent> sP :call YanktmpPaste_P()<CR> 


"------------------------------------
" qfixhowm.vim
" https://sites.google.com/site/fudist/Home/qfixhowm#downloads
"------------------------------------
set runtimepath+=~/.vim/bundle/qfixapp

let QFixHowm_Key = 'g'
let howm_dir             = '~/.howm'
let howm_filename        = '%Y/%m/%Y-%m-%d-%H%M%S.howm'
let howm_fileencoding    = 'utf-8'
let howm_fileformat      = 'unix'

let QFixHowm_DiaryFile = 'diary/%Y/%m/%Y-%m-%d-000000.howm'

"------------------------------------
" taglist.vim
" http://www.vim.org/scripts/script.php?script_id=273
"------------------------------------
":Tlist

"------------------------------------
" Gtags
"------------------------------------
map <C-]> :GtagsCursor<CR>
map <C-l> :Gtags -f %<CR>
map <C-n> :cn<CR>
nnoremap <C-t> <C-o><CR>
map <C-p> :cp<CR>
nnoremap <C-c> <C-w><C-w><C-w>q<CR>
map <C-k> :Gtags -r <C-r><C-w><CR>


""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NeoBundle
""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('vim_starting')
    set runtimepath+=~/.vim/bundle/neobundle.vim
    call neobundle#begin(expand('~/.vim/bundle'))
endif

NeoBundle 'Shougo/vimfiler'
NeoBundle 'Shougo/neomru.vim'
NeoBundle 'Shougo/unite.vim'
NeoBundle has('lua') ? 'Shougo/neocomplete' : 'Shougo/neocomplcache'

NeoBundleLazy 'marcus/rsense', {
      \ 'autoload': {
      \   'filetypes': 'ruby',
      \ },
      \ }

NeoBundle 'Shougo/vimproc', {
  \ 'build' : {
  \     'mac' : 'make -f make_mac.mak',
  \     'unix' : 'make -f make_unix.mak',
  \    },
  \ }
NeoBundleLazy 'supermomonga/neocomplete-rsense.vim', { 'autoload' : {
  \ 'insert' : 1,
  \ 'filetypes': 'ruby',
  \ }}

NeoBundleCheck
call neobundle#end()



"""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" rsense
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
"let g:rsenseUseOmniFunc = 1
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" neocomplete
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
"let g:neocomplete#enable_at_startup = 1
"let g:neocomplete#enable_ignore_case = 1
"let g:neocomplete#enable_smart_case = 1
"if !exists('g:neocomplete#keyword_patterns')
"    let g:neocomplete#keyword_patterns = {}
"endif
"let g:neocomplete#keyword_patterns._ = '\h\w*'
"inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
"inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"
"if !exists('g:neocomplete#force_omni_input_patterns')
"    let g:neocomplete#force_omni_input_patterns = {}
"endif
"let g:neocomplete#force_omni_input_patterns.ruby = '[^. *\t]\.\w*\|\h\w*::'

syntax on



