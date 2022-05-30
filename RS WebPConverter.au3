#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=RS WebPConverter.ico
#AutoIt3Wrapper_Outfile=RS WebPConverter.exe
#AutoIt3Wrapper_Outfile_x64=RS WebPConverter64.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_Res_Comment=Convert WebP animated images to MP4.
#AutoIt3Wrapper_Res_Description=Convert WebP animated images to MP4
#AutoIt3Wrapper_Res_Fileversion=1.0.0.1
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_ProductName=RSWebPConverter
#AutoIt3Wrapper_Res_ProductVersion=1.0
#AutoIt3Wrapper_Res_CompanyName=Ruling Solutions
#AutoIt3Wrapper_Res_LegalCopyright=© 2021, Ruling Solutions
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <File.au3>
#include '..\AU3_Common\RS.au3'
#include '..\AU3_Common\RS_INI.au3'

Opt('MustDeclareVars', 1)

; Constants & variables
Local Const $Path = RS_fileNameValid(@ScriptDir, 2)
Local Const $EXE_anim_dump = $Path & 'anim_dump.exe'
Local Const $EXE_webpinfo = $Path & 'webpinfo.exe'
Local Const $EXE_webpmux = $Path & 'webpmux.exe'
Local Const $EXE_ffmpeg = $Path & 'ffmpeg.exe'
Local Const $TMPdir = RS_removeExt(_TempFile()) & '\'
Local Const $INI = RS_removeExt(@ScriptName) & '.ini'

Local $LNG
Local $iDurations
Local $iHeight
Local $iWidth
Local $sConcatFile
Local $sMP4file
Local $sWEBPfile

; Check language file
If FileExists($INI) Then
  $LNG = INI_valueLoad($INI, 'General', 'LNG', 'English')
Else
  $LNG = 'English'
  INI_valueWrite($INI, 'General', 'LNG', $LNG)
  INI_valueWrite($INI, 'General', 'CheckWebPinfoEXE', '0')
EndIf
$LNG = @ScriptDir & '\' & RS_fileNameInfo($LNG, 1) & '.lng'

If Not FileExists($LNG) Then
  INI_valueWrite($LNG, 'General', '001', 'WebP animated image')
  INI_valueWrite($LNG, 'General', '002', 'File exists')
  INI_valueWrite($LNG, 'General', '003', 'Video "%1" already exists.\nOverwrite?')
  INI_valueWrite($LNG, 'General', '004', 'Wait. Extracting %1 frames...')
  INI_valueWrite($LNG, 'General', '005', 'Wait. Creating video...')
  INI_valueWrite($LNG, 'General', '006', 'Done!')
  INI_valueWrite($LNG, 'Error', '001', 'Error')
  INI_valueWrite($LNG, 'Error', '002', 'Missing files, check instalation.')
  INI_valueWrite($LNG, 'Error', '003', 'Error creating file "%1".')
  INI_valueWrite($LNG, 'Error', '004', 'No chunks found in file "%1".')
  INI_valueWrite($LNG, 'Error', '005', 'No frames found in file "%1".')
  INI_valueWrite($LNG, 'Error', '006', 'Error creating concatenation file.')
  INI_valueWrite($LNG, 'Error', '007', 'Error extracting frames from file "%1".')
  INI_valueWrite($LNG, 'Error', '008', 'Error getting info from file "%1".')
  INI_valueWrite($LNG, 'Error', '009', 'Errors found in file "%1".')
EndIf

; Check executables
If Not FileExists($EXE_anim_dump) Or Not FileExists($EXE_webpmux) Or Not FileExists($EXE_ffmpeg) Then
  MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), INI_valueLoad($LNG, 'Error', '002', 'Missing files, check instalation.'), 3)
  Exit (1)
EndIf
If INI_valueLoad($INI, 'General', 'CheckWebPinfoEXE', '0') = '1' And Not FileExists($EXE_webpinfo) Then
  MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), INI_valueLoad($LNG, 'Error', '002', 'Missing files, check instalation.'), 3)
  Exit (1)
EndIf

; Get WebP filename
$sWEBPfile = RS_cmdLine()
If StringLen($sWEBPfile) = 0 Then
  Local $sDlg = INI_valueLoad($LNG, 'General', '001', 'WebP animated image') & ':'
  While 1
    $sWEBPfile = InputBox(RS_removeExt(@ScriptName), $sDlg, $sWEBPfile, '', 300, 130, @DesktopWidth - 320, @DesktopHeight - 180)
    If @error Then Exit(0)
    If FileExists($sWEBPfile) Then ExitLoop
  WEnd
EndIf

; Get frames data
$iDurations = _countFrames($sWEBPfile, $iWidth, $iHeight)
If Not IsArray($iDurations) Or $iWidth < 1 Or $iHeight < 1 Or $iDurations[0] = 0 Then Exit(1)
$sConcatFile = _createConcat($iDurations, $TMPdir)

; Create video filename and check if exists
$sMP4file = RS_removeExt($sWEBPfile) & '.mp4'
If FileExists($sMP4file) Then
  If MsgBox(36, INI_valueLoad($LNG, 'General', '002', 'File exists'), StringReplace(INI_valueLoad($LNG, 'General', '003', 'Video "%1" already exists.\nOverwrite?'), '%1', $sMP4file)) <> 6 Then Exit
EndIf

; Extract PNG images
If Not _webp2png($sWEBPfile, $TMPdir, StringReplace(INI_valueLoad($LNG, 'General', '004', 'Wait. Extracting %1 frames...'), '%1', $iDurations[0])) Then Exit(1)

; Create MP$ using ffmpeg and concatenation list
If Not _concatMP4($sMP4file, $sConcatFile, $iWidth, $iHeight, $TMPdir, INI_valueLoad($LNG, 'General', '005', 'Wait. Creating video...')) Then Exit(1)

; Delete temporal folders and files
MsgBox(0, RS_removeExt(@ScriptName), INI_valueLoad($LNG, 'General', '006', 'Done!'), 3)
DirRemove($TMPdir, 1)
FileDelete($sConcatFile)

; <=== _concatMP4 =================================================================================
; _concatMP4(String, String, Integer, Integer, [String], [String])
; ; Create MP4 video using ffmpeg using concatenate data.
; ;
; ; @param  String          Video file path.
; ; @param  String          Concatenation file.
; ; @param  Integer         Video width.
; ; @param  Integer         Video height.
; ; @param  [String]        Working directory. Default = ''.
; ; @param  [String]        Message to display in tooltip. Default = ''.
; ; @return Boolean         False if there was any error.
Func _concatMP4($pFile, $pConcat, $pWidth, $pHeight, $pFolder = '', $pMsg = '')
  If StringLen($pFile) = 0 Or StringLen($pConcat) = 0 Or $pWidth < 0 Or $pHeight < 0 Then Return False

  Local $sTmpFile = _TempFile('', '~', 'mp4')
  Local $sCommand = $EXE_ffmpeg & ' -safe 0 -f concat -i "' & $pConcat & '" -y -pix_fmt yuv420p -vf scale=' & $pWidth - Mod($pWidth, 2) & ':' & $pHeight - Mod($pHeight, 2) & ' "' & $sTmpFile & '"'
  RS_Run($sCommand, '', $pMsg)

  ; Copy temporal video to final dir and delete temporal file
  FileCopy($sTmpFile, $pFile, 1)
  If @error Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '003', 'Error creating file "%1".'), '%1', $pFile), 3)
    Return False
  EndIf
  FileDelete($sTmpFile)
  Return True
EndFunc

; <=== _countChunks ===============================================================================
; _countChunks(String, [String])
; ; Count VP8 chunks from info returned from WebP file. Must be same as frames got with webpmux.
; ;
; ; @param  String          WebP file path.
; ; @return [String]        Message to display in tooltip. Default = ''.
; ; @return Integer         VP8 chunks (frames) count.
Func _countChunks($pFile, $pMsg = '')
  Local $iChunks = 0
  Local $sLines = _webpinfo($pFile, $pMsg)
  For $sLine In $sLines
    If StringLeft($sLine, 10) = 'Chunk VP8 ' Then $iChunks += 1
  Next
  If $iChunks = 0 Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '004', 'No chunks found in file "%1".'), '%1', $pFile), 3)
  EndIf
  Return $iChunks
EndFunc

; <=== _countFrames ===============================================================================
; _countFrames(String, Integer, Integer, [String])
; ; Count frames from WebP file using webpmux.
; ;
; ; @param  String          WebP file path.
; ; @param  Integer         Variable to get width frame.
; ; @param  Integer         Variable to get height frame.
; ; @return [String]        Message to display in tooltip. Default = ''.
; ; @return Integer[]       Array with frames duration.
Func _countFrames($pFile, ByRef $pWidth, ByRef $pHeight, $pMsg = '')
  Local $iFrameDurations = ['']
  Local $iWidth = 0
  Local $sLines
  Local $sFrameData

  $sLines = RS_shell($EXE_webpmux, ' -info ' & RS_quote($pFile), '', $pMsg)
  If IsArray($sLines) Then
    For $sLine In $sLines
      If StringLeft($sLine, 13) = 'Canvas size: ' Then
        ; Get canvas sie
        $sLine = StringSplit(StringStripWS(StringTrimLeft($sLine, 13), 8), "x", 2)
        $pWidth = Number($sLine[0])
        $pHeight = Number($sLine[1])
      Else
        ; Get frames durations
        $sLine = RS_LTrim($sLine, ' ')
        If StringInStr('0123456789', StringLeft($sLine, 1)) Then
          $sFrameData = RS_Split($sLine)
          If IsArray($sFrameData) And $sFrameData[0] = 11 Then _ArrayAdd($iFrameDurations, $sFrameData[7])
        EndIf
      EndIf
    Next
    $iFrameDurations[0] = UBound($iFrameDurations) - 1
    If $iFrameDurations[0]< 1 Then
      MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '005', 'No frames found in file "%1".'), '%1', $pFile), 3)
    Endif
    Return $iFrameDurations
  Else
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '005', 'No frames found in file "%1".'), '%1', $pFile), 3)
    Return Null
  EndIf
EndFunc

; <=== _createConcat ==============================================================================
; _createConcat(String, [String])
; ; Create concatenation list file.
; ;
; ; @param  String          Video file path.
; ; @param  [String]        Working directory. Default = ''.
; ; @return String          Concatenation filename.
Func _createConcat($pDurations, $pFolder = '')
  If StringLen($pFolder) = 0 Then $pFolder = @TempDir
  $pFolder = RS_fileNameValid($pFolder, 2)

  ; Open concatenation file
  Local $iLen = StringLen($pDurations[0]) > 4 ? StringLen($pDurations[0]) : 4
  Local $sConcatenationFile = _TempFile($pFolder)
  Local $hFileOpen = FileOpen($sConcatenationFile, 2)
  If $hFileOpen = -1 Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), INI_valueLoad($LNG, 'Error', '006', 'Error creating concatenation file.'), 3)
    MsgBox(16, 'Error', "Error creating concatenation file.")
    Return ''
  EndIf

  ; Write concatenation data
  For $i = 1 To $pDurations[0]
    FileWrite($hFileOpen, "file '" & $pFolder & 'frame_' & RS_padLeft($i - 1, $iLen, '0') & ".png'" & @CRLF)
    FileWrite($hFileOpen, 'duration ' & Number($pDurations[$i]) / 1000 & @CRLF)
  Next

  FileClose($hFileOpen)
  Return $sConcatenationFile
EndFunc

; <=== _createMP4 =================================================================================
; _createMP4(String, [String], [String])
; ; Create MP4 video using ffmpeg.
; ;
; ; @param  String          Video file path.
; ; @param  [String]        Working directory. Default = ''.
; ; @param  [String]        Message to display in tooltip. Default = ''.
; ; @return Boolean         False if there was any error.
Func _createMP4($pFile, $pFolder = '', $pMsg = '')
  If StringLen($pFile) = 0 Or StringLen($pFolder) = 0 Then Return False

  Local $sTmpFile = _TempFile('', '~', 'mp4')
  RS_Run($EXE_ffmpeg & ' -r 15 -i ' & $pFolder & '\frame_%04d.png -c:v libx264 -vf fps=15 -pix_fmt yuv420p -crf 15 ' & $sTmpFile, '', $pMsg)

  ; Copy temporal video to final dir and delete temporal file
  FileCopy($sTmpFile, $pFile, 1)
  If @error Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '003', 'Error creating file "%1".'), '%1', $pFile), 3)
    Return False
  Else
    Return True
  EndIf
  FileDelete($sTmpFile)
EndFunc

; <=== _webp2png ==================================================================================
; _webp2png(String, String, [String])
; ; Extract PNG images to folder using anim_dump.
; ;
; ; @param  String          WebP file path.
; ; @return String          Working directory.
; ; @return [String]        Message to display in tooltip. Default = ''.
; ; @return Boolean         False if there was any error.
Func _webp2png($pFile, $pFolder, $pMsg = '')
  If Not FileExists($pFolder) Then DirCreate($pFolder)
  RS_run($EXE_anim_dump & ' -folder ' & $pFolder & ' -prefix frame_ ' & $pFile, $pFolder, $pMsg)
  Local $sFileList = _FileListToArray($pFolder, '*.png', 1)
  If @error Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '007', 'Error extracting frames from file "%1".'), '%1', $pFile), 3)
    Return False
  Else
    Return True
  EndIf
EndFunc

; <=== _webpinfo ==================================================================================
; _webpinfo(String, [String])
; ; Check WebP info using webpinfo.
; ;
; ; @param  String          WebP file path.
; ; @return [String]        Message to display in tooltip. Default = ''.
; ; @return String[]        Array with standard output.
Func _webpinfo($pFile, $pMsg = '')
  Local $sLines = RS_Shell($EXE_webpinfo, $pFile, '', $pMsg)
  Local $iCount = UBound($sLines)
  If $iCount = 0 Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '008', 'Error getting info from file "%1".'), '%1', $pFile), 3)
    Return Null
  ElseIf $sLines[$iCount - 1] <> 'No error detected.' Then
    MsgBox(16, INI_valueLoad($LNG, 'Error', '001', 'Error'), StringReplace(INI_valueLoad($LNG, 'Error', '009', 'Errors found in file "%1".'), '%1', $pFile), 3)
    Return Null
  Else
    Return $sLines
  EndIf
EndFunc
