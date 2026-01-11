module trayicon;

import core.sys.windows.windows;
import core.sys.windows.shellapi;
import std.utf : toUTF16z; // ТОВА ЛИПСВАШЕ
import constants;

class TrayIcon {
    private HWND parentHwnd;
    private NOTIFYICONDATAW nid;

    this(HWND hwnd) {
        this.parentHwnd = hwnd;
        
        nid.cbSize = NOTIFYICONDATAW.sizeof;
        nid.hWnd = hwnd;
        nid.uID = 1;
        nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
        nid.uCallbackMessage = WM_TRAYICON;
        // nid.hIcon = LoadIconW(null, IDI_APPLICATION);
        nid.hIcon = cast(HICON)LoadImageW(null, "app.ico"w.ptr, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE);
        
        auto tip = "D-Pomodoro Timer"w;
        nid.szTip[0 .. tip.length] = tip[];
        
        Shell_NotifyIconW(NIM_ADD, &nid);
    }

    void showMenu(bool isPaused) {
        HMENU hMenu = CreatePopupMenu();
        
        // Текстът на бутона се мени динамично
        string pauseText = isPaused ? "Resume" : "Pause";
        AppendMenuW(hMenu, MF_STRING, ID_TRAY_PAUSE, pauseText.toUTF16z);
        AppendMenuW(hMenu, MF_SEPARATOR, 0, null);
        
        AppendMenuW(hMenu, MF_STRING, ID_TRAY_SETTINGS, "Settings"w.ptr);
        AppendMenuW(hMenu, MF_STRING, ID_TRAY_ABOUT, "About"w.ptr);
        AppendMenuW(hMenu, MF_SEPARATOR, 0, null);
        AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT, "Exit"w.ptr);

        POINT pt;
        GetCursorPos(&pt);
        SetForegroundWindow(parentHwnd);
        TrackPopupMenu(hMenu, TPM_RIGHTBUTTON, pt.x, pt.y, 0, parentHwnd, null);
        DestroyMenu(hMenu);
    }

    // Новата функция за изскачащи известия (Balloon Tips)
    void showNotification(string title, string message) {
        nid.uFlags |= NIF_INFO;
        
        // Важно: Почистваме старите низове, преди да копираме новите
        nid.szInfoTitle[] = 0;
        nid.szInfo[] = 0;

        import core.stdc.wchar_ : wcscpy;
        wcscpy(nid.szInfoTitle.ptr, title.toUTF16z);
        wcscpy(nid.szInfo.ptr, message.toUTF16z);
        
        nid.uTimeout = 10000; // 10 секунди
        nid.dwInfoFlags = NIIF_INFO; // Синя иконка "i"
        
        Shell_NotifyIconW(NIM_MODIFY, &nid);
    }

    // Позволява ни да променяме текста, който се вижда при задържане на мишката
    void updateTooltip(string text) {
        auto tip = text.toUTF16z;
        import core.stdc.wchar_ : wcscpy;
        wcscpy(nid.szTip.ptr, tip);
        nid.uFlags |= NIF_TIP;
        Shell_NotifyIconW(NIM_MODIFY, &nid);
    }

    void remove() {
        Shell_NotifyIconW(NIM_DELETE, &nid);
    }
}