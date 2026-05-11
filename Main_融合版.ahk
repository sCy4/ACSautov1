#Requires AutoHotkey v2.0
SetTitleMatchMode 2
OnExit((*) => RestoreCursor())

; 引入共用模組與兩個腳本的邏輯
#Include %A_ScriptDir%\Lib_Shared.ahk
#Include %A_ScriptDir%\Lib_General.ahk
#Include %A_ScriptDir%\Lib_Customs.ahk

; 建立融合選單
MergedMenu := Menu()

; 1. 載入萬用選單項目
BuildGeneralMenu(MergedMenu)

; 2. 加上分隔線
MergedMenu.Add()

; 3. 載入清關自動化項目
BuildCustomsMenu(MergedMenu)

; --- 總管熱鍵綁定 ---
#MaxThreadsPerHotkey 2
$RButton:: {
    if (isMouseLocked)
        return

    if (isRunning) {
        Click "Right"
        return
    }

    if !KeyWait("RButton", "T0.3") {
        MergedMenu.Show()
        KeyWait "RButton"
    } else {
        Click "Right"
    }
}
#MaxThreadsPerHotkey 1

F8:: {
    RestoreCursor()
    Reload()
}