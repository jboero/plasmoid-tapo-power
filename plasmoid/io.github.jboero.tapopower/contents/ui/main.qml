import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Last good JSON from tapo-power. Not named "state": Item.state is FINAL.
    property var reading: null
    property string lastError: ""
    property double lastOkMs: 0
    property bool polling: false
    property int pollSerial: 0

    // Plasmoid.configuration reads are undefined for ~250 ms after the applet
    // builds; a NaN Timer interval never fires again, so always fall back.
    function cfgNum(name, fallback) {
        var v = Plasmoid.configuration[name]
        return (typeof v === "number" && isFinite(v)) ? v : fallback
    }
    function cfgBool(name, fallback) {
        var v = Plasmoid.configuration[name]
        return (typeof v === "boolean") ? v : fallback
    }
    function cfgStr(name, fallback) {
        var v = Plasmoid.configuration[name]
        return (typeof v === "string" && v.length > 0) ? v : fallback
    }

    readonly property int intervalSec: Math.max(2, cfgNum("intervalSeconds", 5))

    readonly property bool stale: reading !== null && (Date.now() - lastOkMs) > intervalSec * 3000
    readonly property real outletW: reading ? reading.watts : NaN

    // ---- history for the graph: outlet watts, newest first
    readonly property int historyMinutes: Math.max(1, cfgNum("historyMinutes", 30))
    readonly property int historyCapacity: Math.max(2, Math.round(historyMinutes * 60 / intervalSec))
    property var samples: []
    property var sampleTimes: []
    readonly property real histMin: samples.length ? Math.min.apply(null, samples) : NaN
    readonly property real histMax: samples.length ? Math.max.apply(null, samples) : NaN
    readonly property real histAvg: samples.length ? samples.reduce((a, b) => a + b, 0) / samples.length : NaN
    readonly property double peakAtMs: (samples.length && sampleTimes[samples.indexOf(histMax)]) || 0
    // Y axis always starts at zero so the trace keeps its true proportion; the
    // top is the window's peak plus some headroom, rounded up to a tidy step.
    readonly property real yStep: isNaN(histMax) || histMax <= 100 ? 20 : (histMax <= 500 ? 100 : 250)
    readonly property real graphFrom: 0
    readonly property real graphTo: isNaN(histMax) ? 100 : Math.ceil(histMax * 1.1 / yStep) * yStep

    function fmtWindow(min) { return min >= 60 && min % 60 === 0 ? i18n("%1 h", min / 60) : i18n("%1 min", min) }

    function record(w) {
        // Times first: bindings on `samples` look the matching time up.
        root.sampleTimes = [Date.now()].concat(root.sampleTimes).slice(0, root.historyCapacity)
        root.samples = [w].concat(root.samples).slice(0, root.historyCapacity)
    }

    function fmtW(w) { return isNaN(w) ? "—" : (w >= 100 ? Math.round(w) : w.toFixed(1)) + " W" }
    function fmtKWh(wh) { return (wh === undefined || wh === null) ? "—" : (wh / 1000).toFixed(2) + " kWh" }

    readonly property string panelText: fmtW(outletW)
    // Tray badge: whole watts with a unit glued on, so it is never a bare number.
    readonly property string wattBadge: {
        return isNaN(outletW) ? "" : Math.round(outletW) + "W"
    }
    // Stock Breeze icon (bolt over a graph): a themed name always resolves,
    // where a file URL fell back to the generic document icon in the tray.
    readonly property string iconName: "utilities-energy-monitor"

    Plasmoid.icon: iconName
    Plasmoid.status: PlasmaCore.Types.PassiveStatus
    toolTipMainText: reading ? i18n("Outlet: %1", fmtW(outletW)) : i18n("Tapo Power")
    toolTipSubText: {
        if (!reading)
            return lastError || i18n("Waiting for the first reading…")
        var lines = [i18n("Used today: %1", fmtKWh(reading.today_wh))]
        if (lastError)
            lines.push(i18n("Last poll failed: %1", lastError))
        else if (stale)
            lines.push(i18n("Reading is stale"))
        return lines.join("\n")
    }

    // The host goes into a shell command line, so allow only address characters.
    function safeHost() {
        var h = cfgStr("host", "192.168.1.81")
        return /^[A-Za-z0-9.:-]+$/.test(h) ? h : "192.168.1.81"
    }

    function poll() {
        if (polling)
            return
        polling = true
        pollSerial += 1
        // A unique trailing comment makes every poll a new source; the
        // executable engine will not re-run a source string it already ran.
        exec.connectSource("\"$HOME/bin/tapo-power\" " + safeHost() + " # " + pollSerial)
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            root.polling = false
            var out = (data["stdout"] || "").trim()
            var j
            try {
                j = JSON.parse(out)
            } catch (e) {
                root.lastError = out || (data["stderr"] || "").trim() || i18n("tapo-power produced no output")
                return
            }
            if (j.ok) {
                root.reading = j
                root.lastOkMs = Date.now()
                root.lastError = ""
                root.record(root.outletW)
            } else {
                root.lastError = j.error || i18n("unknown error")
            }
        }
    }

    Timer {
        interval: root.intervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    compactRepresentation: CompactRepresentation {}

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: i18n("Outlet total")
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: root.panelText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                font.bold: true
                opacity: (root.stale || root.lastError) ? 0.5 : 1.0
            }
        }

        PowerGraph {
            Layout.fillWidth: true
            Layout.fillHeight: true
            samples: root.samples
            capacity: root.historyCapacity
            yFrom: root.graphFrom
            yTo: root.graphTo
            windowLabel: root.fmtWindow(root.historyMinutes)

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: root.samples.length < 2
                text: root.lastError ? "" : i18n("Collecting readings…")
                opacity: 0.6
            }
        }

        // Window statistics: what "trends and spikes" means in numbers.
        RowLayout {
            Layout.fillWidth: true
            visible: root.samples.length > 0
            spacing: Kirigami.Units.largeSpacing
            PlasmaComponents.Label { text: i18n("Low %1", root.fmtW(root.histMin)); opacity: 0.8 }
            PlasmaComponents.Label { text: i18n("Average %1", root.fmtW(root.histAvg)); opacity: 0.8 }
            PlasmaComponents.Label {
                text: i18n("Peak %1 at %2", root.fmtW(root.histMax),
                           Qt.formatTime(new Date(root.peakAtMs), "hh:mm:ss"))
                opacity: 0.8
            }
        }

        GridLayout {
            columns: 4
            columnSpacing: Kirigami.Units.largeSpacing
            visible: root.reading !== null

            PlasmaComponents.Label { text: i18n("Used today:"); opacity: 0.7 }
            PlasmaComponents.Label { text: root.reading ? root.fmtKWh(root.reading.today_wh) : "—" }

            PlasmaComponents.Label { text: i18n("Used this month:"); opacity: 0.7 }
            PlasmaComponents.Label { text: root.reading ? root.fmtKWh(root.reading.month_wh) : "—" }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.reading !== null
            text: root.reading ? [root.reading.name, root.reading.model, root.reading.host].filter(s => s).join(" · ") : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.6
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.lastError !== ""
            text: root.lastError
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }
    }
}
