import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var report: null
  property bool refreshPending: false
  readonly property string city: String(setting("city", ""))
  readonly property string region: String(setting("region", ""))
  readonly property real latitude: Number(setting("latitude", 0))
  readonly property real longitude: Number(setting("longitude", 0))
  readonly property string locationLabel: (city + (region ? ", " + region : "")).toUpperCase()
  readonly property var current: report ? report.current : null
  readonly property var forecastDays: report ? report.daily.time.slice(1, 4) : []
  readonly property string reportTempNum: current ? String(Math.round(current.temperature_2m)) : ""
  readonly property string reportTempSecondary: current ? Math.round(current.temperature_2m * 9 / 5 + 32) + "°F" : ""
  readonly property string reportFeels: current ? Math.round(current.apparent_temperature) + "°C" : ""
  readonly property string reportWind: current ? Math.round(current.wind_speed_10m) + " km/h" : ""
  readonly property string reportHumidity: current ? current.relative_humidity_2m + "%" : ""

  function weatherIcon(code) {
    var c = Number(code)
    if (c === 0) return ""
    if (c === 1 || c === 2) return ""
    if (c === 3) return ""
    if (c === 45 || c === 48) return ""
    if (c >= 51 && c <= 57) return ""
    if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return ""
    if ((c >= 71 && c <= 77) || (c >= 85 && c <= 86)) return ""
    if (c >= 95) return ""
    return ""
  }

  function dayName(date) { return Qt.formatDate(new Date(date + "T12:00:00"), "dddd") }
  function rangeC(index) { return Math.round(report.daily.temperature_2m_min[index + 1]) + "–" + Math.round(report.daily.temperature_2m_max[index + 1]) + "°C" }
  function rangeF(index) { return Math.round(report.daily.temperature_2m_min[index + 1] * 9 / 5 + 32) + "–" + Math.round(report.daily.temperature_2m_max[index + 1] * 9 / 5 + 32) + "°F" }
  function refresh() {
    if (forecastProc.running) {
      refreshPending = true
      forecastProc.running = false
    } else {
      refreshPending = false
      forecastProc.running = true
    }
  }
  Component.onCompleted: refresh()
  onSettingsChanged: {
    // The bar injects city settings after construction. Wait until the
    // fallback request has stopped, then reload using these coordinates.
    root.refresh()
  }
  Timer { interval: 600000; running: true; repeat: true; onTriggered: root.refresh() }
  Timer {
    interval: 50
    running: root.refreshPending
    repeat: true
    onTriggered: {
      if (!forecastProc.running) {
        root.refreshPending = false
        forecastProc.running = true
      }
    }
  }

  Process {
    id: forecastProc
    command: ["curl", "-fsS", "--max-time", "8", "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&temperature_unit=celsius&wind_speed_unit=kmh&forecast_days=4&timezone=auto"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { var data = JSON.parse(String(text || "")); if (data.current && data.daily) root.report = data } catch (error) {} } }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(weatherColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(text) { if (text === "r") root.refresh() }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: weatherColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: weatherColumn
          width: parent.width
          spacing: Style.space(14)

          Item {
            width: parent.width
            height: Math.max(heroLeft.height, heroRight.height)

            Row {
              id: heroLeft
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(16)
              Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 5; text: root.current ? root.weatherIcon(root.current.weather_code) : "—"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: 64 }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Row {
                  spacing: Style.space(2)
                  Text { id: tempBig; text: root.reportTempNum || "—"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: 56; font.bold: true }
                  Text { text: root.current ? "°C" : ""; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.display; anchors.top: tempBig.top; anchors.topMargin: Style.space(10) }
                }
                Text { visible: !!root.current; text: root.reportTempSecondary; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.title }
              }
            }

            Column {
              id: heroRight
              width: weatherStats.implicitWidth
              anchors.right: parent.right
              anchors.rightMargin: Style.space(20)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(12)
              Row {
                spacing: Style.space(6)
                Text { text: ""; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.locationLabel; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
              }
              Row {
                id: weatherStats
                visible: !!root.current
                spacing: Style.space(36)
                Column { spacing: Style.space(5); Text { text: "FEELS"; color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 } Text { text: root.reportFeels; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title } }
                Column { spacing: Style.space(5); Text { text: "WIND"; color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 } Text { text: root.reportWind; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title } }
                Column { spacing: Style.space(5); Text { text: "HUMID"; color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 } Text { text: root.reportHumidity; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title } }
              }
            }
          }

          Text { visible: !root.current; text: "Fetching forecast…"; color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.italic: true }
          Rectangle { visible: root.forecastDays.length > 0; width: parent.width; height: Style.spacing.hairline; color: root.bar.foreground; opacity: 0.12 }
          Item {
            visible: root.forecastDays.length > 0
            width: parent.width
            height: forecastRow.height
            Row {
              id: forecastRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(44)
              Repeater {
                model: root.forecastDays
                Row {
                  spacing: Style.space(10)
                  Text { anchors.verticalCenter: parent.verticalCenter; text: root.weatherIcon(root.report.daily.weather_code[index + 1]); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.display }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)
                    Text { text: root.dayName(modelData).toUpperCase(); color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                    Column {
                      spacing: 0
                      Text { text: root.rangeC(index); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
                      Text { text: root.rangeF(index); color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
