import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_host: hostField.text
    property alias cfg_intervalSeconds: intervalSpin.value
    property alias cfg_historyMinutes: historySpin.value
    // Plasma 6's config dialog also sets cfg_<key>Default; declare them or it
    // logs "does not have a property called ..." for every key.
    property var cfg_hostDefault
    property var cfg_intervalSecondsDefault
    property var cfg_historyMinutesDefault

    Kirigami.FormLayout {
        QQC2.TextField {
            id: hostField
            Kirigami.FormData.label: i18n("Plug address:")
        }
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Poll every (seconds):")
            from: 2
            to: 600
        }

        QQC2.SpinBox {
            id: historySpin
            Kirigami.FormData.label: i18n("Graph shows last (minutes):")
            from: 1
            to: 1440
        }

        QQC2.Label {
            text: i18n("Credentials are your Tapo account, stored by running 'tapo-power --setup' in a terminal.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
        }
    }
}
