# AutoHotkey 2 Gemini Proofreader

## Что делает скрипт

- Горячая клавиша: `Ctrl+Alt+X`
- Берёт выделенный текст.
- Отправляет его в Google Gemini API с заданным промптом редактора.
- Заменяет выделенный текст отредактированным результатом.

## Настройка

1. Установите AutoHotkey v2.
2. Скопируйте `.env.example` в `.env`.
3. Укажите в `.env` ваш ключ:

```env
GOOGLE_API_KEY=ваш_ключ
```

4. Запустите `editor_hotkey.ahk`.

## Где менять промпт

Изменяйте переменную `EDIT_PROMPT` в файле `editor_hotkey.ahk`.
