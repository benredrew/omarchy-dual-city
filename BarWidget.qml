import QtQuick
import qs.Commons
import qs.Ui

// Two cities around the local date, ordered west to east like a flight
// itinerary: each city shows its own time, marked ⁺¹/⁻¹ when it is on a
// different date from the one in the middle.
//
//   New York City ☀ 18°C/64°F · 21:30   Sun, October 04   02:30⁺¹ · 12°C/54°F ☾ London
BarWidget {
  id: root
  moduleName: "benredrew.dual-city"

  readonly property var defaultCities: [
    { city: "New York City", region: "NY", latitude: 40.71427, longitude: -74.00597, timezone: "America/New_York" },
    { city: "London", region: "GB", latitude: 51.50853, longitude: -0.12574, timezone: "Europe/London" }
  ]
  // West to east by longitude, never wrapping across the date line, so the
  // order in shell.json does not matter.
  readonly property var cities: {
    var list = setting("cities", null)
    var picked = []
    if (list && list.length >= 2) picked = [list[0], list[1]]
    else picked = defaultCities.slice()
    return picked.sort(function(a, b) { return Number(a.longitude) - Number(b.longitude) })
  }
  readonly property real sideWidth: Math.max(west.implicitWidth, east.implicitWidth)
  readonly property string dateFormat: String(setting("dateFormat", "ddd, MMMM dd"))
  property date now: new Date()
  readonly property string today: Qt.formatDate(now, dateFormat)

  // Index 0 is the west city, 1 the calendar, 2 the east city.
  readonly property var panels: [west.panel, calendarLoader.item, east.panel]
  readonly property int openIndex: {
    for (var i = 0; i < panels.length; i++)
      if (panels[i] && panels[i].opened === true) return i
    return -1
  }
  readonly property bool opened: openIndex >= 0

  function togglePanel(index) {
    var target = panels[index]
    if (!target) return
    if (target.opened) { target.close(); return }
    // The bar knows this widget as a single popout owner, so switching
    // between its own popups is handled here: release first, then open.
    for (var i = 0; i < panels.length; i++)
      if (i !== index && panels[i] && panels[i].opened) panels[i].closeForPopoutSwitch()
    target.open()
  }
  function open() { if (!opened) togglePanel(1) }
  function close() { for (var i = 0; i < panels.length; i++) if (panels[i] && panels[i].opened) panels[i].close() }
  function closeForPopoutSwitch() { for (var i = 0; i < panels.length; i++) if (panels[i] && panels[i].opened) panels[i].closeForPopoutSwitch() }

  function injectCalendar() {
    var target = calendarLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = dateButton
    if ("hostWidget" in target) target.hostWidget = root
    if ("moduleName" in target) target.moduleName = root.moduleName
  }

  // The bar centers one underline on the whole widget; this widget draws its
  // own under whichever part's popup is open, so the bar's is sized to zero.
  readonly property real openPanelIndicatorWidth: 0.01
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  onBarChanged: injectCalendar()
  onSettingsChanged: injectCalendar()

  // Roll the date over shortly after midnight.
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Loader {
    id: calendarLoader
    // Omarchy's stock calendar popup, unchanged.
    source: "file:///usr/share/omarchy/shell/plugins/panels/clock/Panel.qml"
    visible: false
    onLoaded: { root.injectCalendar(); Qt.callLater(root.injectCalendar) }
  }

  Row {
    id: layout
    spacing: Style.space(18)

    // Both sides take the wider city's width so the date stays centered on
    // the bar however long either city's readout is.
    Item {
      id: westSlot
      anchors.verticalCenter: parent.verticalCenter
      width: root.sideWidth
      height: west.implicitHeight

      CityReadout {
        id: west
        anchors.right: parent.right
        bar: root.bar
        host: root
        cityConfig: root.cities[0]
        onActivated: root.togglePanel(0)
      }
    }

    WidgetButton {
      id: dateButton
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      text: root.today
      fontSize: Style.font.body * 1.15
      horizontalMargin: 8.75
      verticalPadding: 8.75
      onPressed: function(mouseButton) { if (mouseButton === Qt.LeftButton) root.togglePanel(1) }
    }

    Item {
      id: eastSlot
      anchors.verticalCenter: parent.verticalCenter
      width: root.sideWidth
      height: east.implicitHeight

      CityReadout {
        id: east
        anchors.left: parent.left
        bar: root.bar
        host: root
        mirror: true
        cityConfig: root.cities[1]
        onActivated: root.togglePanel(2)
      }
    }
  }

  Rectangle {
    readonly property var target: root.openIndex === 0 ? west : root.openIndex === 1 ? dateButton : root.openIndex === 2 ? east : null
    readonly property real targetWidth: !target ? 0 : target === dateButton ? dateButton.labelWidth : target.contentWidth
    visible: opacity > 0
    opacity: target ? 0.9 : 0
    color: Color.accent
    height: Style.space(2)
    radius: height / 2
    width: targetWidth
    readonly property real targetLeft: !target ? 0 : target === dateButton ? dateButton.x : target === west ? westSlot.x + west.x : eastSlot.x + east.x
    x: target ? layout.x + targetLeft + Math.round((target.width - width) / 2) : 0
    y: root.bar && root.bar.position === "bottom" ? Style.space(2) : root.height - height - Style.space(2)

    Behavior on opacity {
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
  }
}
