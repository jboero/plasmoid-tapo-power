/*
 * Line graph of recent power readings, newest at the right edge.
 *
 * `samples` is newest-first, so with ZeroAtEnd index 0 sits on the right and
 * the trace scrolls left as readings arrive. The x range is fixed to the full
 * window rather than automatic, so a half-filled window draws as a line that
 * starts partway across instead of being stretched to fill the width.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartsControls

Item {
    id: graph

    property var samples: []          // watts, newest first
    property int capacity: 360        // points in the full window
    property real yFrom: 0
    property real yTo: 100
    property bool showAxes: true
    property string windowLabel: ""   // e.g. "30 min"
    property color lineColor: Kirigami.Theme.highlightColor

    readonly property color gridColor: Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b, 0.15)

    ChartsControls.GridLines {
        anchors.fill: chart
        chart: chart
        visible: graph.showAxes
        major.count: 3
        major.lineWidth: 1
        major.color: graph.gridColor
        minor.visible: false
    }

    ChartsControls.AxisLabels {
        id: yLabels
        visible: graph.showAxes
        anchors {
            left: parent.left
            top: parent.top
            bottom: xLabels.top
        }
        direction: ChartsControls.AxisLabels.VerticalBottomTop
        delegate: PlasmaComponents.Label {
            text: Math.round(ChartsControls.AxisLabels.label) + " W"
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        source: Charts.ChartAxisSource {
            chart: chart
            axis: Charts.ChartAxisSource.YAxis
            itemCount: 5
        }
    }

    // Time labels are drawn by hand: ChartAxisSource would label sample
    // indices, which mean nothing to a reader.
    RowLayout {
        id: xLabels
        visible: graph.showAxes
        height: visible ? implicitHeight : 0
        anchors {
            left: chart.left
            right: chart.right
            bottom: parent.bottom
        }
        PlasmaComponents.Label {
            text: graph.windowLabel ? "−" + graph.windowLabel : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        Item { Layout.fillWidth: true }
        PlasmaComponents.Label {
            text: i18n("now")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }

    Charts.LineChart {
        id: chart
        anchors {
            top: parent.top
            left: graph.showAxes ? yLabels.right : parent.left
            leftMargin: graph.showAxes ? Kirigami.Units.smallSpacing : 0
            right: parent.right
            bottom: graph.showAxes ? xLabels.top : parent.bottom
        }
        direction: Charts.XYChart.ZeroAtEnd
        interpolate: false
        lineWidth: graph.showAxes ? 2 : 1
        fillOpacity: 0.25
        xRange {
            automatic: false
            from: 0
            to: Math.max(1, graph.capacity - 1)
        }
        yRange {
            automatic: false
            from: graph.yFrom
            to: graph.yTo
        }
        valueSources: Charts.ArraySource { array: graph.samples }
        colorSource: Charts.SingleValueSource { value: graph.lineColor }
    }
}
