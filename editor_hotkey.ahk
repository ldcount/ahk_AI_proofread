#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================
; BASIC FUNCTIONALITY
; ==============================

; Force CapsLock off at script start
SetCapsLockState "AlwaysOff"

; Remap CapsLock to change keyboard layout (Alt + Shift)
CapsLock::Send("{Alt Down}{Shift Down}{Shift Up}{Alt Up}")

; Optional: Define ending characters
::=Ю::=>
::=/::=>
::ЮЮ::>>

; ==============================
; AI TEXT PROOFREADING 
; ==============================
global EDIT_PROMPT :=
    "You has the role of my editor-in-chief: wise, inventive and agentic. You get a message either in English, French or Russian that I want you to correct. As my editor-in-chief I would like you to supervise and correct the following points in each message: 1) Verify and correct language and grammar errors. 2) Analyze sentence structure and introduce improvements for clarity and flow. 3) Identify any ambiguous or unclear language and introduce rephrasing. 4) Suggest alternative sentence constructions for greater variety and coherence. 5) Analyze the use of tenses or subjonctif (in French) and introduce improvements for consistency. In your answer you should use the same language as in my prompt, except if the original text is in Russian. If the original message is in Russian, your answer must be in French. If my prompt is in Russian, your answer must be in French. Your answer shall only be given text either in French or in English. Respond with the rephrased text only:"

; global GEMINI_MODEL := "gemini-2.0-flash"
global GEMINI_MODEL := "gemini-3-flash-preview"

^!x:: {
    originalClipboard := ClipboardAll()

    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1.5) {
        A_Clipboard := originalClipboard
        MsgBox "Не удалось получить выделенный текст. Сначала выделите текст и попробуйте снова.", "Ошибка", "Iconx"
        return
    }

    selectedText := A_Clipboard
    A_Clipboard := originalClipboard

    if Trim(selectedText) = "" {
        MsgBox "Выделенный текст пустой.", "Ошибка", "Iconx"
        return
    }

    apiKey := LoadApiKeyFromEnv(A_ScriptDir . "\\.env")
    if apiKey = "" {
        MsgBox "API-ключ не найден. Создайте файл .env рядом со скриптом и укажите GOOGLE_API_KEY=ваш_ключ", "Ошибка",
            "Iconx"
        return
    }

    editedText := ImproveTextWithGemini(selectedText, apiKey)
    if editedText = "" {
        MsgBox "Google API не вернул отредактированный текст.", "Ошибка API", "Iconx"
        return
    }

    SendText editedText
}

ImproveTextWithGemini(text, apiKey) {
    endpoint := "https://generativelanguage.googleapis.com/v1beta/models/" . GEMINI_MODEL . ":generateContent?key=" .
        UriEncode(apiKey)

    fullPrompt := EDIT_PROMPT . "`r`n`r`n---`r`nOriginal text:`r`n" . text

    payload := "{"
        . '"contents":[{"parts":[{"text":"' . JsonEscape(fullPrompt) . '"}]}],'
        . '"generationConfig":{"temperature":0.3}'
        . "}"

    http := ComObject("WinHttp.WinHttpRequest.5.1")

    try {
        http.Open("POST", endpoint, true) ; Async = true
        http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        http.Send(payload)

        ; Wait for response with tooltip
        while !http.WaitForResponse(0.05) {
            MouseGetPos &mouseX, &mouseY
            ToolTip "Proofreading in action...", mouseX + 15, mouseY + 15
        }
        ToolTip ; Remove tooltip

    } catch as err {
        ToolTip ; Ensure tooltip is removed on error
        MsgBox "Ошибка HTTP-запроса: " . err.Message, "Ошибка", "Iconx"
        return ""
    }

    if http.Status != 200 {
        MsgBox "Google API вернул код " . http.Status . "`n`n" . http.ResponseText, "Ошибка API", "Iconx"
        return ""
    }

    return ExtractGeminiText(http.ResponseText)
}

ExtractGeminiText(jsonText) {
    ; Ищем поле "text" в блоке candidates -> content -> parts
    startPos := InStr(jsonText, '"candidates"')
    if startPos = 0 {
        return ""
    }

    sub := SubStr(jsonText, startPos)

    ; Нестрогий, но практичный разбор: берём первое значение text
    if RegExMatch(sub, '"text"\s*:\s*"((?:\\.|[^"\\])*)"', &m) {
        return JsonUnescape(m[1])
    }

    return ""
}

LoadApiKeyFromEnv(pathToEnv) {
    if !FileExist(pathToEnv) {
        return ""
    }

    raw := FileRead(pathToEnv, "UTF-8")
    for line in StrSplit(raw, "`n", "`r") {
        clean := Trim(line)
        if clean = "" || SubStr(clean, 1, 1) = "#" {
            continue
        }

        if RegExMatch(clean, "i)^GOOGLE_API_KEY\s*=\s*(.*)$", &m) {
            value := Trim(m[1])
            ; Удаляем кавычки, если они есть
            if (SubStr(value, 1, 1) = '"' && SubStr(value, -1) = '"') || (SubStr(value, 1, 1) = "'" && SubStr(value, -1
            ) = "'") {
                value := SubStr(value, 2, StrLen(value) - 2)
            }
            return value
        }
    }

    return ""
}

JsonEscape(str) {
    str := StrReplace(str, "\\", "\\\\")
    str := StrReplace(str, '"', '\\"')
    str := StrReplace(str, "`r", "\\r")
    str := StrReplace(str, "`n", "\\n")
    str := StrReplace(str, "`t", "\\t")
    return str
}

JsonUnescape(str) {
    ; Handle escaped backslashes first to prevent collision with other escapes
    ; In JSON, literal backslash is \\
    ; We replace it with a placeholder that unlikely to appear (ASCII 1)
    str := StrReplace(str, "\\", Chr(1))

    ; Now handle standard escape sequences
    ; Note: In AHK, backslash is literal, so "\n" matches literal backslash followed by n
    str := StrReplace(str, "\n", "`n")
    str := StrReplace(str, "\r", "`r")
    str := StrReplace(str, "\t", "`t")
    str := StrReplace(str, '\"', '"')
    str := StrReplace(str, "\/", "/")
    str := StrReplace(str, "\b", "`b")
    str := StrReplace(str, "\f", "`f")

    ; Restore literal backslashes
    str := StrReplace(str, Chr(1), "\")

    return str
}

UriEncode(str) {
    static chars := "0123456789ABCDEF"
    out := ""
    loop parse, str {
        code := Ord(A_LoopField)
        if (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A) || code =
        0x2D || code = 0x5F || code = 0x2E || code = 0x7E {
            out .= A_LoopField
        } else {
            if code <= 0x7F {
                out .= "%" . SubStr(chars, (code >> 4) + 1, 1) . SubStr(chars, (code & 15) + 1, 1)
            } else {
                ; Для не-ASCII используем UTF-8 байты
                buf := Buffer(StrPut(A_LoopField, "UTF-8"), 0)
                StrPut(A_LoopField, buf, "UTF-8")
                loop buf.Size - 1 {
                    b := NumGet(buf, A_Index - 1, "UChar")
                    out .= "%" . SubStr(chars, (b >> 4) + 1, 1) . SubStr(chars, (b & 15) + 1, 1)
                }
            }
        }
    }
    return out
}
