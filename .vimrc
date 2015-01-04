set tabstop=4
set expandtab
set hlsearch
set incsearch

set encoding=utf-8
set fileencodings=utf-8,iso-2022-jp,cp932,sjis,euc-jp


"===================================-
" plugin settings
"===================================-
"------------------------------------
" Ichange.vim
"------------------------------------
let g:Ichange#before_indent = 2
let g:Ichange#after_indent = 4
map <C-I> <Plug>(change_indent)


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


