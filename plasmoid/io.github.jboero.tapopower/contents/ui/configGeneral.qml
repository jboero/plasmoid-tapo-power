import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_hosts: hostsField.text
    property alias cfg_intervalSeconds: intervalSpin.value
    property alias cfg_historyMinutes: historySpin.value
    property alias cfg_costPerKWh: rateField.text
    property alias cfg_currency: currencyField.text
    // Plasma 6's config dialog also sets cfg_<key>Default; declare them or it
    // logs "does not have a property called ..." for every key.
    property var cfg_hostsDefault
    property var cfg_intervalSecondsDefault
    property var cfg_historyMinutesDefault
    property var cfg_costPerKWhDefault
    property var cfg_currencyDefault

    Kirigami.FormLayout {
        QQC2.TextArea {
            id: hostsField
            Kirigami.FormData.label: i18n("Plug addresses:")
            placeholderText: i18n("One address per line")
            implicitWidth: Kirigami.Units.gridUnit * 14
            implicitHeight: Kirigami.Units.gridUnit * 5
            wrapMode: TextEdit.NoWrap
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

        QQC2.TextField {
            id: rateField
            Kirigami.FormData.label: i18n("Electricity rate (per kWh):")
            placeholderText: "0.19342"
            // A dot decimal regardless of locale, since the applet parses it with parseFloat.
            validator: RegularExpressionValidator { regularExpression: /^\d*\.?\d{0,6}$/ }
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        QQC2.TextField {
            id: currencyField
            Kirigami.FormData.label: i18n("Currency symbol:")
            maximumLength: 4
            implicitWidth: Kirigami.Units.gridUnit * 3
        }
        QQC2.Label {
            text: i18n("Costs are estimates from energy use times this rate. Fixed charges and taxes on your bill are not included. Set the rate to 0 to hide costs.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
        }

        QQC2.Label {
            text: i18n("Credentials are your Tapo account, stored by running 'tapo-power --setup' in a terminal.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
        }
    }
}
