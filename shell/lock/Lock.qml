// Session lock (ext-session-lock): every screen shows LockContent until PAM (the system
// "login" stack, like hyprlock/swaylock) accepts the password. If the shell dies while
// locked, Hyprland keeps the screen locked. Lock: `Lock.lock()`; there is no unlock call.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs

Singleton {
    id: root
    property string buffer: "" // typed password, shared by every screen's field
    property string error: ""
    property bool busy: false
    property string pending: "" // handed to PAM when it asks, then cleared
    readonly property bool locked: sessionLock.locked

    function lock(): void {
        buffer = "";
        error = "";
        sessionLock.locked = true;
    }
    function submit(): void {
        if (busy || buffer === "") return;
        busy = true;
        error = "";
        pending = buffer;
        buffer = "";
        if (!pam.start()) { busy = false; pending = ""; error = "can't start PAM"; }
    }

    PamContext {
        id: pam
        onResponseRequiredChanged: if (responseRequired) { respond(root.pending); root.pending = ""; }
        onCompleted: result => {
            root.busy = false;
            root.pending = "";
            if (result === PamResult.Success) sessionLock.locked = false;
            else root.error = messageIsError && message ? message.toLowerCase() : "wrong password";
        }
        onError: e => { root.busy = false; root.pending = ""; root.error = PamError.toString(e).toLowerCase(); }
    }

    WlSessionLock {
        id: sessionLock
        WlSessionLockSurface {
            color: Theme.bg
            LockContent { anchors.fill: parent }
        }
    }
}
