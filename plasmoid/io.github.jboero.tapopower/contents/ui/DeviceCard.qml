/*
 * One plug in the device list: its reading, sparkline and energy totals.
 * The polling itself is done by the plug's PlugPoller on the applet.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    property var poller: null
    property real costPerKWh: 0     // 0 hides cost estimates
    property string currency: "$"

    readonly property var reading: poller ? poller.reading : null
    readonly property string lastError: poller ? poller.lastError : ""
    readonly property bool stale: poller ? poller.stale : false
    readonly property real outletW: reading ? reading.watts : NaN
    readonly property string title: poller ? poller.title : ""
    readonly property string subtitle: poller ? poller.subtitle : ""

    function fmtW(w) { return isNaN(w) ? "—" : (w >= 100 ? Math.round(w) : w.toFixed(1)) + " W" }
    function fmtKWh(wh) { return (wh === undefined || wh === null) ? "—" : (wh / 1000).toFixed(2) + " kWh" }
    function fmtEnergy(wh) {
        if (wh === undefined || wh === null || costPerKWh <= 0)
            return fmtKWh(wh)
        return i18n("%1 ≈ %2", fmtKWh(wh), currency + (wh / 1000 * costPerKWh).toFixed(2))
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
            samples: card.poller ? card.poller.history.samples : []
            capacity: card.poller ? card.poller.historyCapacity : 2
            yFrom: 0
            yTo: card.poller ? card.poller.history.yTo : 100
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: i18n("Today: %1", card.fmtEnergy(card.reading ? card.reading.today_wh : undefined))
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: i18n("Month: %1", card.fmtEnergy(card.reading ? card.reading.month_wh : undefined))
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
