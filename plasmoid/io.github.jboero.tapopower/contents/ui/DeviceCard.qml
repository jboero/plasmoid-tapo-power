/*
 * One plug in the device list: its own poll loop, history and sparkline.
 * Every poll is reported up to the applet, which totals the plugs for the header.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    property string host: ""
    property int intervalSec: 5
    property int historyCapacity: 360

    // watts is NaN and error is set when the poll failed.
    signal reported(real watts, var todayWh, var monthWh, string error)

    property var reading: null      // last good JSON from tapo-power
    property string lastError: ""
    property double lastOkMs: 0
    property bool polling: false
    property int pollSerial: 0

    readonly property real outletW: reading ? reading.watts : NaN
    readonly property bool stale: reading !== null && (Date.now() - lastOkMs) > intervalSec * 3000
    readonly property string title: reading && reading.name ? reading.name : host
    readonly property string subtitle: [reading ? reading.model : "", host].filter(s => s).join(" · ")

    PowerHistory {
        id: history
        capacity: card.historyCapacity
    }

    function fmtW(w) { return isNaN(w) ? "—" : (w >= 100 ? Math.round(w) : w.toFixed(1)) + " W" }
    function fmtKWh(wh) { return (wh === undefined || wh === null) ? "—" : (wh / 1000).toFixed(2) + " kWh" }

    function fail(msg) {
        card.lastError = msg
        card.reported(NaN, null, null, msg)
    }

    // The host goes into a shell command line; the applet only passes hosts
    // that are plain address characters.
    function poll() {
        if (polling)
            return
        polling = true
        pollSerial += 1
        // A unique trailing comment makes every poll a new source; the
        // executable engine will not re-run a source string it already ran.
        exec.connectSource("\"$HOME/bin/tapo-power\" " + host + " # " + pollSerial)
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            card.polling = false
            var out = (data["stdout"] || "").trim()
            var j
            try {
                j = JSON.parse(out)
            } catch (e) {
                card.fail(out || (data["stderr"] || "").trim() || i18n("tapo-power produced no output"))
                return
            }
            if (j.ok) {
                card.reading = j
                card.lastOkMs = Date.now()
                card.lastError = ""
                history.record(j.watts)
                card.reported(j.watts, j.today_wh, j.month_wh, "")
            } else {
                card.fail(j.error || i18n("unknown error"))
            }
        }
    }

    Timer {
        interval: card.intervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: card.poll()
    }

    implicitHeight: content.implicitHeight + 2 * Kirigami.Units.largeSpacing
    color: Kirigami.Theme.alternateBackgroundColor
    radius: Kirigami.Units.smallSpacing

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.title
                    font.bold: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.subtitle
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }
            PlasmaComponents.Label {
                text: card.fmtW(card.outletW)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                font.bold: true
                opacity: (card.stale || card.lastError !== "") ? 0.5 : 1.0
            }
        }

        PowerGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
            showAxes: false
            samples: history.samples
            capacity: card.historyCapacity
            yFrom: 0
            yTo: history.yTo
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: i18n("Today: %1", card.fmtKWh(card.reading ? card.reading.today_wh : undefined))
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: i18n("Month: %1", card.fmtKWh(card.reading ? card.reading.month_wh : undefined))
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: card.lastError !== ""
            text: card.lastError
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
            font: Kirigami.Theme.smallFont
        }
    }
}
