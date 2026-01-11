module settings;

import core.sys.windows.windows;
import core.sys.windows.commctrl;
import std.conv : to;
import std.utf : toUTF16z;
import std.file : exists, write, readText;
import std.string : splitLines, format, indexOf, strip;
import std.array : replace; // За новия ред
import constants;

enum string TRACKBARW = "msctls_trackbar32";
enum TBM_SETRANGE = WM_USER + 1;
enum TBM_GETPOS = WM_USER + 0;
enum TBM_SETPOS = WM_USER + 5;
enum CLEARTYPE_QUALITY = 5;

extern(Windows)
LRESULT settingsProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) nothrow {
    try {
        auto app = cast(SettingsWindow)cast(void*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
        switch (msg) {
            case WM_HSCROLL:
                if (app) app.updateLabels();
                return 0;
            case WM_COMMAND:
                if (LOWORD(cast(DWORD)wParam) == ID_BTN_SAVE) {
                    if (app) app.saveCurrent();
                    return 0;
                }
                break;
            case WM_CLOSE:
                ShowWindow(hwnd, SW_HIDE);
                return 0;
            default: break;
        }
    } catch (Throwable) {}
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

class SettingsWindow {
    private HWND hwnd;
    private HWND hWorkTrack, hRestTrack;
    private HWND hWorkValLabel, hRestValLabel;
    private HFONT hFont;
    private string configPath = "dp_settings.ini";
    
    public string[string] lang;

    this(HWND parent) {
        loadConfig();

        // Взимаме размера от настройките (дефолт 16, ако липсва)
        int fSize = ("font_size" in lang) ? lang["font_size"].to!int : 16;

        hFont = CreateFontW(fSize, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, 
                            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 
                            CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_SWISS, "Segoe UI"w.ptr);

        string className = "SettingsWindowClass";
        WNDCLASSW swc;
        swc.lpfnWndProc = &settingsProc;
        swc.hInstance = GetModuleHandleW(null);
        swc.lpszClassName = className.toUTF16z;
        swc.hCursor = LoadCursorW(null, IDC_ARROW);
        // Зареждаме иконата и за прозореца с настройки
        swc.hIcon = cast(HICON)LoadImageW(null, "app.ico"w.ptr, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE);
        swc.hbrBackground = cast(HBRUSH)(COLOR_BTNFACE + 1);
        RegisterClassW(&swc);

        hwnd = CreateWindowExW(WS_EX_DLGMODALFRAME, className.toUTF16z, 
            lang["title"].toUTF16z, WS_SYSMENU | WS_CAPTION,
            CW_USEDEFAULT, CW_USEDEFAULT, 350, 300, parent, null, swc.hInstance, null);

        SetWindowLongPtrW(hwnd, GWLP_USERDATA, cast(LONG_PTR)cast(void*)this);

        // Позиционираме контролите (леко разширени заради по-големия шрифт)
        applyFont(createLabel(lang["work_label"], 10, 10, 150));
        hWorkValLabel = applyFont(createLabel("", 170, 10, 80));
        hWorkTrack = CreateWindowExW(0, TRACKBARW.toUTF16z, null, WS_CHILD | WS_VISIBLE | TBS_AUTOTICKS,
            10, 40, 310, 30, hwnd, null, null, null);
        SendMessageW(hWorkTrack, TBM_SETRANGE, TRUE, MAKELONG(1, 240));

        applyFont(createLabel(lang["rest_label"], 10, 95, 150));
        hRestValLabel = applyFont(createLabel("", 170, 95, 80));
        hRestTrack = CreateWindowExW(0, TRACKBARW.toUTF16z, null, WS_CHILD | WS_VISIBLE | TBS_AUTOTICKS,
            10, 125, 310, 30, hwnd, null, null, null);
        SendMessageW(hRestTrack, TBM_SETRANGE, TRUE, MAKELONG(1, 240));

        HWND hBtn = CreateWindowExW(0, "Button"w.ptr, lang["btn_save"].toUTF16z,
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON, 100, 200, 150, 45, hwnd, cast(HMENU)ID_BTN_SAVE, null, null);
        applyFont(hBtn);
            
        updateUIFromConfig();
    }

    private HWND createLabel(string text, int x, int y, int width) {
        return CreateWindowExW(0, "Static"w.ptr, text.toUTF16z, WS_CHILD | WS_VISIBLE, x, y, width, 25, hwnd, null, null, null);
    }

    private HWND applyFont(HWND hCtrl) {
        SendMessageW(hCtrl, WM_SETFONT, cast(WPARAM)hFont, TRUE);
        return hCtrl;
    }

    void updateLabels() {
        int w = cast(int)SendMessageW(hWorkTrack, TBM_GETPOS, 0, 0);
        int r = cast(int)SendMessageW(hRestTrack, TBM_GETPOS, 0, 0);
        SetWindowTextW(hWorkValLabel, (w.to!string ~ " min").toUTF16z);
        SetWindowTextW(hRestValLabel, (r.to!string ~ " min").toUTF16z);
    }

    void updateUIFromConfig() {
        SendMessageW(hWorkTrack, TBM_SETPOS, TRUE, lang["work"].to!int);
        SendMessageW(hRestTrack, TBM_SETPOS, TRUE, lang["rest"].to!int);
        updateLabels();
    }

    void saveCurrent() {
        lang["work"] = SendMessageW(hWorkTrack, TBM_GETPOS, 0, 0).to!string;
        lang["rest"] = SendMessageW(hRestTrack, TBM_GETPOS, 0, 0).to!string;
        
        string content = format("work=%s\nrest=%s\nfont_size=%s\n[labels]\n", 
                                lang["work"], lang["rest"], lang["font_size"]);
        foreach(key; ["title", "work_label", "rest_label", "btn_save", "msg_saved", "msg_err_ini", "about_text"]) {
            content ~= format("%s=%s\n", key, lang[key]);
        }
        write(configPath, content);
        
        ShowWindow(hwnd, SW_HIDE);
        MessageBoxW(null, lang["msg_saved"].toUTF16z, "Info"w.ptr, MB_OK | MB_ICONINFORMATION);
    }

    private void loadConfig() {
        lang = ["work":"25", "rest":"5", "font_size":"16", "title":"Settings", "work_label":"Work:", 
                "rest_label":"Rest:", "btn_save":"Save", "msg_saved":"Saved!", 
                "msg_err_ini":"File not found!", "about_text":"Pomodoro v1.0"];

        if (!exists(configPath)) return;

        foreach(line; readText(configPath).splitLines()) {
            auto idx = line.indexOf('=');
            if (idx != -1) {
                string key = line[0..idx].strip;
                string val = line[idx+1..$].strip;
                val = val.replace("\\n", "\n"); 
                lang[key] = val;
            }
        }
    }

    void show() {
        loadConfig();
        updateUIFromConfig();
        ShowWindow(hwnd, SW_SHOW);
    }
}