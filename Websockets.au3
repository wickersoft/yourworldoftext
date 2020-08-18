#include <WinHTTP.au3>
#include <WinAPI.au3>

; This script requires Autoit-WinHTTP.
; https://github.com/dragana-r/autoit-winhttp/releases


Global Const $ERROR_NOT_ENOUGH_MEMORY = 8
Global Const $ERROR_INVALID_PARAMETER = 87

Global Const $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET = 114

Global Const $WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 0
Global Const $WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE = 1

Global Const $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS = 1000


Func _WebSocketOpen($sServerName, $iPort = 80, $sPath = "", $bWebSocketSecure = False)
	$WINHTTP_OPEN_REQUEST_FLAGS = 0x40
	If $bWebSocketSecure Then $WINHTTP_OPEN_REQUEST_FLAGS = BitOR($WINHTTP_OPEN_REQUEST_FLAGS, 0x800000)

	; Create session, connection and request handles.
	$hOpen = _WinHttpOpen("WebSocket sample", $WINHTTP_ACCESS_TYPE_DEFAULT_PROXY)
	If $hOpen = 0 Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("Open error" & @CRLF)
		Return False
	EndIf

	$hConnect = _WinHttpConnect($hOpen, $sServerName, $iPort)
	If $hConnect = 0 Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("Connect error" & @CRLF)
		Return False
	EndIf

	$hRequest = _WinHttpOpenRequest($hConnect, "GET", $sPath, Default, Default, Default, $WINHTTP_OPEN_REQUEST_FLAGS)
	If $hRequest = 0 Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("OpenRequest error" & @CRLF)
		Return False
	EndIf

	; Request protocol upgrade from http to websocket.

	Local $fStatus = _WinHttpSetOptionNoParams($hRequest, $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET)
	If Not $fStatus Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("SetOption error" & @CRLF)
		Return False
	EndIf

	; Perform websocket handshake by sending a request and receiving server's response.
	; Application may specify additional headers if needed.

	$fStatus = _WinHttpSendRequest($hRequest)
	If Not $fStatus Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("SendRequest error" & @CRLF)
		Return False
	EndIf

	$fStatus = _WinHttpReceiveResponse($hRequest)
	If Not $fStatus Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("SendRequest error" & @CRLF)
		Return False
	EndIf

	; Application should check what is the HTTP status code returned by the server and behave accordingly.
	; WinHttpWebSocketCompleteUpgrade will fail if the HTTP status code is different than 101.

	$hWebSocket = _WinHttpWebSocketCompleteUpgrade($hRequest, 0)
	If $hWebSocket = 0 Then
		$iError = _WinAPI_GetLastError()
		ConsoleWrite("WebSocketCompleteUpgrade error" & @CRLF)
		Return False
	EndIf

	_WinHttpCloseHandle($hRequest)
	$hRequestHandle = 0

	Return $hWebSocket
EndFunc   ;==>_WebSocketOpen

Func _WebSocketSend($hWebSocket, $bMessage, $iWebSocketBufferType = 0)
	; Send data on the websocket protocol.
	$iError = _WinHttpWebSocketSend($hWebSocket, _
			$iWebSocketBufferType, _
			$bMessage)
	If @error Or $iError <> 0 Then
		ConsoleWrite("WebSocketSend error" & @CRLF)
		Return False
	EndIf
EndFunc   ;==>_WebSocketSend

Func _WebSocketRecv($hWebSocket, $iBufferLen, $bWaitForData = False)
	Local $tBuffer = 0, $bRecv = Binary("")

	Local $iBytesRead = 0, $iBufferType = 0

	If $iBufferLen = 0 Then
		$iError = $ERROR_NOT_ENOUGH_MEMORY
		Return False
	EndIf

	Do
		$tBuffer = DllStructCreate("byte[" & $iBufferLen & "]")

		$iError = _WinHttpWebSocketReceive($hWebSocket, _
				$tBuffer, _
				$iBytesRead, _
				$iBufferType)
		If @error Or $iError <> 0 Then
			ConsoleWrite("WebSocketReceive error " & @error & " " & $iError & @CRLF)
			Return False
		EndIf

		; If we receive just part of the message restart the receive operation.

		$bRecv &= BinaryMid(DllStructGetData($tBuffer, 1), 1, $iBytesRead)
		$tBuffer = 0

		$iBufferLen -= $iBytesRead
	Until Not $bWaitForData Or $iBufferType <> $WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE Or $iBufferLen <= 0

	Return SetExtended($iBufferType, $bRecv)
EndFunc   ;==>_WebSocketRecv

Func _WebSocketCloseSocket($hWebSocket)
	; Gracefully close the connection.

	$iError = _WinHttpWebSocketClose($hWebSocket, _
			$WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS)
	If @error Or $iError <> 0 Then
		ConsoleWrite("WebSocketClose error" & @CRLF)
		Return False
	EndIf

	; Check close status returned by the server.

	Local $iStatus = 0, $iReasonLengthConsumed = 0
	Local $tCloseReasonBuffer = DllStructCreate("byte[1000]")

	$iError = _WinHttpWebSocketQueryCloseStatus($hWebSocket, _
			$iStatus, _
			$iReasonLengthConsumed, _
			$tCloseReasonBuffer)
	If @error Or $iError <> 0 Then
		ConsoleWrite("QueryCloseStatus error" & @CRLF)
		Return False
	EndIf

	ConsoleWrite("The server closed the connection with status code: '" & $iStatus & "' and reason: '" & _
			BinaryToString(BinaryMid(DllStructGetData($tCloseReasonBuffer, 1), 1, $iReasonLengthConsumed)) & "'" & @CRLF)

	Return True
EndFunc   ;==>_WebSocketCloseSocket

Func _WinHttpSetOptionNoParams($hInternet, $iOption)
	Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "bool", "WinHttpSetOption", _
			"handle", $hInternet, "dword", $iOption, "ptr", 0, "dword", 0)
	If @error Or Not $aCall[0] Then Return SetError(4, 0, 0)
	Return 1
EndFunc   ;==>_WinHttpSetOptionNoParams

Func _WinHttpWebSocketCompleteUpgrade($hRequest, $pContext = 0)
	Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketCompleteUpgrade", _
			"handle", $hRequest, _
			"DWORD_PTR", $pContext)
	If @error Then Return SetError(@error, @extended, -1)
	Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketCompleteUpgrade

Func _WinHttpWebSocketSend($hWebSocket, $iBufferType, $vData)
	Local $tBuffer = 0, $iBufferLen = 0
	If IsBinary($vData) = 0 Then $vData = StringToBinary($vData, 4)
	$iBufferLen = BinaryLen($vData)
	If $iBufferLen > 0 Then
		$tBuffer = DllStructCreate("byte[" & $iBufferLen & "]")
		DllStructSetData($tBuffer, 1, $vData)
	EndIf

	Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "DWORD", "WinHttpWebSocketSend", _
			"handle", $hWebSocket, _
			"int", $iBufferType, _
			"ptr", DllStructGetPtr($tBuffer), _
			"DWORD", $iBufferLen)
	If @error Then Return SetError(@error, @extended, -1)
	Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketSend

Func _WinHttpWebSocketReceive($hWebSocket, $tBuffer, ByRef $iBytesRead, ByRef $iBufferType)
	Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketReceive", _
			"handle", $hWebSocket, _
			"ptr", DllStructGetPtr($tBuffer), _
			"DWORD", DllStructGetSize($tBuffer), _
			"DWORD*", $iBytesRead, _
			"int*", $iBufferType)
	If @error Then Return SetError(@error, @extended, -1)
	$iBytesRead = $aCall[4]
	$iBufferType = $aCall[5]
	Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketReceive

Func _WinHttpWebSocketClose($hWebSocket, $iStatus, $tReason = 0)
	Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketClose", _
			"handle", $hWebSocket, _
			"USHORT", $iStatus, _
			"ptr", DllStructGetPtr($tReason), _
			"DWORD", DllStructGetSize($tReason))
	If @error Then Return SetError(@error, @extended, -1)
	Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketClose

Func _WinHttpWebSocketQueryCloseStatus($hWebSocket, ByRef $iStatus, ByRef $iReasonLengthConsumed, $tCloseReasonBuffer = 0)
	Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketQueryCloseStatus", _
			"handle", $hWebSocket, _
			"USHORT*", $iStatus, _
			"ptr", DllStructGetPtr($tCloseReasonBuffer), _
			"DWORD", DllStructGetSize($tCloseReasonBuffer), _
			"DWORD*", $iReasonLengthConsumed)
	If @error Then Return SetError(@error, @extended, -1)
	$iStatus = $aCall[2]
	$iReasonLengthConsumed = $aCall[5]
	Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketQueryCloseStatus

