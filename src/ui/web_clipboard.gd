class_name WebClipboard
extends Node

## Let a real browser paste update Godot's cache before its native text-edit action.
const INSTALL: String = """
(() => {
    if (window.__ssokWebClipboard) return false;
    let pending = null;
    const canvas = document.getElementById('canvas');
    if (!canvas) return false;
    const isGodotTarget = target => target === canvas ||
        (target instanceof HTMLElement && target.classList.contains('ime') &&
         target.isContentEditable && target.parentElement === canvas.parentElement);
    const onKey = event => {
        if (!event.isTrusted || event.code !== 'KeyV' || event.altKey ||
            !(event.ctrlKey || event.metaKey) || !isGodotTarget(event.target)) return;
        pending = {target: event.target, ctrlKey: event.ctrlKey, metaKey: event.metaKey};
        event.stopImmediatePropagation();
    };
    const onPaste = event => {
        if (!event.isTrusted || !pending || !isGodotTarget(event.target)) return;
        const input = pending;
        pending = null;
        if (!input.target.isConnected || input.target !== event.target) return;
        input.target.dispatchEvent(new KeyboardEvent('keydown', {
            key: 'v', code: 'KeyV', ctrlKey: input.ctrlKey, metaKey: input.metaKey,
            bubbles: true, cancelable: true, composed: true
        }));
        event.preventDefault();
    };
    const clearPending = () => { pending = null; };
    window.addEventListener('keydown', onKey, true);
    window.addEventListener('paste', onPaste);
    window.addEventListener('blur', clearPending);
    window.__ssokWebClipboard = {
        dispose() {
            window.removeEventListener('keydown', onKey, true);
            window.removeEventListener('paste', onPaste);
            window.removeEventListener('blur', clearPending);
            pending = null;
            delete window.__ssokWebClipboard;
        }
    };
    return true;
})();
"""
const DISPOSE: String = "if (window.__ssokWebClipboard) window.__ssokWebClipboard.dispose();"
var _installed: bool = false


func _ready() -> void:
	if OS.has_feature("web"):
		_installed = bool(JavaScriptBridge.eval(INSTALL, true))


func _exit_tree() -> void:
	if _installed:
		JavaScriptBridge.eval(DISPOSE, true)
		_installed = false
