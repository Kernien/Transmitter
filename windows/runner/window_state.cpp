#include "window_state.h"

namespace window_state {

namespace {

constexpr const wchar_t kKey[] = L"Software\\Transmitter";
constexpr const wchar_t kValue[] = L"WindowPlacement";

}  // namespace

bool Restore(HWND window) {
  WINDOWPLACEMENT placement{};
  DWORD size = sizeof(placement);
  if (::RegGetValueW(HKEY_CURRENT_USER, kKey, kValue, RRF_RT_REG_BINARY,
                     nullptr, &placement, &size) != ERROR_SUCCESS ||
      size != sizeof(placement) || placement.length != sizeof(placement)) {
    return false;
  }
  if (::MonitorFromRect(&placement.rcNormalPosition, MONITOR_DEFAULTTONULL) ==
      nullptr) {
    return false;
  }
  const bool maximized = placement.showCmd == SW_SHOWMAXIMIZED;
  // Окно покажется после первого кадра Flutter (см. FlutterWindow::OnCreate).
  placement.showCmd = SW_HIDE;
  placement.flags = 0;
  ::SetWindowPlacement(window, &placement);
  return maximized;
}

void Save(HWND window) {
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!::GetWindowPlacement(window, &placement)) return;
  // Свёрнутым окно не открываем — только обычным или развёрнутым.
  if (placement.showCmd != SW_SHOWMAXIMIZED) placement.showCmd = SW_SHOWNORMAL;
  ::RegSetKeyValueW(HKEY_CURRENT_USER, kKey, kValue, REG_BINARY, &placement,
                    sizeof(placement));
}

}  // namespace window_state
