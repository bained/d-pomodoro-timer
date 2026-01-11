import core.sys.windows.windows;
import core.sys.windows.shellapi;
import core.runtime;
import std.utf : toUTF16z;
import std.conv : to;
import std.format : format;

import constants;    
import trayicon;     
import settings;     

// Глобални променливи за състоянието на приложението
SettingsWindow settingsWin;
int timeLeftSeconds = 0;
bool isWorking = true;
bool isPaused = false;

extern(Windows)
LRESULT windowProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) nothrow {
    try {
        switch (msg) {

            case WM_TRAYICON:
                if (lParam == WM_RBUTTONUP) {
                    auto tray = cast(TrayIcon)cast(void*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
                    if (tray) tray.showMenu(isPaused); // Предаваме състоянието за динамично меню
                    return 0;
                }
                // Ляв бутон -> Директно отваря настройките (Settings)
                if (lParam == WM_LBUTTONUP) {
                    // Извикваме същия код, който се изпълнява при избор на Settings от менюто
                    if (settingsWin is null) settingsWin = new SettingsWindow(hwnd);
                    settingsWin.show();
                    return 0;
                }
                break;

            case WM_TIMER:
                if (timeLeftSeconds > 0) {
                    timeLeftSeconds--;
                    
                    // Обновяваме тултипа при всяка секунда
                    auto tray = cast(TrayIcon)cast(void*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
                    if (tray) {
                        string status = isWorking ? "Work: " : "Break: ";
                        int mins = timeLeftSeconds / 60;
                        int secs = timeLeftSeconds % 60;
                        tray.updateTooltip(format("%s%02d:%02d", status, mins, secs));
                    }
                } else {
                    // Времето ИЗТЕЧЕ
                    KillTimer(hwnd, 1);
                    
                    string title, displayMsg;
                    if (isWorking) {
                        title = "Work Done!";
                        displayMsg = "Време е за почивка!";
                        isWorking = false;
                        timeLeftSeconds = (settingsWin !is null) ? settingsWin.lang["rest"].to!int * 60 : 5 * 60;
                    } else {
                        title = "Break Over!";
                        displayMsg = "Време е за работа!";
                        isWorking = true;
                        timeLeftSeconds = (settingsWin !is null) ? settingsWin.lang["work"].to!int * 60 : 25 * 60;
                    }

                    MessageBeep(MB_ICONASTERISK);

                    // Показваме системно съобщение
                    MessageBoxW(null, displayMsg.toUTF16z, title.toUTF16z, 
                                MB_OK | MB_ICONEXCLAMATION | MB_SYSTEMMODAL | MB_SERVICE_NOTIFICATION);

                    // Рестартираме таймера за следващата фаза
                    SetTimer(hwnd, 1, 1000, null);
                }
                return 0;

            case WM_COMMAND:
                // Тук се обработват всички команди от менюта и бутони
                switch (LOWORD(cast(DWORD)wParam)) {
                    
                    case ID_TRAY_PAUSE:
                        isPaused = !isPaused; 
                        auto tray = cast(TrayIcon)cast(void*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
                        
                        if (isPaused) {
                            KillTimer(hwnd, 1); 
                            if (tray) tray.updateTooltip("Timer: Paused");
                        } else {
                            SetTimer(hwnd, 1, 1000, null); 
                            if (tray) tray.updateTooltip("Timer: Resumed...");
                        }
                        return 0;

                    case ID_TRAY_SETTINGS:
                        if (settingsWin is null) settingsWin = new SettingsWindow(hwnd);
                        settingsWin.show();
                        return 0;

                    case ID_TRAY_ABOUT:
                        string aboutText = (settingsWin !is null) ? settingsWin.lang["about_text"] : "D-Pomodoro Timer v1.0";
                        MessageBoxW(hwnd, aboutText.toUTF16z, "About"w.ptr, MB_OK | MB_ICONINFORMATION);
                        return 0;

                    case ID_BTN_SAVE:
                        if (settingsWin !is null) {
                            settingsWin.saveCurrent();
                            isWorking = true;
                            isPaused = false; // Винаги отменяме паузата при нов старт
                            timeLeftSeconds = settingsWin.lang["work"].to!int * 60;
                            SetTimer(hwnd, 1, 1000, null);
                        }
                        return 0;

                    case ID_TRAY_EXIT:
                        PostQuitMessage(0);
                        return 0;
                        
                    default: break;
                }
                break;

            case WM_DESTROY:
                PostQuitMessage(0);
                return 0;

            default: break;
        }
    } catch (Throwable e) {}
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void main() {
    // Инициализация на системните контроли за плъзгачите
    import core.sys.windows.commctrl : InitCommonControls;
    InitCommonControls();

    HINSTANCE hInst = GetModuleHandleW(null);
    string className = "PomodoroHiddenClass";
    
    WNDCLASSW wc;
    wc.lpfnWndProc = &windowProc;
    wc.hInstance = hInst;
    wc.lpszClassName = className.toUTF16z;
    wc.hCursor = LoadCursorW(null, IDC_ARROW);
    
    // Зареждане на иконата на приложението
    wc.hIcon = cast(HICON)LoadImageW(null, "app.ico"w.ptr, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE);
    
    RegisterClassW(&wc);

    // Създаване на невидимия прозорец-майка
    HWND hwnd = CreateWindowExW(
        0, className.toUTF16z, "PomodoroHelper"w.ptr, 
        0, 0, 0, 0, 0, null, null, hInst, null
    );

    if (!hwnd) return;

    // Зареждане на настройките
    settingsWin = new SettingsWindow(hwnd);
    
    try {
        timeLeftSeconds = settingsWin.lang["work"].to!int * 60;
    } catch (Exception) {
        timeLeftSeconds = 25 * 60; 
    }

    // Инициализация на иконата в системния трей
    auto tray = new TrayIcon(hwnd);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, cast(LONG_PTR)cast(void*)tray);

    // Стартираме таймера веднага след пускане
    SetTimer(hwnd, 1, 1000, null);

    // Главният цикъл на Windows
    MSG msg;
    while (GetMessageW(&msg, null, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    tray.remove();
}