#include <YourWorldOfText.au3>

; This script requires Autoit-WinHTTP.
; https://github.com/dragana-r/autoit-winhttp/releases

_YWOT_Open("testworld")

While 1
	$text = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & " " & @MIN & " " & @SEC & "          "
	_YWOT_PasteText($text & @CRLF & "Clock provided by brainiac", 4, 3)
	Sleep(1000)
WEnd

_YWOT_Close()