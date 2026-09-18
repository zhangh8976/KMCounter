/*
已知问题
更换显示器后尺寸无法自动更新
*/
/*
更新地址
https://github.com/zhangh8976/KMCounter
*/
;编译信息
;@Ahk2Exe-Bin Unicode 32*
;@Ahk2Exe-SetName KMCounter
;@Ahk2Exe-SetVersion 4.2.3
;@Ahk2Exe-SetCopyright telppa (2021 - )
;@Ahk2Exe-SetMainIcon resouces\KMCounter.ico

#NoEnv
#SingleInstance Force
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
#Include %A_ScriptDir%\Lib\TileRenderer.ahk
#Include %A_ScriptDir%\Lib\Heatmap.ahk
#Include %A_ScriptDir%\Lib\Storage.ahk
#Include %A_ScriptDir%\Lib\Localization.ahk

global DemoMode := (A_Args[1] = "--demo" || A_Args[1] = "--smoke" || A_Args[1] = "--render-preview")
if (A_Args[1] = "--self-test") {
  RunSelfTests()
  ExitApp
}
global APPName:="KMCounter", ver:="4.2.3"
     , today:=SubStr(A_Now, 1, 8)
     , tomorrow:=EnvAdd(today, 1, "Days", 1, 8)
     , DataStorageDays, firstday
     , devicecaps:={}, layout:={}
     , hHookMouse, mouse:={}
     , hHookKeyboard, keyboard:={}

LoadData(today)
gosub, MultiLanguage
gosub, CreateMenu                       ; 创建托盘菜单
gosub, CreateGui1                       ; 预先创建 GUI1 以便需要时加速显示
gosub, CreateGui2                       ; 预先创建 GUI2 以便需要时加速显示

if (A_Args[1] = "--render-preview") {
  RenderDesignPreviews()
  ExitApp
}

if (A_Args[1] = "--smoke") {
  TestDashboard()
  ExitApp
}

if (!DemoMode) {
  HookMouse()
  HookKeyboard()
}

SetTimer, Reload, % countdown()         ; 设置一个计时器用于跨夜时重启进程以便保存当日数据并开始新的一天
if (!DemoMode)
  SetTimer, ReloadHook, % 60000*10        ; 每10分钟重载一次钩子，避免用户的按键映射型钩子的影响
OnExit("ExitFunc")                      ; 退出时在这里卸载钩子并保存参数

SetTimer, RefreshDashboard, 1000
if (!DemoMode)
  SetTimer, PersistCounts, 60000
if (DemoMode || A_Args[1] != "--background")
  gosub, ShowHeatMap
return

CreateGui1:
  BuildDashboard()
return

RangeClick:
  SelectedRange := SubStr(A_GuiControl, 6) + 0
  gosub, ShowHeatMap
return

SelectThemeFromTray:
  for i, label in ThemeMenuLabels
    if (A_ThisMenuItem = label) {
      SetDashboardTheme(i)
      break
    }
return

OpenSettings:
  GuiControl, 2:, dsd,  % DataStorageDays
  GuiControl, 2:, dw,   % devicecaps.w
  GuiControl, 2:, dh,   % devicecaps.h
  GuiControl, 2:, lkw,  % layout.kw
  GuiControl, 2:, lkh,  % layout.kh
  GuiControl, 2:, lks,  % layout.ks
  GuiControl, 2:, lkhs, % layout.khs
  GuiControl, 2:, lkvs, % layout.kvs
  Gui, 2:Show, , %L_gui2_设置%
return

SelectLanguageFromTray:
  SetDashboardLanguage(A_ThisMenuItem = "English" ? "en" : "zh")
return

SelectPaletteFromTray:
  for i, label in PaletteMenuLabels
    if (A_ThisMenuItem = label) {
      SetDashboardPalette(i)
      break
    }
return

ShowHeatMap:
  Gui, 1:Show, , % "KMCounter" (DemoMode ? Tr(" · 演示数据", " · Demo") : "")
  RefreshDashboard()
return

RefreshDashboard:
  if (DllCall("IsWindowVisible", "Ptr", hWin))
    RefreshDashboard()
return

PersistCounts:
  SaveData()
return

GuiEscape:
GuiClose:
  Gui, 1:Hide
  ToolTip
return

CreateGui2:
  BuildSettings()
  ApplyLanguageLabels()
return

CancelSetting:
2GuiEscape:
2GuiClose:
  Gui, 2:Hide
return

SaveSetting:
  Gui, 2:Submit
  ; 主文件保留天数；旧明细按年归档。
  DataStorageDays := Round(NonNull_Ret(dsd, 366, 1))
  UpdateDeviceCaps(dw, dh)
  UpdateLayout(lkw, lkh, lks, lkhs, lkvs)
  ; 直接重启以便更新设置
  gosub, Reload
return

Reload:
  Reload
return

ReloadHook:
  ; 如果用户的 .ahk 在我们之后运行，并且其中含有 a::b 之类的按键映射，此时就需要重载以便我们的钩子更靠前，才能获取消息。
  DllCall("UnhookWindowsHookEx", "Ptr", hHookMouse)
  DllCall("UnhookWindowsHookEx", "Ptr", hHookKeyboard)
  HookMouse()
  HookKeyboard()
return

CreateMenu:
{
  if (MenusReady) {
    Menu, Tray, DeleteAll
    Menu, SettingsMenu, DeleteAll
    Menu, ThemeMenu, DeleteAll
    Menu, PaletteMenu, DeleteAll
    Menu, LanguageMenu, DeleteAll
  }
  MenusReady := true
  Menu, Tray, NoStandard                           ; 不显示 ahk 自己的菜单
  Menu, Tray, Tip, %APPName% v%ver%                ; 托盘提示信息
  Menu, Tray, Add, %L_menu_统计%,     MenuHandler  ; 创建新菜单项
  ThemeMenuLabels := [ThemeDisplayName(1), ThemeDisplayName(2)]
  Menu, SettingsMenu, Add, % Tr("常规设置…", "Preferences…"), OpenSettings
  Menu, SettingsMenu, Add
  for i, label in ThemeMenuLabels
    Menu, ThemeMenu, Add, %label%, SelectThemeFromTray, +Radio
  Menu, SettingsMenu, Add, % Tr("主题", "Theme"), :ThemeMenu
  UpdateThemeMenu()
  PaletteMenuLabels := []
  UpdatePaletteMenu(true)
  Menu, LanguageMenu, Add, 中文, SelectLanguageFromTray, +Radio
  Menu, LanguageMenu, Add, English, SelectLanguageFromTray, +Radio
  Menu, LanguageMenu, Check, % AppLanguage="en" ? "English" : "中文"
  Menu, SettingsMenu, Add, 语言 / Language, :LanguageMenu
  Menu, Tray, Add, %L_menu_设置%, :SettingsMenu
  Menu, Tray, Add                                  ; 分隔符
  Menu, Tray, Add, %L_menu_开机启动%, MenuHandler
  Menu, Tray, Add, %L_menu_布局定制%, MenuHandler
  Menu, Tray, Add
  Menu, Tray, Add, %L_menu_退出%,     MenuHandler
  Menu, Tray, Default, %L_menu_统计%               ; 将统计设为默认项

  if (!A_IsCompiled)
    Menu, Tray, Icon, resouces\KMCounter.ico

  IfExist, %A_Startup%\%APPName%.Lnk                 ; 检测启动文件夹中是否有快捷方式来确定是否勾选自启
    Menu, Tray, Check, %L_menu_开机启动%
}
return

MenuHandler:
  if (A_ThisMenuItem = L_menu_统计)
  {
    gosub, ShowHeatMap
  }

  if (A_ThisMenuItem = L_menu_开机启动)
  {
    IfExist, %A_Startup%\%APPName%.Lnk
    {
      FileDelete, %A_Startup%\%APPName%.Lnk
      Menu, Tray, UnCheck, %L_menu_开机启动%
    }
    else
    {
      FileCreateShortcut, %A_ScriptFullPath%, %A_Startup%\%APPName%.Lnk, %A_ScriptDir%, --background
      Menu, Tray, Check, %L_menu_开机启动%
    }
  }

  if (A_ThisMenuItem = L_menu_布局定制)
  {
    contactEmail := "huizhang8080@gmail.com"
    MsgBox, 64, % Tr("布局定制", "Custom Layout"), % Tr("如需定制键盘布局，请联系：", "For a custom keyboard layout, contact:") "`n`n" contactEmail
  }

  if (A_ThisMenuItem = L_menu_退出)
    ExitApp
return

ExitFunc(ExitReason, ExitCode)
{
  DllCall("UnhookWindowsHookEx", "Ptr", hHookMouse)
  DllCall("UnhookWindowsHookEx", "Ptr", hHookKeyboard)
  FreeTileBrushes()
  if (!DemoMode)
    SaveData()
}

HookMouse()
{
  ; 全局鼠标钩子
  hHookMouse := DllCall("SetWindowsHookEx" . (A_IsUnicode ? "W" : "A")
                      , "Int", WH_MOUSE_LL := 14
                      , "Ptr", RegisterCallback("LowLevelMouseProc", "Fast", 3)
                      , "Ptr", DllCall("GetModuleHandle", "UInt", 0, "Ptr")
                      , "UInt", 0, "Ptr")
}
; https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644986(v=vs.85)
; 非常坑爹的，在上面微软链接中没有记录 0x0208 0x020C 等值。
LowLevelMouseProc(nCode, wParam, lParam)
{
  static oldx, oldy, init:=MouseGetPos(oldx, oldy)
  Critical
  ; lParam 是一个指针，假设 &lParam = 0x123，而 lParam = 0x456
  ; 也就是它自身地址是 0x123 ，自身存储的地址是 0x456
  ; 直接 NumGet(lParam, 12, "UInt") 的话，是把 0x456 这个值按 uint 解析
  ; 而 NumGet(lParam+0, 12, "UInt") ，是把 0x456 这个地址里面的值按 uint 解析
  flags := NumGet(lParam+0, 12, "UInt") & 0x1                            ; 物理按下是0，模拟是1。0x1 = 00000001
  if (nCode>=0 and flags=0)
  {
    switch, wParam
    {
      case, 0x0200:                                                      ; WM_MOUSEMOVE   = 0x0200
          x := NumGet(lParam+0, 0, "Int")
        , y := NumGet(lParam+0, 4, "Int")
        , d := Sqrt((x-oldx)**2 + (y-oldy)**2)                           ; 勾股求斜边
        , d := d * devicecaps.w / A_ScreenWidth / 1000                   ; 将单位 像素 转换为 米
        , oldx := x, oldy := y
        , mouse[today].move += d
        , mouse.total.move  += d
      case, 0x0202: mouse[today].lbcount += 1, mouse.total.lbcount += 1  ; WM_LBUTTONUP   = 0x0202
      case, 0x0205: mouse[today].rbcount += 1, mouse.total.rbcount += 1  ; WM_RBUTTONUP   = 0x0205
      case, 0x0208: mouse[today].mbcount += 1, mouse.total.mbcount += 1  ; WM_MBUTTONUP   = 0x0208
      case, 0x020C: mouse[today].xbcount += 1, mouse.total.xbcount += 1  ; WM_XBUTTONUP   = 0x020C
      case, 0x020A: mouse[today].wheel   += 1, mouse.total.wheel   += 1  ; WM_MOUSEWHEEL  = 0x020A
      case, 0x020E: mouse[today].hwheel  += 1, mouse.total.hwheel  += 1  ; WM_MOUSEHWHEEL = 0x020E
    }
  }
  ; CallNextHookEx 让其它钩子可以继续处理消息
  ; 返回非0值 例如1 告诉系统此消息将丢弃
  return, DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

HookKeyboard()
{
  ; 全局键盘钩子
  hHookKeyboard := DllCall("SetWindowsHookEx" . (A_IsUnicode ? "W" : "A")
                         , "Int", WH_KEYBOARD_LL := 13
                         , "Ptr", RegisterCallback("LowLevelKeyboardProc", "Fast", 3)
                         , "Ptr", DllCall("GetModuleHandle", "UInt", 0, "Ptr")
                         , "UInt", 0, "Ptr")
}
; https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644985(v=vs.85)
LowLevelKeyboardProc(nCode, wParam, lParam)
{
  Critical
  flags := NumGet(lParam+0, 8, "UInt") & 0x10                         ; 物理按下是0，模拟是非0。0x10 = 00010000
  if (nCode>=0 and flags=0 and (wParam = 0x0101 or wParam = 0x0105))  ; WM_KEYUP = 0x0101 WM_SYSKEYUP = 0x0105
  {
    ; vk := NumGet(lParam+0, "UInt")                                  ; vk 不能区分数字键盘，所以用 sc
      Extended := NumGet(lParam+0, 8, "UInt") & 0x1                   ; 扩展键（即功能键或者数字键盘上的键）是1，否则是0
    , sc := (Extended<<8) | NumGet(lParam+0, 4, "UInt")
    if (!keyboard[today].HasKey("sc" sc))                             ; 即使不在布局中的按键依然初始化，使其可被记录
    {
      keyboard[today,   "sc" sc] := 0
      if (!keyboard.total.HasKey("sc" sc))
        keyboard["total", "sc" sc] := 0
    }
      keyboard[today,   "sc" sc] += 1
    , keyboard["total", "sc" sc] += 1
    , keyboard[today,   "keystrokes"] += 1
    , keyboard["total", "keystrokes"] += 1
  }
  ; CallNextHookEx 让其它钩子可以继续处理消息
  ; 返回非0值 例如1 告诉系统此消息将丢弃
  return, DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

countdown()
{
  ; 距离明天凌晨 0:00:05 的秒数，+5秒是为了给系统时间不准留点余量
  return, -(EnvSub(tomorrow, A_Now, "Seconds")+5)*1000
}

UpdateDeviceCaps(w:="", h:="")
{
  ; 我的屏幕使用 EDID 与 GetDeviceCaps 两种方法获取到的屏幕尺寸都是错的
  ; 并且 aida64 之类的软件获取到的屏幕尺寸也是错的
  ; 所以并不存在一种 100% 准确获取屏幕物理尺寸的方法
  if (w>0 and h>0)                                                          ; 传过来的值可能是空格（空值），所以用大于符号判断。
  {
    devicecaps.w  := w                                                      ; 有传值过来则直接使用
    devicecaps.h  := h
  }
  else
  {                                                                         ; 没有传值过来则获取屏幕物理尺寸
    hdcScreen     := DllCall("GetDC", "UPtr", 0, "Ptr")
    devicecaps.w  := DllCall("GetDeviceCaps", "UPtr", hdcScreen, "Int", 4)  ; 毫米
    devicecaps.h  := DllCall("GetDeviceCaps", "UPtr", hdcScreen, "Int", 6)  ; 毫米
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
  }
  devicecaps.size := (Sqrt(devicecaps.w**2 + devicecaps.h**2)/25.4)         ; 英寸 勾股求斜边
}

UpdateLayout(lkw, lkh, lks, lkhs, lkvs)
{
  layout.kw  := lkw
  layout.kh  := lkh
  layout.ks  := lks
  layout.khs := lkhs
  layout.kvs := lkvs
}

IniRead(Filename, Section:="", Key:="", Default:=""){
  IniRead, OutputVar, %Filename%, %Section%, %Key%, %Default%
  ; 不管是没找到键 亦或是 键值为空 都返回默认值
  return, (OutputVar="" || OutputVar="ERROR") ? Default : OutputVar
}
IniWrite(Value, Filename, Section, Key:=""){
  IniWrite, %Value%, %Filename%, %Section%, %Key%
}
EnvSub(Var, Value, TimeUnits){
  EnvSub, Var, %Value%, %TimeUnits%
  return, Var
}
EnvAdd(Var, Value, TimeUnits, StartingPos, Length){
  EnvAdd, Var, %Value%, %TimeUnits%
  ; 日期经过 EnvAdd 计算后位数会发生变化，所以用 SubStr 还原。
  return, SubStr(Var, StartingPos, Length)
}
MouseGetPos(ByRef OutputVarX, ByRef OutputVarY){
	MouseGetPos, OutputVarX, OutputVarY
}
MouseGetClassNN(){
	MouseGetPos,,,,OutputVarControl
  return, OutputVarControl
}

; 此函数储存了每个按键之间的大小与距离关系，实现了自定义键盘大小。
LoadControlList(layout:="")
{
  KeyW              := NonNull_Ret(layout.kw,  52, 30)  ; 限制按键宽度最小值为30
  KeyH              := NonNull_Ret(layout.kh,  45, 25)  ; 限制按键高度最小值为25（可以正常显示1行文本的最小高度）
  KeySpacing        := NonNull_Ret(layout.ks,  2,  0)   ; 限制键间距
  HorizontalSpacing := NonNull_Ret(layout.khs, 10, 0)   ; 限制区域水平间距
  VerticalSpacing   := NonNull_Ret(layout.kvs, 10, 0)   ; 限制区域垂直间距

  m:=[KeySpacing,        "+" KeySpacing                 ; 普通按键间距
    , HorizontalSpacing, "+" HorizontalSpacing          ; 区域水平间距
    , VerticalSpacing,   "+" VerticalSpacing            ; 区域垂直间距
    , "",                ""]                            ; ESC-F1 间距（计算得到）

  , w    :=  KeyW                                       ; w h 不带数字的是普通按键的宽高，带数字则表示第n行特殊按键的宽高。
  , h    :=  KeyH
  , w2   :=  w*2+10                                     ; BackSpace
  , w3   := (w*13 + w2 - w*12 + m.1*0)/2                ; Tab      \
  , w4   := (w*13 + w2 - w*11 + m.1*1)/2                ; CapsLock Enter
  , w5   := (w*13 + w2 - w*10 + m.1*2)/2                ; Shift
  , w6_1 :=  w3                                         ; Ctrl
  , w6_2 :=  w6_1-10                                    ; Win      Alt
  , w6_3 := (w*13 + w2 - w6_1*2 - w6_2*4 + m.1*7)       ; Space

  , m7   := (w*13 + w2 - w*13 + m.1*4)/3                ; ESC-F1 间距
  , m.7  :=  m7
  , m.8  :=  "+" m7

  list:=[]
  ; 第一行
  list.push({Hwnd:"sc1",  Text:"Esc", x:"",  y:"", w:w, h:h})
  list.push({Hwnd:"sc59", Text:"F1",  x:m.8, y:"", w:w, h:h})
  list.push({Hwnd:"sc60", Text:"F2",  x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc61", Text:"F3",  x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc62", Text:"F4",  x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc63", Text:"F5",  x:m.8, y:"", w:w, h:h})
  list.push({Hwnd:"sc64", Text:"F6",  x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc65", Text:"F7",  x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc66", Text:"F8",  x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc67", Text:"F9",  x:m.8, y:"", w:w, h:h})
  list.push({Hwnd:"sc68", Text:"F10", x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc87", Text:"F11", x:m.2, y:"", w:w, h:h})
  list.push({Hwnd:"sc88", Text:"F12", x:m.2, y:"", w:w, h:h})
  ; 第二行
  list.push({Hwnd:"sc41", Text:"``",        x:"m", y:m.4, w:w,  h:h})
  list.push({Hwnd:"sc2",  Text:"1",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc3",  Text:"2",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc4",  Text:"3",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc5",  Text:"4",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc6",  Text:"5",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc7",  Text:"6",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc8",  Text:"7",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc9",  Text:"8",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc10", Text:"9",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc11", Text:"0",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc12", Text:"-",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc13", Text:"=",         x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc14", Text:"BackSpace", x:m.2, y:"",  w:w2, h:h})
  ; 第三行
  list.push({Hwnd:"sc15", Text:"Tab", x:"m", y:m.2, w:w3, h:h})
  list.push({Hwnd:"sc16", Text:"q",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc17", Text:"w",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc18", Text:"e",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc19", Text:"r",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc20", Text:"t",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc21", Text:"y",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc22", Text:"u",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc23", Text:"i",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc24", Text:"o",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc25", Text:"p",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc26", Text:"[",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc27", Text:"]",   x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc43", Text:"\",   x:m.2, y:"",  w:w3, h:h})
  ; 第四行
  list.push({Hwnd:"sc58", Text:"CapsLock", x:"m", y:m.2, w:w4, h:h})
  list.push({Hwnd:"sc30", Text:"a",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc31", Text:"s",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc32", Text:"d",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc33", Text:"f",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc34", Text:"g",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc35", Text:"h",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc36", Text:"j",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc37", Text:"k",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc38", Text:"l",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc39", Text:";",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc40", Text:"'",        x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc28", Text:"Enter",    x:m.2, y:"",  w:w4, h:h})
  ; 第五行
  list.push({Hwnd:"sc42", Text:"Shift", x:"m", y:m.2, w:w5, h:h})
  list.push({Hwnd:"sc44", Text:"z",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc45", Text:"x",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc46", Text:"c",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc47", Text:"v",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc48", Text:"b",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc49", Text:"n",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc50", Text:"m",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc51", Text:",",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc52", Text:".",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc53", Text:"/",     x:m.2, y:"",  w:w,  h:h})
  list.push({Hwnd:"sc310", Text:"Shift", x:m.2, y:"",  w:w5, h:h})
  ; 第六行
  list.push({Hwnd:"sc29",  Text:"Ctrl",  x:"m", y:m.2, w:w6_1, h:h})
  list.push({Hwnd:"sc347", Text:"Win",   x:m.2, y:"",  w:w6_2, h:h})
  list.push({Hwnd:"sc56",  Text:"Alt",   x:m.2, y:"",  w:w6_2, h:h})
  list.push({Hwnd:"sc57",  Text:"Space", x:m.2, y:"",  w:w6_3, h:h})
  list.push({Hwnd:"sc312", Text:"Alt",   x:m.2, y:"",  w:w6_2, h:h})
  list.push({Hwnd:"sc348", Text:"Win",   x:m.2, y:"",  w:w6_2, h:h})
  list.push({Hwnd:"sc285", Text:"Ctrl",  x:m.2, y:"",  w:w6_1, h:h})

  ; 定位翻页键的区域，确保高度与第二行一致。temp1:="ym+123 Section"
  temp1:="m+" h+m.3 " Section"
  list.push({Hwnd:"sc338", Text:"Insert", x:m.6, y:temp1, w:w, h:h})
  list.push({Hwnd:"sc327", Text:"Home",   x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc329", Text:"PageUp", x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc339", Text:"Delete", x:"s", y:m.2,   w:w, h:h})
  list.push({Hwnd:"sc335", Text:"End",    x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc337", Text:"PageDn", x:m.2, y:"",    w:w, h:h})

  ; 定位方向键的区域，确保高度与第五行一致。temp1:="xs+123" temp2:="y+123"
  temp1:="s+" w+m.1, temp2:="+" h+2*m.1
  list.push({Hwnd:"sc328", Text:"▲", x:temp1, y:temp2, w:w, h:h})
  list.push({Hwnd:"sc331", Text:"◀", x:"s",   y:m.2,   w:w, h:h})
  list.push({Hwnd:"sc336", Text:"▼", x:m.2,   y:"",    w:w, h:h})
  list.push({Hwnd:"sc333", Text:"▶", x:m.2,   y:"",    w:w, h:h})

  ; 定位数字键盘的区域，确保高度与第二行一致。temp1:="ym+123 Section"
  temp1:="m+" h+m.3 " Section"
  list.push({Hwnd:"sc325", Text:"NumLock", x:m.6, y:temp1, w:w, h:h})
  list.push({Hwnd:"sc309", Text:"/",       x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc55",  Text:"*",       x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc74",  Text:"-",       x:m.2, y:"",    w:w, h:h})
  ; 数字键盘第二行
  list.push({Hwnd:"sc71", Text:"7",        x:"s", y:m.2,   w:w, h:h})
  list.push({Hwnd:"sc72", Text:"8",        x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc73", Text:"9",        x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc78", Text:"+",        x:m.2, y:"",    w:w, h:h*2+m.1})
  ; 数字键盘第三行
  temp1:="s+" (h+m.1)*2
  list.push({Hwnd:"sc75", Text:"4",        x:"s", y:temp1, w:w, h:h})
  list.push({Hwnd:"sc76", Text:"5",        x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc77", Text:"6",        x:m.2, y:"",    w:w, h:h})
  ; 数字键盘第四行
  temp1:="s+" (h+m.1)*3
  list.push({Hwnd:"sc79",  Text:"1",       x:"s", y:temp1, w:w, h:h})
  list.push({Hwnd:"sc80",  Text:"2",       x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc81",  Text:"3",       x:m.2, y:"",    w:w, h:h})
  list.push({Hwnd:"sc284", Text:"Enter",   x:m.2, y:"",    w:w, h:h*2+m.1})
  ; 数字键盘第五行
  temp1:="s+" (h+m.1)*4
  list.push({Hwnd:"sc82", Text:"0",        x:"s", y:temp1, w:w*2+m.1, h:h})
  list.push({Hwnd:"sc83", Text:".",        x:m.2, y:"",    w:w,       h:h})

  ; 信息框
    temp1:="m+" w*13+Round(m.7*3)+m.1*9+m.5
  , temp2:=w*7+m.1*5+m.5    ; 与 翻页键区域 + 数字键盘区域 等宽
  , temp3:=h                ; 与 单个按键等高
  list.push({Hwnd:"Message", Text:"",      x:temp1, y:"m", w:temp2, h:temp3})

  ; 信息框放大后会被遮挡的按键列表
  list.Covered := ["sc338", "sc327", "sc329", "sc339", "sc335", "sc337"  ; 翻页区
                 , "sc328", "sc331", "sc336", "sc333"                    ; 方向区
                 , "sc325", "sc309", "sc55",  "sc74"                     ; 小键盘区
                 , "sc71",  "sc72",  "sc73",  "sc78"
                 , "sc75",  "sc76",  "sc77"
                 , "sc79",  "sc80",  "sc81",  "sc284"
                 , "sc82",  "sc83"]

  ; Color 没有 0x 前缀。背景色影响 GUI 信息框 当日按键数据太少时的按键。不影响数据量足够后的按键。
  list.Opt := {Font:"Segoe UI", FontSize:9, BackgroundColor:"101A2B", TextColor:"DAE9F5"}

  return, list
}

MultiLanguage:
  if (AppLanguage != "en")
  {
    L_menu_统计:="统计"
    L_menu_设置:="设置"
    L_menu_开机启动:="开机启动"
    L_menu_布局定制:="布局定制"
    L_menu_退出:="退出"

    L_gui1_当前显示数据:="当前显示数据"
    L_gui1_LV标题:="项目|今日|本周|本月|总计"
    L_gui1_鼠标移动:="鼠标移动"
    L_gui1_键盘敲击:="键盘敲击"
    L_gui1_左键点击:="左键点击"
    L_gui1_右键点击:="右键点击"
    L_gui1_中键点击:="中键点击"
    L_gui1_滚轮滚动:="滚轮滚动"
    L_gui1_滚轮横滚:="滚轮横滚"
    L_gui1_侧键点击:="侧键点击"
    L_gui1_屏幕尺寸:="屏幕尺寸"
    L_gui1_米:="米"
    L_gui1_次:="次"
    L_gui1_寸:="寸"
    L_gui1_msgbox:="今日按键次数较少，故暂未生成按键热点图。"

    L_gui2_设置:="设置"
    L_gui2_历史数据:="历史数据"
    L_gui2_sub1:="主文件保留天数；更早明细按年归档。"
    L_gui2_存储:="存储"
    L_gui2_天:="天"
    L_gui2_屏幕尺寸:="屏幕尺寸"
    L_gui2_sub2:="设置显示器的真实尺寸。"
    L_gui2_屏幕宽:="屏幕宽"
    L_gui2_屏幕高:="屏幕高"
    L_gui2_毫米:="毫米"
    L_gui2_键盘布局:="键盘布局"
    L_gui2_sub3:="设置键盘热力图的尺寸。"
    L_gui2_键宽:="键宽"
    L_gui2_键高:="键高"
    L_gui2_键间距:="键间距"
    L_gui2_区域水平间距:="区域水平间距"
    L_gui2_区域垂直间距:="区域垂直间距"
    L_gui2_像素:="像素"
    L_gui2_取消:="取消"
    L_gui2_保存:="保存"

    L_welcome_main:="欢迎使用 KMCounter"
    L_welcome_sub:="KMCounter 将常驻托盘菜单为你统计所需信息。`n点击托盘图标即可查看统计结果。"
  }
  else
  {
    L_menu_统计:="Statistics"
    L_menu_设置:="Settings"
    L_menu_开机启动:="Start-Up"
    L_menu_布局定制:="Custom Layout"
    L_menu_退出:="Exit"

    L_gui1_当前显示数据:="Date"
    L_gui1_LV标题:="Item|Today|This Week|This Month|Total"
    L_gui1_鼠标移动:="MouseMove"
    L_gui1_键盘敲击:="Keystrokes"
    L_gui1_左键点击:="LButton"
    L_gui1_右键点击:="RButton"
    L_gui1_中键点击:="MButton"
    L_gui1_滚轮滚动:="Wheel"
    L_gui1_滚轮横滚:="HWheel"
    L_gui1_侧键点击:="XButton"
    L_gui1_屏幕尺寸:="Monitor"
    L_gui1_米:="m"
    L_gui1_次:="  "
    L_gui1_寸:="inch"
    L_gui1_msgbox:="The number of keystrokes is too low, keyboard heatmap not generated yet."

    L_gui2_设置:="Settings"
    L_gui2_历史数据:="History"
    L_gui2_sub1:="Active days; older data is archived by year."
    L_gui2_存储:="Storage"
    L_gui2_天:="days"
    L_gui2_屏幕尺寸:="Monitor"
    L_gui2_sub2:="Set the real size of the monitor."
    L_gui2_屏幕宽:="Width"
    L_gui2_屏幕高:="Height"
    L_gui2_毫米:="mm"
    L_gui2_键盘布局:="Layout"
    L_gui2_sub3:="Set the size of the heatmap."
    L_gui2_键宽:="Key Width"
    L_gui2_键高:="Key Height"
    L_gui2_键间距:="Key Spacing"
    L_gui2_区域水平间距:="HSpacing"
    L_gui2_区域垂直间距:="VSpacing"
    L_gui2_像素:="px"
    L_gui2_取消:="Cancel"
    L_gui2_保存:="Save"

    L_welcome_main:="Welcome to KMCounter"
    L_welcome_sub:="KMCounter will stay in the tray menu for statistics.`nClick the tray icon to view the results."
  }
return


#Include %A_ScriptDir%\tests\SelfTest.ahk

#Include %A_ScriptDir%\tests\DesignPreview.ahk
