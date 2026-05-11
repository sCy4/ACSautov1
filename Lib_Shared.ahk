#Requires AutoHotkey v2.0

; --- 全域狀態變數 ---
global isRunning := false
global isMouseLocked := false 

; --- OSD 介面初始化 ---
global OSD := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
OSD.BackColor := "FCA311"
OSD.SetFont("s18", "Microsoft JhengHei")
global OSD_Text := OSD.Add("Text", "w600 r2 Center c14213D", "準備中...")

ShowOSD(text) {
    OSD_Text.Value := text
    OSD.Show("NoActivate xCenter y100")
}

HideOSD() {
    OSD.Hide()
}

SetSystemCursor(Cursor := "Wait") {
    CursorIDs := [32512, 32513, 32649] 
    for id in CursorIDs {
        hCursor := DllCall("LoadCursor", "Ptr", 0, "UInt", Cursor == "Wait" ? 32514 : 32512, "Ptr")
        hCopy := DllCall("CopyImage", "Ptr", hCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
        DllCall("SetSystemCursor", "Ptr", hCopy, "UInt", id)
    }
}

RestoreCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)
}

EndProcess() {
    global isRunning := false
    global isMouseLocked := false 
    RestoreCursor()
    HideOSD()
}

; --- 全域熱鍵：防誤觸滑鼠鎖 ---
#HotIf isMouseLocked
*LButton::return
*MButton::return
*WheelUp::return
*WheelDown::return
*XButton1::return
*XButton2::return
#HotIf

; --- 全域熱鍵：暫停與恢復 ---
#HotIf isRunning
Esc:: {
    static paused := false
    static wasLocked := false
    paused := !paused
    if paused {
        wasLocked := isMouseLocked
        global isMouseLocked := false
        RestoreCursor()
        ShowOSD("⏸️ 腳本已暫停 - 你可以正常操作電腦`n(回到暫停時的畫面按 ESC 恢復運作) (按 F8 關閉腳本)")
        Pause 1
    } else {
        global isMouseLocked := wasLocked
        if (isMouseLocked)
            SetSystemCursor("Wait")
            
        ShowOSD("⏳ 腳本恢復中...")
        Sleep 1500
        
        if (isRunning && !isMouseLocked)
            ShowOSD("⏳ 正在修改表單資料，請稍等...")
        else if (isRunning)
            ShowOSD("▶️ 腳本繼續運行中...")
        else
            HideOSD()
            
        Pause 0
    }
}
#HotIf