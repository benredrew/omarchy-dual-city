import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// One city's readout inside the Dual City widget: name, weather glyph,
// temperature and local time. The host widget places two of these around
// the date and owns which popup is open.
Item {
  id: root
  property var bar: null
  property var host: null
  property var cityConfig: ({})
  property var reading: null
  property bool refreshPending: false
  property bool timeRefreshPending: false
  property string cityDate: ""
  property string cityTime: ""
  // Whole days this city is ahead of (+) or behind (-) the local date shown
  // in the middle, marked like a flight itinerary: 01:00⁺¹.
  property int dayOffset: 0
  // The east readout is mirrored — time · weather · city — so both cities'
  // times sit next to the date.
  property bool mirror: false
  readonly property string city: String(cfg("city", ""))
  readonly property string timezone: String(cfg("timezone", "UTC"))
  readonly property real latitude: Number(cfg("latitude", 0))
  readonly property real longitude: Number(cfg("longitude", 0))
  readonly property var panel: panelLoader.item
  // Width of the visible readout, for the host's open-panel underline.
  readonly property real contentWidth: weatherRow.implicitWidth

  signal activated()

  function cfg(name, fallback) {
    var value = cityConfig ? cityConfig[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function icon() {
    if (!reading) return "?"
    var night = Number(reading.is_day) === 0
    var code = Number(reading.weather_code)
    if (code === 0) return night ? "" : ""
    if (code === 1 || code === 2) return night ? "" : ""
    if (code === 3) return ""
    if (code === 45 || code === 48) return night ? "\ue346" : "\ue313"
    if (code >= 51 && code <= 61) return night ? "" : ""
    if ((code >= 63 && code <= 67) || (code >= 80 && code <= 82)) return ""
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return ""
    if (code >= 95) return ""
    return ""
  }

  readonly property string detailsLabel: {
    if (!reading) return "—"
    var celsius = Math.round(Number(reading.temperature_2m))
    var temps = celsius + "°C/" + Math.round(celsius * 9 / 5 + 32) + "°F"
    if (!root.cityTime) return temps
    var time = root.cityTime + root.offsetMark()
    return root.mirror ? time + " · " + temps : temps + " · " + time
  }

  function offsetMark() {
    if (root.dayOffset === 0) return ""
    var digits = "⁰¹²³⁴⁵⁶⁷⁸⁹"
    var n = String(Math.abs(root.dayOffset)).split("").map(function(d) { return digits[Number(d)] }).join("")
    return (root.dayOffset > 0 ? "⁺" : "⁻") + n
  }

  function refresh() {
    if (weatherProc.running) {
      refreshPending = true
      weatherProc.running = false
    } else {
      refreshPending = false
      weatherProc.running = true
    }
  }
  function refreshTime() {
    if (timeProc.running) {
      timeRefreshPending = true
      timeProc.running = false
    } else {
      timeRefreshPending = false
      timeProc.running = true
    }
  }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.cityConfig
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root.host
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Component.onCompleted: { refresh(); refreshTime() }
  onBarChanged: injectPanel()
  onHostChanged: injectPanel()
  onCityConfigChanged: {
    root.injectPanel()
    // The readout starts before the bar injects this entry's settings.
    // refresh() waits for a cancelled fallback request to fully stop before
    // starting this city's request with its own coordinates.
    root.refresh()
    root.refreshTime()
  }

  Timer { interval: 600000; running: true; repeat: true; onTriggered: root.refresh() }
  Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refreshTime() }
  Timer {
    interval: 50
    running: root.refreshPending
    repeat: true
    onTriggered: {
      if (!weatherProc.running) {
        root.refreshPending = false
        weatherProc.running = true
      }
    }
  }
  Timer {
    interval: 50
    running: root.timeRefreshPending
    repeat: true
    onTriggered: {
      if (!timeProc.running) {
        root.timeRefreshPending = false
        timeProc.running = true
      }
    }
  }

  Process {
    id: weatherProc
    command: ["curl", "-fsS", "--max-time", "8", "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,weather_code,is_day&temperature_unit=celsius&forecast_days=1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { var report = JSON.parse(String(text || "")); if (report.current) root.reading = report.current } catch (error) {}
      }
    }
  }

  Process {
    id: timeProc
    command: ["env", "TZ=" + root.timezone, "date", "+%Y-%m-%d|%H:%M"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var fields = String(text || "").trim().split("|")
        if (fields.length === 2) {
          root.cityDate = fields[0]
          root.cityTime = fields[1]
          var localDate = Qt.formatDate(new Date(), "yyyy-MM-dd")
          root.dayOffset = Math.round((Date.parse(fields[0]) - Date.parse(localDate)) / 86400000)
        }
      }
    }
  }

  Loader {
    id: panelLoader
    source: Qt.resolvedUrl("WeatherPanel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 7
    fixedWidth: weatherRow.implicitWidth + scaledHorizontalMargin * 2
    tooltipText: ""
    onPressed: function(button) {
      if (button === Qt.MiddleButton) root.refresh()
      else root.activated()
    }

    Row {
      id: weatherRow
      anchors.centerIn: parent
      spacing: Style.space(4)
      layoutDirection: root.mirror ? Qt.RightToLeft : Qt.LeftToRight

      Text {
        text: root.city
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        anchors.verticalCenter: parent.verticalCenter

        OpticalGlyph {
          anchors.fill: parent
          text: root.icon()
          fontFamily: button.fontFamily
          fontSize: Style.bar.iconFont
          color: button.foreground
        }
      }

      Text {
        text: root.detailsLabel
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
