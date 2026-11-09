/*
 * Polls one plug and keeps its history. Pollers live on the applet itself
 * rather than in the popup, which Plasma only builds once it is first opened,
 * so the panel reading updates from the start.
 */
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: poller

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

    readonly property bool stale: reading !== null && (Date.now() - lastOkMs) > intervalSec * 3000
    readonly property string title: reading && reading.name ? reading.name : host
    readonly property string subtitle: [reading ? reading.model : "", host].filter(s => s).join(" · ")

    readonly property PowerHistory history: PowerHistory {
        capacity: poller.historyCapacity
    }

    function fail(msg) {
        poller.lastError = msg
        poller.reported(NaN, null, null, msg)
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
            poller.polling = false
            var out = (data["stdout"] || "").trim()
            var j
            try {
                j = JSON.parse(out)
            } catch (e) {
                poller.fail(out || (data["stderr"] || "").trim() || i18n("tapo-power produced no output"))
                return
            }
            if (j.ok) {
                poller.reading = j
                poller.lastOkMs = Date.now()
                poller.lastError = ""
                poller.history.record(j.watts)
                poller.reported(j.watts, j.today_wh, j.month_wh, "")
            } else {
                poller.fail(j.error || i18n("unknown error"))
            }
        }
    }

    Timer {
        interval: poller.intervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.poll()
    }
}
