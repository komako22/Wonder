# Architecture

## Selection pipeline

Both desktop clients follow the same state machine:

```text
mouse down -> hide stale bubble -> mouse up -> configurable debounce
  -> query accessible element -> if unavailable, do not trigger
  -> read non-empty selection and bounds
  -> show non-activating bubble -> user click -> call translation API
  -> show result/error in transient glass panel
```

The debounce prevents a bubble from flashing while the selection is still being adjusted. Selection is read only through macOS Accessibility or Windows UI Automation; the app never simulates a keyboard copy shortcut and never mutates the clipboard. The bubble never triggers translation by itself, so simply selecting private text does not send it over the network.

macOS reads `AXSelectedText`, `AXSelectedTextRange`, and `AXBoundsForRange` from the focused or pointer-adjacent accessibility element. Windows reads `TextPattern.GetSelection()` from the pointer-adjacent or focused UI Automation element.

## Security

- Language preferences and the optional free-service contact email are stored locally.
- Translation history is intentionally not persisted in v1.

## Known limitations

- Applications that render text as pixels or do not expose accessibility text cannot be supported without OCR or clipboard simulation. Neither fallback is enabled because it would add screen-recording permissions or mutate the user's clipboard.
- Password and secure-input controls are rejected.
- The Windows executable must be built on Windows because WPF and Windows UI Automation target the Windows Desktop SDK.
- Both apps are unsigned MVP builds. Public distribution requires an Apple Developer ID notarization flow and a Windows code-signing certificate.
