'
' FastBasic - Fast basic interpreter for the Atari 8-bit computers
' Copyright (C) 2017-2019 Daniel Serpell
'
' This program is free software; you can redistribute it and/or modify
' it under the terms of the GNU General Public License as published by
' the Free Software Foundation, either version 2 of the License, or
' (at your option) any later version.
'
' This program is distributed in the hope that it will be useful,
' but WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
' GNU General Public License for more details.
'
' You should have received a copy of the GNU General Public License along
' with this program.  If not, see <http://www.gnu.org/licenses/>
'
' In addition to the permissions in the GNU General Public License, the
' authors give you unlimited permission to link the compiled version of
' this file into combinations with other programs, and to distribute those
' combinations without any restriction coming from the use of this file.
' (The General Public License restrictions do apply in other respects; for
' example, they cover modification of the file, and distribution when not
' linked into a combine executable.)


' A text editor / IDE in FastBasic
' --------------------------------
'

'-------------------------------------
' Array definitions
dim ScrAdr(24)
' And an array with the current line being edited
''NOTE: Use page 6 ($600 to $6FF) to free memory instead of a dynamic array
'dim EditBuf(256) byte
EditBuf = $600

' We start with the help file.
FileName$ = "D:HELP.TXT"

' MemStart: the start of available memory, used as a buffer for the file data
dim MemStart(-1) byte
' MemEnd: the end of the current file, initialized to MemStart.
MemEnd = Adr(MemStart)

' NOTE: variables already are initialized to '0' in the runtime.
' line:
' column:       Logical cursor position (in the file)
' scrLine:
' scrColumn:    Cursor position in the screen
' hDraw:        Column at left of screen, and last "updated" column
' lDraw:        Number of the line last drawn, and being edited.
' linLen:       Current line length.
' edited:       0 if not currently editing a line
' ScrAdr():     Address in the file of screen line


'-------------------------------------
' Gets a filename with minimal line editing
'
PROC InputFilename
  ' Show current filename:
  pos. 6, 0: ? FileName$;
  do
    get key
    if key <= 27
      exit
    elif key = 155
      pos. 6, 0
      poke @CH, 12: ' Force ENTER
      input ; FileName$
      key = 0
      exit
    elif key >= 30 and key <= 124 or key = 126
      put key
    endif
  loop
  exec ShowInfo
ENDPROC

'-------------------------------------
' Compile (and run) file
PROC CompileFile
  ' Compile main file
  exec SaveLine
  poke MemEnd, $9B
  pos. 1,0
  ? "��Parsing: ";
  if USR( @compile_buffer, key, Adr(MemStart), MemEnd+1)
    ' Parse error, go to error line
    line = dpeek(@@linenum) - 1
    column = peek( @@bmax )
    scrLine = line
    if line > 10
      scrLine = 10
    endif
    get key
  elif key
    exec SaveCompiledFile
  else
    get key
    sound
    exec InitScreen
  endif
  exec RedrawScreen
ENDPROC

'-------------------------------------
' Deletes the character over the cursor
'
PROC DeleteChar
  fileChanged = 1
  edited = 1
  linLen = linLen - 1
  ptr = EditBuf + column
  move ptr+1, ptr, linLen - column
  exec ForceDrawCurrentLine
ENDPROC

'-------------------------------------
' Draws current line from edit buffer
' and move cursor to current position
'
PROC ForceDrawCurrentLine
  hDraw = -1
  exec DrawCurrentLine
ENDPROC

'-------------------------------------
' Draws current line from edit buffer
' and move cursor to current position
'
PROC DrawCurrentLine

  hColumn = 0
  scrColumn = column

  while scrColumn >= peek(@@RMARGN)
    hColumn = hColumn + 8
    scrColumn = column - hColumn + 1
  wend

  if hDraw <> hColumn

    hDraw = hColumn
    y = scrLine
    ptr = EditBuf
    lLen = linLen
    exec DrawLinePtr

  endif
  lDraw = scrLine

  pos. scrColumn, scrLine
  put 29
ENDPROC

'-------------------------------------
' Insert a character over the cursor
'
PROC InsertChar
  fileChanged = 1
  edited = 1
  ptr = EditBuf + column
  -move ptr, ptr+1, linLen - column
  poke ptr, key
  inc linLen
ENDPROC

'-------------------------------------
' Save line being edited
'
PROC SaveLine
  if edited
    ' Move file memory to make room for new line
    nptr = ScrAdr(lDraw) + linLen
    ptr = ScrAdr(lDraw+1) - 1
    newPtr = nptr - ptr

    if newPtr < 0
      move  ptr, nptr, MemEnd - ptr
    elif newPtr > 0
      -move ptr, nptr, MemEnd - ptr
    endif
    MemEnd = MemEnd + newPtr

    ' Copy new line
    ptr  = ScrAdr(lDraw)
    move EditBuf, ptr, linLen
    ' Adjust all pointers
    y = lDraw
    repeat
      inc y
      ScrAdr(y) = ScrAdr(y) + newPtr
    until y > 22
    ' End
    edited = 0
  endif
ENDPROC

'-------------------------------------
' Copy current line to edit buffer
'
PROC CopyToEdit
  ptr = ScrAdr(scrLine)
  linLen = ScrAdr(scrLine+1) - ptr - 1

  ' Get column in range
  if column > linLen
    column = linLen
    if linLen < 0
      column = 0
    endif
  endif

  ' Copy line to 'Edit' buffer, if not too long
  if linLen > 255
    linLen = 255
  endif
  if linLen > 0
    move ptr, EditBuf, linLen
  else
    poke EditBuf, $9b
  endif
ENDPROC

'-------------------------------------
' Save edited file
'
PROC AskSaveFile
  exec SaveLine
  pos. 0, 0
  ? "��Save?";
  exec InputFileName
  if key
    ' Don't save
    exit
  endif

  open #1, 8, 0, FileName$
  if err() < 128
    ' Open ok, write dile
    bput #1, Adr(MemStart), MemEnd - Adr(MemStart)
    if err() < 128
      ' Save ok, close
      close #1
      if err() < 128
        fileChanged = 0
        Exit
      endif
    endif
  endif

  exec FileError
ENDPROC

'-------------------------------------
' Shows file error
'
PROC FileError
  pos. 0,0
  ? "ERROR: "; err(); ", press any key�";
  close #1
  get key
  exec ShowInfo
ENDPROC

'-------------------------------------
' Prints line info and changes line
'
PROC ShowInfo
  ' Print two "-", then filename, then complete with '-' until right margin
  pos. 0, 0 : put $12 : put $12
  ? FileName$;
  repeat : put $12 : until peek(@@RMARGN) = peek(@@COLCRS)
  ' Fill last character
  poke @@OLDCHR, $52
  ' Go to cursor position
  pos. scrColumn, scrLine
  put 29
ENDPROC

'-------------------------------------
' Ask to save a file if it is changed
' from last save.
PROC AskSaveFileChanged
  key = 0
  while fileChanged
   exec AskSaveFile
   ' ESC means "don't save, cancel operation"
   if key = 27
     exit
   endif
   ' CONTROL-C means "don't save, lose changes"
   if key = 3
     key = 0
     exit
   endif
  wend
ENDPROC

'-------------------------------------
' Moves the cursor down 1 line
PROC CursorDown
  if scrLine = 22
    exec SaveLine
    exec ScrollUp
  else
    inc scrLine
  endif
  inc line
ENDPROC

'-------------------------------------
' Moves the cursor up 1 line
PROC CursorUp
  if scrLine
    dec scrLine
    dec line
  else
    exec SaveLine
    exec ScrollDown
  endif
ENDPROC

'-------------------------------------
' Scrolls screen Down (like page-up)
PROC ScrollDown
  ' Don't scroll if already at beginning of file
  if Adr(MemStart) = ScrAdr(0) then Exit

  ' Scroll screen image inserting a line
  poke @CRSINH, 1
  pos. 0, 1
  put 157
  ' Move screen pointers
  -move adr(ScrAdr), adr(ScrAdr)+2, 46
  ' Get first screen line by searching last '$9B'
  for ptr = ScrAdr(0) - 2 to Adr(MemStart) step -1
    if peek(ptr) = $9B then Exit
  next ptr
  inc ptr
  ScrAdr(0) = ptr

  ' Adjust line
  dec line

  ' Draw first line
  y = 0
  exec DrawLineOrig

ENDPROC

'-------------------------------------
' Draws line 'Y' from file buffer
'
PROC DrawLineOrig
  ptr = ScrAdr(y)
  lLen = ScrAdr(y+1) - ptr - 1
  hDraw = 0
  exec DrawLinePtr
ENDPROC

'-------------------------------------
' Draws line 'Y' scrolled by hDraw
' with data from ptr and lLen.
'
PROC DrawLinePtr

  poke @DSPFLG, 1
  poke @CRSINH, 1

  pos. 0, y+1
  ptr = ptr + hdraw
  max = peek(@@RMARGN) - 1
  if lLen < 0
    put $FD
    exec PutBlanks
    poke @@OLDCHR, $00
  else
    if hDraw
      lLen = lLen - hDraw
      put $9E
    else
      inc max
    endif

    if lLen > max
      bput #0, ptr, max
      poke @@OLDCHR, $DF
    else
      if lLen > 0
        bput #0, ptr, lLen
      endif
      max = max - lLen
      exec PutBlanks
      poke @@OLDCHR, $00
    endif
  endif

  poke @DSPFLG, 0
  poke @CRSINH, 0

ENDPROC

proc PutBlanks
  while max : put 32 : dec max : wend
endproc


'-------------------------------------
' Calls 'CountLines
PROC CountLines
' This code is too slow in FastBasic, so we use machine code
'  nptr = ptr
'  while nptr <> MemEnd
'    inc nptr
'    if peek(nptr-1) = $9b then exit
'  wend
  nptr = USR(@Count_Lines, ptr, MemEnd - ptr)
ENDPROC

'-------------------------------------
' Scrolls screen Up (like page-down)
PROC ScrollUp
  ' Don't scroll if already in last position
  if MemEnd = ScrAdr(1) then Exit

  ' Scroll screen image deleting the first line
  poke @CRSINH, 1
  pos. 0, 1
  put 156
  ' Move screen pointers
  move adr(ScrAdr)+2, adr(ScrAdr), 46

  ' Get last screen line length by searching next EOL
  ptr = ScrAdr(23)
  exec CountLines
  ScrAdr(23) = nptr

  ' Draw last line
  y = 22
  exec DrawLineOrig
ENDPROC

'-------------------------------------
' Load file into editor
'
PROC LoadFile

  open #1, 4, 0, FileName$
  if err() < 128
    bget #1, Adr(MemStart), fre()
    if err() = 136
      MemEnd = dpeek($358) + adr(MemStart)
      close #1
    endif
  endif

  if err() > 127
    exec FileError
  endif

  exec RedrawNewFile
ENDPROC

'-------------------------------------
' Redraw screen after new file
'
PROC RedrawNewFile
  fileChanged = 0
  column = 0
  line = 0
  scrLine = 0
  exec RedrawScreen
ENDPROC

'-------------------------------------
' Redraws entire screen
'
PROC RedrawScreen

  ' Top line is current minus screen line
  line = line - scrLine

  exec CheckEmptyBuf

  ' Search given line
  ptr = Adr(MemStart)
  for y=1 to line
   exec CountLines
   if nptr = MemEnd
     '  Line is outside of current file, go to last line
     line = y - 1
     exit
   endif
   ptr = nptr
  next y

  ' Draw all screen lines
  cls
  exec ShowInfo
  hdraw = 0
  y = 0
  ScrAdr(0) = ptr
  while y < 23
    exec CountLines
    lLen = nptr - ptr - 1
    exec DrawLinePtr
    ptr = nptr
    inc y
    ScrAdr(y) = ptr
  wend

  line = line + scrLine

  exec ChgLine
ENDPROC

'-------------------------------------
' Change current line.
'
PROC ChgLine

  exec SaveLine

  ' Restore last line, if needed
  if hDraw <> 0
    y = lDraw
    exec DrawLineOrig
  endif

  ' Keep new line in range
  while scrLine and ScrAdr(scrLine) = MemEnd
    line = line - 1
    scrLine = scrLine - 1
  wend

  exec CopyToEdit

  ' Print status
  pos. 32, 0 : ? line+1;
  put $12

  ' Redraw line
  hDraw = 0
  exec DrawCurrentLine

ENDPROC

'-------------------------------------
' Fix empty buffer
PROC CheckEmptyBuf
  if MemEnd = adr(MemStart)
    poke adr(MemStart), $9b
    MemEnd = MemEnd + 1
  endif
ENDPROC

'-------------------------------------
' Initializes E: device
PROC InitScreen
  close #0 : open #0, 12, 0, "E:"
  poke @@LMARGN, $00
  poke @KEYREP, 3
ENDPROC

'-------------------------------------
' Main Program
'

' Loads initial file, and change the filename
exec InitScreen
exec LoadFile
FileName$ ="D:"

escape = 0
do
  ' Key reading loop
  exec ProcessKeys
loop

'-------------------------------------
' Reads a key and process
PROC ProcessKeys
  get key
  ' Special characters:
  '   27 ESC            ok
  '   28 UP             ok
  '   29 DOWN           ok
  '   30 LEFT           ok
  '   31 RIGHT          ok
  '  125 CLR SCREEN (shift-<) or (ctrl-<)
  '  126 BS CHAR        ok
  '  127 TAB
  '  155 CR             ok
  '  156 DEL LINE (shift-bs)   ok
  '  157 INS LINE (shift->)
  '  158 CTRL-TAB
  '  159 SHIFT-TAB
  '  253 BELL (ctrl-2)
  '  254 DEL CHAR (ctrl-bs)    ok
  '  255 INS CHAR (ctrl->)

  '--------- Return Key - can't be escaped
  if key = $9B
    ' Ads an CR char and terminate current line editing.
    exec InsertChar
    exec SaveLine
    ' Redraw old line up to the new EOL
    hDraw = 0
    y = scrLine
    ptr = ScrAdr(scrLine)
    lLen = column
    exec DrawLinePtr
    ' Split current line at this point
    newPtr = ScrAdr(scrLine) + column + 1
    ' Go to column 0
    column = 0
    ' Scroll screen if we are in the last line
    if scrLine > 21
      exec ScrollUp
      dec scrLine
    endif
    ' Go to next line
    inc line
    inc scrLine
    ' Move screen down!
    poke @CRSINH, 1
    pos. 0, scrLine+1
    put 157
    ' Move screen pointers
    -move Adr(ScrAdr) + scrLine * 2, Adr(ScrAdr) + (scrLine+1) * 2, (23 - scrLine) * 2
    ' Save new line position
    ScrAdr(scrLine) = newPtr
    lDraw = scrLine
    hDraw = -1
    exec ChgLine
  elif (escape or ( ((key & 127) >= $20) and ((key & 127) < 125)) )
    ' Process normal keys
    escape = 0
    if linLen > 254
      put @@ATBEL : ' ERROR, line too long
    else
      exec InsertChar
      inc column
      if linLen = column and scrColumn < peek(@@RMARGN)-1
        inc scrColumn
        poke @DSPFLG, 1
        put key
        poke @DSPFLG, 0
      else
        exec ForceDrawCurrentLine
      endif
    endif
  else
    '--------------------------------
    ' Command keys handling
    '
    '
    '--------- Delete Line ----------
    if key = 156
      ' Mark file as changed
      fileChanged = 1
      ' Go to beginning of line
      column = 0
      ' Delete line from screen
      poke @CRSINH, 1
      pos. 0, scrLine+1
      put 156
      ' Delete from entire file!
      ptr = ScrAdr(scrLine)
      nptr = ScrAdr(scrLine+1)
      move nptr, ptr, MemEnd - nptr
      MemEnd = MemEnd - nptr + ptr
      exec CheckEmptyBuf
      ' Scroll screen if we are in the first line
      if scrLine = 0 and ptr = MemEnd
        exec ScrollDown
      endif
      nptr = ScrAdr(scrLine)
      for y = scrLine to 22
        ptr = nptr
        exec CountLines
        ScrAdr(y+1) = nptr
      next y
      y = scrLine
      exec DrawLineOrig
      edited = 0
      lDraw = 22
      hDraw = -1
      exec ChgLine
    '
    '--------- Backspace ------------
    elif key = 126
      if column > 0
        column = column - 1
        exec DeleteChar
      endif
    '
    '--------- Del Char -------------
    elif key = 254
      if column < linLen
        exec DeleteChar
      else
        ' Mark file as changed
        fileChanged = 1
        exec SaveLine
        ' Manually delete the EOL
        ptr = ScrAdr(scrLine+1)
        move ptr, ptr - 1, MemEnd - ptr
        MemEnd = MemEnd - 1
        ' Redraw
        exec RedrawScreen
      endif
    '
    '--------- Control-E (END) ------
    elif key = $05
      column = linLen
      exec DrawCurrentLine
    '
    '--------- Control-A (HOME) -----
    elif key = $01
      column = 0
      exec DrawCurrentLine
    '
    '--------- Left -----------------
    elif key = $1F
      if column < linLen
        inc column
        if scrColumn < peek(@@RMARGN)-1
          inc scrColumn
          put key
        else
          exec DrawCurrentLine
        endif
      endif
    '
    '--------- Right ----------------
    elif key = $1E
      if column > 0
        column = column - 1
        if scrColumn > 1
          scrColumn = scrColumn - 1
          put key
        else
          exec DrawCurrentLine
        endif
      endif
    '
    '--------- Control-U (page up)---
    elif key = $15
      ' To use less code, reuse "key" variable
      ' as loop counter, so instead of looping
      ' from 0 to 18, loops from key=$15 to $15+18=$27
      repeat
        exec CursorUp
        inc key
      until key>$27
      exec ChgLine
    '
    '--------- Control-V (page down)-
    elif key = $16
      ' To use less code, reuse "key" variable
      ' as loop counter, so instead of looping
      ' from 0 to 18, loops from key=$16 to $16+18=$28
      repeat
        exec CursorDown
        inc key
      until key>$28
      exec ChgLine
    '
    '--------- Down -----------------
    elif key = $1D
      exec CursorDown
      exec ChgLine
    '
    '--------- Up -------------------
    elif key = $1C
      exec CursorUp
      exec ChgLine
    '
    '--------- Control-Q (exit) -----
    elif key = $11
      exec AskSaveFileChanged
      if not key
        cls
        end
      endif
    '
    '--------- Control-S (save) -----
    elif key = $13
      exec AskSaveFile
    '
    '--------- Control-R (run) -----
    elif key = $12
      key = 0 ' key = 0 -> run
      exec CompileFile
    '
    '--------- Control-W (write compiled file) -----
    elif key = $17
      ' key <> 0 -> save
      exec CompileFile
    '
    '--------- Control-N (new) -----
    elif key = $0E
      exec AskSaveFileChanged
      if not key
        FileName$="D:"
        MemEnd = Adr(MemStart)
        exec RedrawNewFile
      endif
    '
    '--------- Control-L (load) -----
    elif key = $0C
      exec AskSaveFileChanged
      if not key
        pos. 0, 0
        ? "��Load?";
        exec InputFileName
        if not key
          exec LoadFile
        endif
      endif
    '
    '--------- Control-Z (undo) -----
    elif key = $1A
      if edited
        edited = 0
        exec CopyToEdit
        exec ForceDrawCurrentLine
      else
        put @@ATBEL
      endif
    '
    '--------- Escape ---------------
    elif key = $1B
      escape = 1
   'else
      ' Unknown Control Key
    endif
  endif
ENDPROC

'-------------------------------------
' Save compiled file
'
PROC SaveCompiledFile
  ' Save original filename
  move Adr(FileName$), EditBuf, 128
  poke Adr(FileName$) + Len(FileName$), $58

  pos. 0, 0
  ? "��Name?";
  exec InputFileName
  if key
    ' Don't save
    exit
  endif

  open #1, 8, 0, FileName$
  if err() < 128
    ' Open ok, write header
    bput #1, @COMP_HEAD_1, 6
    bput #1, @@__INTERP_START__, @@__INTERP_SIZE__
    bput #1, @COMP_HEAD_2, 4
    bput #1, @__JUMPTAB_RUN__, @COMP_RT_SIZE
    ' Note, the compiler writes to "NewPtr" the end of program code
    bput #1, MemEnd + 1, NewPtr - MemEnd
    if err() < 128
      bput #1, @COMP_TRAILER, 6
      ' Save ok, close
      close #1
    endif
  endif

  if err() > 127
    exec FileError
  endif

  ' Restore original filename
  move EditBuf, Adr(FileName$), 128
ENDPROC

' vi:syntax=tbxl
