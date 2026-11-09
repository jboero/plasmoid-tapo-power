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

    // Y labels at round values, only as many as fit with a line's gap between
    // them, so a short graph gets fewer labels instead of overlapping ones.
    readonly property var yTicks: {
        var span = yTo - yFrom
        if (!(span > 0) || chart.height <= 0)
            return []
        var room = Math.max(1, Math.floor(chart.height / (tickMetrics.height * 2)))
        var step = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000]
                       .find(s => span / s <= room) || span
        var ticks = []
        for (var v = yFrom; v <= yTo + 1e-6; v += step)
            ticks.push(v)
        return ticks
    }

    TextMetrics {
        id: tickMetrics
        font: Kirigami.Theme.smallFont
        text: Math.round(graph.yTo) + " W"
    }

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

    // Placed by hand: AxisLabels stacked every label at the top of a short graph.
    Item {
        id: yLabels
        visible: graph.showAxes
        width: visible ? Math.ceil(tickMetrics.advanceWidth) : 0
        anchors {
            left: parent.left
            top: chart.top
            bottom: chart.bottom
        }
        Repeater {
            model: graph.showAxes ? graph.yTicks : []
            PlasmaComponents.Label {
                // Centred on its value, but kept inside the chart's height.
                y: Math.max(0, Math.min(yLabels.height - height,
                       yLabels.height * (1 - (modelData - graph.yFrom) / (graph.yTo - graph.yFrom)) - height / 2))
                anchors.right: parent.right
                text: Math.round(modelData) + " W"
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
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
