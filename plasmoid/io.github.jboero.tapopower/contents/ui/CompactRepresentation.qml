/*
 * Panel and tray face. In the system tray there is only an icon-sized square,
 * so the reading rides on a badge; on a normal panel there is room for text.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    // The system tray is the containment that draws its own plasmoid headings.
    readonly property bool inTray: (Plasmoid.containmentDisplayHints
                                    & PlasmaCore.Types.ContainmentDrawsPlasmoidHeading) !== 0
    readonly property bool faulted: root.faulted
    readonly property bool dim: root.dim
    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    Layout.minimumWidth: inTray ? Kirigami.Units.iconSizes.small : row.implicitWidth
    Layout.preferredWidth: inTray ? -1 : row.implicitWidth
    Layout.minimumHeight: Kirigami.Units.iconSizes.small

    hoverEnabled: true
    onClicked: root.expanded = !root.expanded

    // ---- tray: icon filling the cell, reading as a badge
    Kirigami.Icon {
        visible: compact.inTray
        anchors.fill: parent
        source: compact.faulted ? "dialog-warning" : root.iconName
        isMask: false
        active: compact.containsMouse
        opacity: compact.dim && !compact.faulted ? 0.6 : 1.0
    }
    Rectangle {
        visible: compact.inTray && root.okCount > 0
                 && compact.height >= Kirigami.Units.iconSizes.small
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Sized from the label, while the label's font derives from the
        // panel-imposed height of `compact` -- never from this rectangle,
        // which would be a binding loop.
        width: Math.min(compact.width, badgeLabel.implicitWidth + 2)
        height: Math.min(compact.height * 0.55, badgeLabel.implicitHeight)
        radius: height / 3
        color: Kirigami.Theme.backgroundColor
        opacity: 0.9

        PlasmaComponents.Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.wattBadge
            font.pixelSize: Math.max(7, Math.round(compact.height * 0.38))
            font.bold: true
            opacity: compact.dim ? 0.6 : 1.0
        }
    }

    // ---- panel: icon plus the full reading
    RowLayout {
        id: row
        visible: !compact.inTray
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: compact.faulted ? "dialog-warning" : root.iconName
            isMask: false
        }
        // Live sparkline on a horizontal panel; same data as the popup graph.
        PowerGraph {
            visible: compact.horizontal
            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
            Layout.fillHeight: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            showAxes: false
            samples: root.totalHistory.samples
            capacity: root.historyCapacity
            yFrom: 0
            yTo: root.totalHistory.yTo
        }
        PlasmaComponents.Label {
            text: root.panelText
            opacity: compact.dim ? 0.5 : 1.0
        }
    }
}
