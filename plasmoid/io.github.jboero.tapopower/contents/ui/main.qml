import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Plasmoid.configuration reads are undefined for ~250 ms after the applet
    // builds; a NaN Timer interval never fires again, so always fall back.
    function cfgNum(name, fallback) {
        var v = Plasmoid.configuration[name]
        return (typeof v === "number" && isFinite(v)) ? v : fallback
    }
    function cfgStr(name, fallback) {
        var v = Plasmoid.configuration[name]
        return (typeof v === "string" && v.length > 0) ? v : fallback
    }

    readonly property int intervalSec: Math.max(2, cfgNum("intervalSeconds", 5))
    readonly property int historyMinutes: Math.max(1, cfgNum("historyMinutes", 30))
    readonly property int historyCapacity: Math.max(2, Math.round(historyMinutes * 60 / intervalSec))

    // Plug addresses, one per line or separated by commas. Anything that is not
    // a plain address is dropped, because each host goes into a shell command line.
    readonly property var hosts: {
        var seen = []
        cfgStr("hosts", "192.168.1.81").split(/[\s,;]+/).forEach(h => {
            if (/^[A-Za-z0-9.:-]+$/.test(h) && seen.indexOf(h) < 0)
                seen.push(h)
        })
        return seen
    }

    // Latest result per host, written by each device card's poll:
    // {watts, todayWh, monthWh, error}. Watts is NaN while that plug is failing.
    property var readings: ({})
    function setReading(host, watts, todayWh, monthWh, error) {
        var m = Object.assign({}, root.readings)
        m[host] = { watts: watts, todayWh: todayWh, monthWh: monthWh, error: error }
        root.readings = m
    }

    // Plugs that have reported a good reading, and the sums over them.
    readonly property var live: hosts.map(h => readings[h]).filter(r => r !== undefined && !isNaN(r.watts))
    readonly property int okCount: live.length
    readonly property int deviceCount: hosts.length
    readonly property real totalW: okCount ? live.reduce((a, r) => a + r.watts, 0) : NaN
    readonly property real totalTodayWh: live.reduce((a, r) => a + (r.todayWh || 0), 0)
    readonly property string firstError: {
        var failing = hosts.map(h => readings[h]).filter(r => r !== undefined && r.error)
        return failing.length ? failing[0].error : ""
    }
    readonly property bool faulted: deviceCount > 0 && okCount === 0
    readonly property bool dim: okCount < deviceCount

    // History of the total, sampled once per interval.
    readonly property var totalHistory: totalSeries
    PowerHistory {
        id: totalSeries
        capacity: root.historyCapacity
    }
    Timer {
        interval: root.intervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: totalSeries.record(root.totalW)
    }

    function fmtWindow(min) { return min >= 60 && min % 60 === 0 ? i18n("%1 h", min / 60) : i18n("%1 min", min) }
    function fmtW(w) { return isNaN(w) ? "—" : (w >= 100 ? Math.round(w) : w.toFixed(1)) + " W" }
    function fmtKWh(wh) { return (wh === undefined || wh === null) ? "—" : (wh / 1000).toFixed(2) + " kWh" }

    readonly property string panelText: fmtW(totalW)
    // Tray badge: whole watts with a unit glued on, so it is never a bare number.
    readonly property string wattBadge: okCount ? Math.round(totalW) + "W" : ""
    // Stock Breeze icon (bolt over a graph): a themed name always resolves,
    // where a file URL fell back to the generic document icon in the tray.
    readonly property string iconName: "utilities-energy-monitor"

    Plasmoid.icon: iconName
    Plasmoid.status: PlasmaCore.Types.PassiveStatus
    toolTipMainText: okCount ? i18n("Total: %1", fmtW(totalW)) : i18n("Tapo Power")
    toolTipSubText: {
        if (deviceCount === 0)
            return i18n("No plugs configured")
        var lines = []
        if (okCount)
            lines.push(i18n("Used today: %1", fmtKWh(totalTodayWh)))
        if (okCount < deviceCount)
            lines.push(i18n("%1 of %2 plugs reporting", okCount, deviceCount))
        if (firstError)
            lines.push(firstError)
        return lines.join("\n")
    }

    compactRepresentation: CompactRepresentation {}

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24
        spacing: Kirigami.Units.smallSpacing

        // ---- header: the total over every plug
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: i18n("All plugs")
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: root.panelText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                font.bold: true
                opacity: root.dim ? 0.5 : 1.0
            }
        }

        PowerGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
            samples: totalSeries.samples
            capacity: root.historyCapacity
            yFrom: 0
            yTo: totalSeries.yTo
            windowLabel: root.fmtWindow(root.historyMinutes)

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: totalSeries.samples.length < 2
                text: root.firstError ? "" : i18n("Collecting readings…")
                opacity: 0.6
            }
        }

        // Window statistics for the total: what "trends and spikes" means in numbers.
        RowLayout {
            Layout.fillWidth: true
            visible: totalSeries.samples.length > 0
            spacing: Kirigami.Units.largeSpacing
            PlasmaComponents.Label { text: i18n("Low %1", root.fmtW(totalSeries.minW)); opacity: 0.8 }
            PlasmaComponents.Label { text: i18n("Average %1", root.fmtW(totalSeries.avgW)); opacity: 0.8 }
            PlasmaComponents.Label {
                text: i18n("Peak %1 at %2", root.fmtW(totalSeries.maxW),
                           Qt.formatTime(new Date(totalSeries.peakAtMs), "hh:mm:ss"))
                opacity: 0.8
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                visible: root.okCount > 0
                text: i18n("Today: %1", root.fmtKWh(root.totalTodayWh))
                opacity: 0.8
            }
        }

        // ---- the plugs, one card each, scrolling when they do not all fit
        QQC2.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: list
                width: scroll.availableWidth
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.hosts

                    delegate: DeviceCard {
                        Layout.fillWidth: true
                        host: modelData
                        intervalSec: root.intervalSec
                        historyCapacity: root.historyCapacity
                        onReported: (watts, todayWh, monthWh, error) =>
                            root.setReading(modelData, watts, todayWh, monthWh, error)
                    }
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.deviceCount === 0
            text: i18n("No plug addresses configured. Add them in the widget settings.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
    }
}
