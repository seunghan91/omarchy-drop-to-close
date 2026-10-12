import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Trash tile shown only while a window is being dragged. It draws and never
// takes input. All decisions (is the cursor over the tile, should the drop
// close the window) live in the Hyprland Lua half (hypr/drop_to_close.lua);
// this side only receives the geometry and hover state over IPC, so what is
// drawn and what is hit-tested can never drift apart.
Item {
  id: root

  property bool opened: false
  property bool hovered: false
  property string monitorName: ""
  // Monitor-local logical pixels, computed by the Lua half for the
  // monitor's resolution, aspect ratio, and scale.
  property real zoneX: 0
  property real zoneY: 0
  property real zoneSize: 64

  function open(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      monitorName = p.monitor || ""
      zoneX = Number(p.x) || 0
      zoneY = Number(p.y) || 0
      zoneSize = Number(p.size) || 64
      hovered = p.hover === true
    } catch (e) {}
    opened = true
  }

  function close() {
    opened = false
    hovered = false
  }

  function setHover(value) {
    hovered = value === true || value === "true"
    return "ok"
  }

  PanelWindow {
    visible: root.opened
    screen: {
      var screens = Quickshell.screens
      for (var i = 0; i < screens.length; i++)
        if (screens[i].name === root.monitorName) return screens[i]
      return null
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "drop-to-close"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only surface: an empty input region never intercepts the drag.
    mask: Region {}

    Rectangle {
      id: bin
      x: root.zoneX
      y: root.zoneY
      width: root.zoneSize
      height: root.zoneSize
      radius: Math.max(Style.cornerRadius, root.zoneSize * 0.22)
      color: root.hovered ? Util.alpha(Color.urgent, 0.92) : Util.alpha(Color.background, 0.88)
      border.width: Math.max(1, Math.round(root.zoneSize / 32))
      border.color: root.hovered ? Color.urgent : Util.alpha(Color.popups.border, 0.9)
      scale: root.hovered ? 1.15 : 1.0
      transformOrigin: Item.Bottom

      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: ""
        font.family: Style.font.family
        font.pixelSize: Math.round(root.zoneSize * 0.48)
        color: root.hovered ? Color.background : Color.popups.text
      }
    }
  }
}
