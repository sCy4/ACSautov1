#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib_Shared.ahk
#Include %A_ScriptDir%\UIA.ahk

; 將原本長長檔名的設定檔，改為隱藏快取檔
global CONFIG_FILE := A_ScriptDir "\.assignees_cache.txt"
global DEFAULT_ASSIGNEES := "萍, 富, 蓁, 姿, 珊, 彥"
global GAS_URL := "https://script.google.com/macros/s/AKfycbw2D6js48bcpApc6VhBfksd-98TCjvXZTccShoFBegp2P03Wh4tw3E3ufNQLKg4EXqX/exec"
global SHEET_TAB_NAME := "清關報告"
global MSG := {
    ErrNoSelect: "■ 錯誤：你沒有選取單號",
    ErrNoPage: "■ 錯誤：找不到物流管理系統頁面",
    ErrNoSearch: "■ 錯誤：找不到搜尋欄位也找不到返回按鈕",
    ErrCloudWrite: "■ 錯誤：雲端找不到寫入範圍",
    ErrCloudConn: "■ 錯誤：連線雲端失敗",
    ErrScript: "■ 錯誤：腳本中斷",
    
    OsdRunning: "▶️ 腳本運行中 [進度 {1} / {2}] - 滑鼠已鎖定，防誤觸`n(按 Esc 暫停) (按 F8 關閉腳本)",
    OsdWriting: "⏳ 正在修改表單資料，請稍等...`n(你可以正常操作電腦)",
    
    InputTitle: "這次分配給誰？",
    InputBody: "請填寫參與分配的人員`n`n(中間用空格或逗號隔開) (留空則只標記 Y/N)",
    
    ReportTitle: "📑 統計報告",
    ReportBody: "完成了`n`n總計：{1}`n`n已按申報相符：{2}`n已上傳個案委任書：{3}`n其他：{4}`n`n本次有 {5} 筆狀態更改"
}

; --- 建立選單函數 (已移除 emoji) ---
BuildCustomsMenu(TargetMenu) {
    TargetMenu.Add("◎ 清關名單動作自動化", (*) => "")
    TargetMenu.Disable("◎ 清關名單動作自動化")
    TargetMenu.Add(" 查詢單筆", Action_EZWCheck)
    TargetMenu.Add(" 更新申報狀態", Action_EZWRenew)
    TargetMenu.Add(" 分配人員與標記Y/N", Action_EZWAllot)
}

; --- 導航輔助函式 ---
NavigateToSearch(ChromeEl) {
    if ChromeEl.ElementExist({AutomationId: "traceCode", Type: "Edit"})
        return true

    backLink := ChromeEl.ElementExist({Name: "返回上一頁", Type: "Link", MatchMode: "Substring"})
    if backLink {
        backLink.Click(), Sleep(200)
        ChromeEl.WaitElement({AutomationId: "traceCode", Type: "Edit"}, 5000)
        return true
    }

    navLink := ChromeEl.ElementExist({Value: "javascript:addTabs('%E8%A8%82%E5%96%AE%E6%9F%A5%E8%A9%A2','doc.order');"})
    if !navLink {
        dropdown := ChromeEl.ElementExist({Type: "Link", ClassName: "has-ul"})
        if dropdown {
            dropdown.Click(), Sleep(200)
            navLink := ChromeEl.ElementExist({Value: "javascript:addTabs('%E8%A8%82%E5%96%AE%E6%9F%A5%E8%A9%A2','doc.order');"})
        }
    }

    if navLink {
        navLink.Click(), Sleep(200)
        if ChromeEl.ElementExist({AutomationId: "traceCode", Type: "Edit"})
            return true

        backLink2 := ChromeEl.ElementExist({Name: "返回上一頁", Type: "Link", MatchMode: "Substring"})
        if backLink2 {
            backLink2.Click(), Sleep(200)
        }

        ChromeEl.WaitElement({AutomationId: "traceCode", Type: "Edit"}, 8000)
        return true
    }
    return false
}

; --- 動作函式 ---
Action_EZWCheck(*) {
    if !GetSelectedText(&cleanClip)
        return
    
    global isRunning := true
    global isMouseLocked := true 
    SetSystemCursor("Wait")
    
    try {
        chromeList := WinGetList("ahk_exe chrome.exe")
        foundTab := false
        for chromeHwnd in chromeList {
            try {
                ChromeEl := UIA.ElementFromHandle(chromeHwnd)
                targetTab := ChromeEl.ElementExist({Name: "物流管理系統", Type: "TabItem", MatchMode: "Substring"})
                if targetTab {
                    WinActivate(chromeHwnd), WinWaitActive(chromeHwnd)
                    targetTab.Click(), Sleep(100)
                    foundTab := true
                    break
                }
            }
        }

        if !foundTab {
            EndProcess(), MsgBox(MSG.ErrNoPage)
            return
        }

        if !NavigateToSearch(ChromeEl) {
            EndProcess(), MsgBox(MSG.ErrNoSearch)
            return
        }

        traceField := ChromeEl.WaitElement({AutomationId: "traceCode", Type: "Edit"}, 5000)
        traceField.Value := cleanClip
        Sleep 50

        ChromeEl.WaitElement({Name: "查詢", Type: "Button"}, 5000).Click()
        Sleep 300

        numLinkPattern := "^(\d+-\d|" . cleanClip . ")$"
        ChromeEl.WaitElement({Name: numLinkPattern, Type: "Link", MatchMode: "RegEx", Index: 1}, 10000).Click()
        Sleep 50

        ChromeEl.WaitElement({Name: "EZWAY", Type: "TabItem"}, 10000).Click()
        
        EndProcess() 

    } catch as err {
        EndProcess(), MsgBox(MSG.ErrScript err.Message)
    }
}

Action_EZWRenew(*) {    
    if !GetSelectedText(&cleanClip)
        return

    global isRunning := true
    global isMouseLocked := true 
    SetSystemCursor("Wait")
    trackings := StrSplit(cleanClip, "`n", "`r")
    matchCount := 0, validCount := 0, noMatchCount := 0, dataList := [] 
    
    try {
        chromeList := WinGetList("ahk_exe chrome.exe")
        foundTab := false
        for chromeHwnd in chromeList {
            try {
                ChromeEl := UIA.ElementFromHandle(chromeHwnd)
                targetTab := ChromeEl.ElementExist({Name: "物流管理系統", Type: "TabItem", MatchMode: "Substring"})
                if targetTab {
                    WinActivate(chromeHwnd), WinWaitActive(chromeHwnd)
                    targetTab.Click(), Sleep(200)
                    foundTab := true
                    break
                }
            }
        }
        
        if !foundTab {
            EndProcess(), MsgBox(MSG.ErrNoPage)
            return
        }

        for index, rawTrackCode in trackings {
            trackCode := RegExReplace(rawTrackCode, "[^\w\-]", "")
            if (StrLen(trackCode) < 4) {
                noMatchCount++
                continue
            }
            
            try {
                ShowOSD(Format(MSG.OsdRunning, index, trackings.Length))
                
                if !NavigateToSearch(ChromeEl)
                    throw Error("NavFail")

                ChromeEl.WaitElement({AutomationId: "traceCode", Type: "Edit"}, 5000).Value := trackCode
                Sleep 50
                ChromeEl.WaitElement({Name: "查詢", Type: "Button"}, 5000).Click()
                Sleep 300
                numLinkPattern := "^(\d+-\d|" . trackCode . ")$"
                ChromeEl.WaitElement({Name: numLinkPattern, Type: "Link", MatchMode: "RegEx", Index: 1}, 10000).Click()
                Sleep 50
                ChromeEl.WaitElement({Name: "EZWAY", Type: "TabItem"}, 10000).Click()
                Sleep 50
                ChromeEl.WaitElement({Name: "實名認證比對結果", MatchMode: "Substring"}, 10000)

                thisMatch := "無"
                if ChromeEl.ElementExist({Name: "資料相符", MatchMode: "Substring"}) {
                    matchCount++, thisMatch := "資料相符"
                } else if ChromeEl.ElementExist({Name: "有效", MatchMode: "Substring"}) {
                    validCount++, thisMatch := "有效"
                } else {
                    noMatchCount++
                }
                dataList.Push({code: trackCode, match: thisMatch})
            } catch {
                noMatchCount++
                dataList.Push({code: trackCode, match: "失敗"})
            }
        }

        ShowOSD(MSG.OsdWriting)
        RestoreCursor()
        global isMouseLocked := false 
        JumpToSheet()

        if (dataList.Length > 0) {
            jsonBody := '{"data": ['
            for i, item in dataList
                jsonBody .= '{"code":"' item.code '","match":"' item.match '"},'
            jsonBody := RTrim(jsonBody, ",") . ']}'
            
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.SetTimeouts(0, 60000, 30000, 300000)
            whr.Open("POST", GAS_URL, true)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.Send(jsonBody)
            
            while (whr.WaitForResponse(0.05) == 0) {
                Sleep 50 
            }
            
            if (whr.Status == 200) {
                if RegExMatch(whr.ResponseText, '"status"\s*:\s*"error"') {
                    EndProcess(), MsgBox(MSG.ErrCloudWrite)
                    return
                }

                actualNew := 0
                if RegExMatch(whr.ResponseText, '"newChanges"\s*:\s*(\d+)', &match)
                    actualNew := match[1]

                EndProcess()
                totalCount := matchCount + validCount + noMatchCount
                reportMsg := Format(MSG.ReportBody, totalCount, matchCount, validCount, noMatchCount, actualNew)
                MsgBox(reportMsg, MSG.ReportTitle)
            } else {
                EndProcess(), MsgBox(MSG.ErrCloudConn whr.Status)
            }
        } else {
             EndProcess()
        }
    } catch as err {
        EndProcess(), MsgBox(MSG.ErrScript err.Message)
    }
}

Action_EZWAllot(*) {
    rawAssigneeText := ""
    
    ; 讀取上次存檔的名單，若無則使用預設名單
    if !FileExist(CONFIG_FILE) {
        rawAssigneeText := DEFAULT_ASSIGNEES
    } else {
        rawAssigneeText := FileRead(CONFIG_FILE, "UTF-8")
    }

    cleanedFileText := RegExReplace(rawAssigneeText, "[,\r\n，、\s]+", ", ")
    cleanedFileText := Trim(cleanedFileText, " ,")
    
    ib := InputBox(MSG.InputBody, MSG.InputTitle, "w400 h160", cleanedFileText)
    
    if (ib.Result = "Cancel" || ib.Result = "Timeout")
        return 
        
    ; 【新增功能】：將這次輸入的名單存起來，並標記為隱藏檔案
    try {
        if FileExist(CONFIG_FILE)
            FileDelete(CONFIG_FILE)
        FileAppend(ib.Value, CONFIG_FILE, "UTF-8")
        FileSetAttrib("+H", CONFIG_FILE) 
    } catch {
        ; 忽略寫入權限錯誤，不影響後續執行
    }
    
    cleanedInput := RegExReplace(ib.Value, "[，、\s]+", ",")
    tempArray := StrSplit(cleanedInput, ",")
    
    global ASSIGNEES := []
    for name in tempArray {
        if (Trim(name) != "")
            ASSIGNEES.Push(Trim(name))
    }

    if !GetSelectedText(&cleanClip)
        return

    global isRunning := true
    global isMouseLocked := true 
    SetSystemCursor("Wait")
    trackings := StrSplit(cleanClip, "`n", "`r")
    matchCount := 0, validCount := 0, noMatchCount := 0, dataList := [], validQueryIndex := 0
    
    try {
        chromeList := WinGetList("ahk_exe chrome.exe")
        foundTab := false
        for chromeHwnd in chromeList {
            try {
                ChromeEl := UIA.ElementFromHandle(chromeHwnd)
                targetTab := ChromeEl.ElementExist({Name: "物流管理系統", Type: "TabItem", MatchMode: "Substring"})
                if targetTab {
                    WinActivate(chromeHwnd), WinWaitActive(chromeHwnd)
                    targetTab.Click(), Sleep(200)
                    foundTab := true
                    break
                }
            }
        }
        
        if !foundTab {
            EndProcess(), MsgBox(MSG.ErrNoPage)
            return
        }

        for index, rawTrackCode in trackings {
            trackCode := RegExReplace(rawTrackCode, "[^\w\-]", "")
            if (StrLen(trackCode) < 4) {
                noMatchCount++
                continue
            }
            
            try {
                ShowOSD(Format(MSG.OsdRunning, index, trackings.Length))
                
                if !NavigateToSearch(ChromeEl)
                    throw Error("NavFail")

                ChromeEl.WaitElement({AutomationId: "traceCode", Type: "Edit"}, 5000).Value := trackCode
                Sleep 50
                ChromeEl.WaitElement({Name: "查詢", Type: "Button"}, 5000).Click()
                Sleep 300
                numLinkPattern := "^(\d+-\d|" . trackCode . ")$"
                ChromeEl.WaitElement({Name: numLinkPattern, Type: "Link", MatchMode: "RegEx", Index: 1}, 10000).Click()
                Sleep 50
                ChromeEl.WaitElement({Name: "EZWAY", Type: "TabItem"}, 10000).Click()
                Sleep 50
                ChromeEl.WaitElement({Name: "實名認證比對結果", MatchMode: "Substring"}, 10000)

                thisMatch := "無"
                if ChromeEl.ElementExist({Name: "資料相符", MatchMode: "Substring"}) {
                    matchCount++, thisMatch := "資料相符"
                } else if ChromeEl.ElementExist({Name: "有效", MatchMode: "Substring"}) {
                    validCount++, thisMatch := "有效"
                } else {
                    noMatchCount++
                }

                ynStatus := ""
                if ChromeEl.ElementExist({Name: "Y", Type: "DataItem", ClassName: "text-success"}) {
                    ynStatus := "Y"
                } else if ChromeEl.ElementExist({Name: "N", Type: "DataItem", ClassName: "text-danger"}) {
                    ynStatus := "N"
                }
                
                assigneeName := ""
                if (thisMatch != "資料相符" && thisMatch != "有效" && ASSIGNEES.Length > 0) {
                    validQueryIndex++
                    assigneeName := ASSIGNEES[Mod(validQueryIndex - 1, ASSIGNEES.Length) + 1]
                }
                dataList.Push({code: trackCode, match: thisMatch, yn: ynStatus, assignee: assigneeName})
                
            } catch {
                noMatchCount++
                assigneeName := ""
                if (ASSIGNEES.Length > 0) {
                    validQueryIndex++
                    assigneeName := ASSIGNEES[Mod(validQueryIndex - 1, ASSIGNEES.Length) + 1]
                }
                dataList.Push({code: trackCode, match: "失敗", yn: "", assignee: assigneeName})
            }
        }

        ShowOSD(MSG.OsdWriting)
        RestoreCursor()
        global isMouseLocked := false 
        JumpToSheet()

        if (dataList.Length > 0) {
            jsonBody := '{"data": ['
            for i, item in dataList
                jsonBody .= '{"code":"' item.code '","match":"' item.match '","yn":"' item.yn '","assignee":"' item.assignee '"},'
            jsonBody := RTrim(jsonBody, ",") . ']}'
            
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.SetTimeouts(0, 60000, 30000, 300000)
            whr.Open("POST", GAS_URL, true)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.Send(jsonBody)
            
            while (whr.WaitForResponse(0.05) == 0) {
                Sleep 50 
            }
            
            if (whr.Status == 200) {
                if RegExMatch(whr.ResponseText, '"status"\s*:\s*"error"') {
                    EndProcess(), MsgBox(MSG.ErrCloudWrite)
                    return
                }
                actualNew := 0
                if RegExMatch(whr.ResponseText, '"newChanges"\s*:\s*(\d+)', &match)
                    actualNew := match[1]

                EndProcess()
                totalCount := matchCount + validCount + noMatchCount
                reportMsg := Format(MSG.ReportBody, totalCount, matchCount, validCount, noMatchCount, actualNew)
                MsgBox(reportMsg, MSG.ReportTitle)
            }
        } else {
            EndProcess()
        }
    } catch as err {
        EndProcess(), MsgBox(MSG.ErrScript err.Message)
    }
}

; --- 剪貼簿與視窗輔助函式 ---
GetSelectedText(&cleanText) {
    hWnd := WinActive("A")
    if hWnd
        PostMessage(0x50, 0, 0x04090409, , "ahk_id " hWnd)
    
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1) {
        MsgBox(MSG.ErrNoSelect)
        return false
    }
    cleanText := Trim(A_Clipboard, " `t`r`n")
    return true
}

JumpToSheet() {
    chromeList := WinGetList("ahk_exe chrome.exe")
    for chromeHwnd in chromeList {
        try {
            el := UIA.ElementFromHandle(chromeHwnd)
            tab := el.ElementExist({Name: SHEET_TAB_NAME, Type: "TabItem", MatchMode: "Substring"})
            if tab {
                WinActivate(chromeHwnd), WinWaitActive(chromeHwnd)
                tab.Click(), Sleep(200)
                return true
            }
        }
    }
    return false
}

; --- 判斷是否為單獨執行 ---
if (A_LineFile == A_ScriptFullPath) {
    SetTitleMatchMode 2
    OnExit((*) => RestoreCursor())
    MyMenu := Menu()
    BuildCustomsMenu(MyMenu)

    Customs_StandaloneRButton(*) {
        if (isMouseLocked)
            return
        if (isRunning) {
            Click "Right"
            return
        }
        if !KeyWait("RButton", "T0.3") {
            MyMenu.Show()
            KeyWait "RButton"
        } else {
            Click "Right"
        }
    }

    Customs_StandaloneF8(*) {
        RestoreCursor()
        Reload()
    }

    Hotkey "$RButton", Customs_StandaloneRButton, "T2"
    Hotkey "F8", Customs_StandaloneF8
}
