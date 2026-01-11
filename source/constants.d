module constants;

import core.sys.windows.windows;

enum : uint {
    ID_TRAY_EXIT = 1001,
    ID_TRAY_SETTINGS = 1002,
    ID_TRAY_ABOUT = 1003,
    ID_BTN_SAVE = 2001, // ID за бутона Save
    WM_TRAYICON = WM_USER + 1,
    ID_TRAY_PAUSE = 1005
}