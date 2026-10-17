#ifndef RUNNER_WINDOW_STATE_H_
#define RUNNER_WINDOW_STATE_H_

#include <windows.h>

// Положение, размер и развёрнутость окна между запусками — в реестре
// текущего пользователя (HKCU\Software\Transmitter).
namespace window_state {

// Ставит окну сохранённые положение и размер (окно остаётся скрытым).
// Возвращает true, если окно нужно показать развёрнутым на весь экран.
// Если сохранённое место не видно ни на одном мониторе (например, отключили
// второй монитор), окно остаётся на стандартном месте.
bool Restore(HWND window);

// Запоминает текущие положение, размер и развёрнутость окна.
void Save(HWND window);

}  // namespace window_state

#endif  // RUNNER_WINDOW_STATE_H_
