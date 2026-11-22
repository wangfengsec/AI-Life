# Key names and scancodes

`-Key` and `-To` accept the names below (case-insensitive).

## Letters

| Name | Scan | Name | Scan | Name | Scan |
| --- | --- | --- | --- | --- | --- |
| Q | 0x10 | A | 0x1E | Z | 0x2C |
| W | 0x11 | S | 0x1F | X | 0x2D |
| E | 0x12 | D | 0x20 | C | 0x2E |
| R | 0x13 | F | 0x21 | V | 0x2F |
| T | 0x14 | G | 0x22 | B | 0x30 |
| Y | 0x15 | H | 0x23 | N | 0x31 |
| U | 0x16 | J | 0x24 | M | 0x32 |
| I | 0x17 | K | 0x25 | | |
| O | 0x18 | L | 0x26 | | |
| P | 0x19 | | | | |

## Digits and symbols

| Name | Scan | Name | Scan |
| --- | --- | --- | --- |
| 1–9 | 0x02–0x0A | MINUS | 0x0C |
| 0 | 0x0B | EQUAL | 0x0D |
| LBRACKET | 0x1A | RBRACKET | 0x1B |
| SEMICOLON | 0x27 | QUOTE | 0x28 |
| BACKQUOTE | 0x29 | BACKSLASH | 0x2B |
| COMMA | 0x33 | PERIOD | 0x34 |
| SLASH | 0x35 | | |

## Control keys

| Name | Scan | Name | Scan |
| --- | --- | --- | --- |
| ESC | 0x01 | SPACE | 0x39 |
| BACKSPACE | 0x0E | CAPSLOCK | 0x3A |
| TAB | 0x0F | LSHIFT | 0x2A |
| ENTER | 0x1C | RSHIFT | 0x36 |
| LCTRL | 0x1D | LALT | 0x38 |
| RCTRL | 0xE01D | RALT | 0xE038 |
| LWIN | 0xE05B | RWIN | 0xE05C |
| APPS | 0xE05D | | |

## Arrow / navigation (extended)

| Name | Scan | Name | Scan |
| --- | --- | --- | --- |
| UP | 0xE048 | DOWN | 0xE050 |
| LEFT | 0xE04B | RIGHT | 0xE04D |
| HOME | 0xE047 | END | 0xE04F |
| PGUP | 0xE049 | PGDN | 0xE051 |
| INSERT | 0xE052 | DELETE | 0xE053 |

Names starting with `0xE0` are **extended** scancodes (two bytes: `E0 xx`, stored little-endian in the map as `xx E0`).

## Scancode Map binary format

```
DWORD version        = 00 00 00 00
DWORD flags          = 00 00 00 00
DWORD count          = number of entries + 1
DWORD entry[0..n-1]  = (newScancode << 16) | oldScancode
DWORD terminator     = 00 00 00 00
```

Examples:

- Disable left Win key: `00 00 00 00 00 00 00 00 02 00 00 00 00 00 5B E0 00 00 00 00`
- Disable both Win keys: `00 00 00 00 00 00 00 00 03 00 00 00 00 00 5B E0 00 00 5C E0 00 00 00 00`
- Remap Right Ctrl → I: new = 0x0017, old = 0xE01D → entry bytes `17 00 1D E0`

The map lives at:

```
HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout
    Scancode Map   (REG_BINARY)
```

Deleting the value restores the default layout.

## VK codes used by the detector

| Key | VK | Key | VK |
| --- | --- | --- | --- |
| LWIN | 0x5B | RWIN | 0x5C |
| LSHIFT | 0xA0 | RSHIFT | 0xA1 |
| LCTRL | 0xA2 | RCTRL | 0xA3 |
| LALT | 0xA4 | RALT | 0xA5 |
| A–Z | 0x41–0x5A | 0–9 | 0x30–0x39 |
