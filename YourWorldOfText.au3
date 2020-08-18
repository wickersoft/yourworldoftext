#include <Websockets.au3>

; This script requires Autoit-WinHTTP.
; https://github.com/dragana-r/autoit-winhttp/releases


Global Const $YWOT_WRITE_CACHE_AUTOFLUSH_SIZE_BYTES = 2000
Global $YWOT_WEBSOCKET = 0
Global $YWOT_WRITE_BUFFER = ""

Func _YWOT_Open($world)
    $YWOT_WEBSOCKET = _WebSocketOpen("www.yourworldoftext.com", 443, $world & "/ws/", True)
EndFunc

Func _YWOT_PutChar($tileX, $tileY, $charX, $charY, $char)
	$YWOT_WRITE_BUFFER &= '[' & $tileY & ',' & $tileX & ',' & $charY & ',' & $charX & ',0,"' & $char & '",0],'
	If StringLen($YWOT_WRITE_BUFFER) >= $YWOT_WRITE_CACHE_AUTOFLUSH_SIZE_BYTES Then
		_YWOT_Flush()
	EndIf
EndFunc

Func _YWOT_Flush()
	If $YWOT_WRITE_BUFFER = "" Then Return
	_WebSocketSend($YWOT_WEBSOCKET, '{"edits":[' & StringTrimRight($YWOT_WRITE_BUFFER, 1) & '],"kind":"write"}', 2)
	$YWOT_WRITE_BUFFER = ""
EndFunc

Func _YWOT_Close()
	_WebSocketCloseSocket($YWOT_WEBSOCKET)
EndFunc

Func _YWOT_PasteText($text, $x_tile, $y_tile, $x_char = 0, $y_char = 0)
	$ymin = $y_tile * 8
	$xmin = $x_tile * 16
	$ymin += $y_char ; More calculating coordinates.
	$xmin += $x_char
	$x = $xmin
	$y = $ymin
	$string_index = 0
	$string_length = StringLen($text)
	While 1
		$string_index += 1
		$a = StringMid($text, $string_index, 1) ; Extracting the next character from the String
		If $a = @LF Then
			$x = $xmin ; Reset the x-coordinate where the text file has a line feed
			$y += 1
		ElseIf $a = @CR Then ; A line feed consists of two characters. One of them gets skipped here.
		Else
			$xtile = Floor($x / 16)
			$ytile = Floor($y / 8)
			$xchar = $x - 16 * $xtile ; Calculating the coordinates for this character
			$ychar = $y - 8 * $ytile
			_YWOT_PutChar($xtile, $ytile, $xchar, $ychar, convert($a))
			$x += 1
		EndIf
		If $string_index = $string_length Then ExitLoop ; This happens when the function has reached the end of the String.
	WEnd
	_YWOT_Flush()
EndFunc   ;==>paste_text

Func convert($UnicodeURL) ; This converts unicode text into HTTP-friendly text (escapes characters)
	If StringInStr("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 ", $UnicodeURL) Then Return $UnicodeURL
	Return "\u" & Hex(AscW($UnicodeURL), 4)
EndFunc   ;==>convert