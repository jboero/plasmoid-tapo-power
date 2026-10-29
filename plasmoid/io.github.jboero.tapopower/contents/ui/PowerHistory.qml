/*
 * Rolling window of power readings, newest first, with the statistics and the
 * axis range the graphs need. Each plug keeps one, and the total keeps another.
 */
import QtQuick

QtObject {
    id: history

    property int capacity: 360
    property var samples: []        // watts, newest first
    property var sampleTimes: []    // Date.now() for each sample, same order

    readonly property real minW: samples.length ? Math.min.apply(null, samples) : NaN
    readonly property real maxW: samples.length ? Math.max.apply(null, samples) : NaN
    readonly property real avgW: samples.length ? samples.reduce((a, b) => a + b, 0) / samples.length : NaN
    readonly property double peakAtMs: (samples.length && sampleTimes[samples.indexOf(maxW)]) || 0
    // Y axis always starts at zero so the trace keeps its true proportion; the
    // top is the window's peak plus some headroom, rounded up to a tidy step.
    readonly property real yStep: isNaN(maxW) || maxW <= 100 ? 20 : (maxW <= 500 ? 100 : 250)
    readonly property real yTo: isNaN(maxW) ? 100 : Math.ceil(maxW * 1.1 / yStep) * yStep

    function record(w) {
        if (isNaN(w))
            return
        // Times first: bindings on `samples` look the matching time up.
        history.sampleTimes = [Date.now()].concat(history.sampleTimes).slice(0, history.capacity)
        history.samples = [w].concat(history.samples).slice(0, history.capacity)
    }
}
