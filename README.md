# D-Pomodoro Timer

A lightweight, distraction-free Pomodoro timer built with the **D Programming Language** using the native **Windows API**. This application is designed specifically for **Windows** and runs efficiently in the system tray.

## Features
- **Native Windows Integration:** Low resource usage and no extra dependencies.
- **System Tray Icon:** Displays real-time countdown when hovering.
- **Customizable Intervals:** Set your own work and break durations via an INI file.
- **Smart Notifications:** System-modal alerts ensure you never miss a break.
- **Quick Controls:** Left-click for Settings, Right-click for Pause/Resume and Menu.
- **Localization:** Support for custom fonts and UI text via configuration.

## Installation & Usage

### For Users
1. Download the latest release ZIP from the Releases section.
2. Extract all files (`d-pomodoro.exe`, `app.ico`, and `dp_settings.ini`) into a folder.
3. Run `d-pomodoro.exe`.

### For Developers
To build from source, you need the DMD compiler and DUB package manager.
1. Clone the repository.
2. Run the following command to build the production version:
```bash
dub build -b release --compiler=dmd
```

## Configuration

The application uses dp_settings.ini to store preferences:
- **work:** Work duration in minutes.
- **rest:** Break duration in minutes.
- **font_size:** UI text size adjustment.
- **lang:** UI localization strings.

## License

This project is licensed under the MIT License.


---

**Developed with D and Win32 API**

---

