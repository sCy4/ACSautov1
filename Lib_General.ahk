#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib_Shared.ahk

global SysDelay := 50
global SysSleep := 40

; --- 動作函數 (移除 OSD 橫幅，保留狀態鎖與轉圈游標) ---
Action_Sign(category, *) {
    global isRunning := true, isMouseLocked := true
    SetSystemCursor("Wait")
    
    SetKeyDelay SysDelay * 0.6
    SendEvent "{End}+{Home}^v{Tab 3}"
    SendText category
    Sleep SysSleep
    SendEvent "{Enter}"
    EndProcess()
}

Action_PP(Ptype, *) {
    global isRunning := true, isMouseLocked := true
    SetSystemCursor("Wait")

    SavedClip := ClipboardAll()
    SetKeyDelay SysDelay
    SendEvent "{End}+{Home}^v{Tab}{Up}{Down 2}{Tab}"
    Sleep SysSleep
    SendText Ptype
    Sleep SysSleep
    SendEvent "{Enter}+{Tab}^c{Tab}{End}+{Home}^v{F3}"
    Sleep SysSleep * 5
    A_Clipboard := SavedClip
    SavedClip := ""
    EndProcess()
}

Action_TPC(Cnumber, *) {
    global isRunning := true, isMouseLocked := true
    SetSystemCursor("Wait")

    SetKeyDelay SysDelay
    SendEvent "{Tab}{Enter}"
    Sleep SysSleep
    SendText Cnumber
    Sleep SysSleep
    SendEvent "{Enter 2}"
    EndProcess()
}

; --- 建立選單函數 ---
BuildGeneralMenu(TargetMenu) {
    TPCourierMenu := Menu()
    TPCourierList := [
        ["01. 西-溫正杭", "20240513"], ["02. 東-蔡俊傑", "20240710"],
        ["03. 西-戴勝堂", "20250324"], ["04. 東-郭香蘭", "20260305"],
        ["05. 東-趙克強", "20289041"], ["06. 東-牟善賢", "20290022"],
        ["07. 東-詹益全", "20296021"], ["08. 東-吳萌瑜", "20997092"],
        ["09. 東-鄒樂勳", "21005222"], ["10. 西-梁志強", "21192074"]
    ]
    for _, item in TPCourierList
        TPCourierMenu.Add(item[1], Action_TPC.Bind(item[2]))

    MotoCourierMenu := Menu()
    MotoCourierList := [
        ["機車快遞2", "MOTO2"], ["機車快遞5", "MOTO5"],
        ["機車快遞8", "MOTO8"], ["機車快遞10", "MOTO10"],
        ["機車快遞12", "MOTO12"], ["機車快遞13", "MOTO13"]
    ]
    for _, item in MotoCourierList
        MotoCourierMenu.Add(item[1], Action_TPC.Bind(item[2]))

    TargetMenu.Add("◎ 快速簽收", (*) => "")
    TargetMenu.Disable("◎ 快速簽收")
    TargetMenu.Add(" 1. 已簽收", Action_Sign.Bind("已簽收"))
    TargetMenu.Add(" 2. 櫃台簽收", Action_Sign.Bind("櫃台簽收"))
    TargetMenu.Add(" 3. 已放置客戶指定位置", Action_Sign.Bind("已放置客戶指定位置"))
    TargetMenu.Add()
    
    TargetMenu.Add("◎ 快速問題件", (*) => "")
    TargetMenu.Disable("◎ 快速問題件")
    TargetMenu.Add(" 1. 電話無人接", Action_PP.Bind("01"))
    TargetMenu.Add(" 2. 收件人另約派送日期", Action_PP.Bind("ct"))
    TargetMenu.Add(" 3. 地址錯誤", Action_PP.Bind("97"))
    TargetMenu.Add(" 4. 收件人更改派送地址", Action_PP.Bind("ca"))
    TargetMenu.Add()
    
    TargetMenu.Add("◎ 簽收監控", (*) => "")
    TargetMenu.Disable("◎ 簽收監控")
    TargetMenu.Add(" 北市十位外務", TPCourierMenu)
    TargetMenu.Add(" 六位外派", MotoCourierMenu)
}

; --- 判斷是否為單獨執行 ---
if (A_LineFile == A_ScriptFullPath) {
    SetTitleMatchMode 2
    OnExit((*) => RestoreCursor())
    MyMenu := Menu()
    BuildGeneralMenu(MyMenu)

    ; 加上 General_ 前綴避免名稱衝突
    General_StandaloneRButton(*) {
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

    General_StandaloneF8(*) {
        RestoreCursor()
        Reload()
    }

    ; 綁定熱鍵
    Hotkey "$RButton", General_StandaloneRButton, "T2"
    Hotkey "F8", General_StandaloneF8
}