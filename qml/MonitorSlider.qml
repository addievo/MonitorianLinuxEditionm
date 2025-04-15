import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: parent.width
    height: 50

    property string monitorName: "Unknown Monitor"
    property int brightnessValue: 50
    property bool isControllable: true
    property bool isLinked: false

    signal brightnessChanged(int value)
    signal linkToggled(bool linked)

    // Throttle timer
    Timer {
        id: throttleTimer
        interval: 200
        repeat: false
        property int pendingValue: 0
        onTriggered: {
            root.brightnessChanged(pendingValue)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Monitor name
        Text {
            text: monitorName
            color: "#ffffff"
            font.pixelSize: 11
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // Slider row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Brightness slider
            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: brightnessValue
                enabled: isControllable

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: brightnessSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#3a3a3a"

                    Rectangle {
                        width: brightnessSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#2982cc"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: brightnessSlider.pressed ? "#1c86ee" : "#5ca4de"
                    border.color: "#2982cc"
                    border.width: 1
                }

                onMoved: {
                    throttleTimer.pendingValue = Math.round(value)
                    throttleTimer.restart()
                }
            }

            // Link toggle button
            Rectangle {
                width: 20
                height: 20
                radius: 3
                color: isLinked ? "#ff9500" : "transparent"
                border.color: isLinked ? "#e68600" : "#555555"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⋮"
                    color: "#ffffff"
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.linkToggled(!isLinked)
                    }
                }
            }

            // Current brightness value
            Text {
                text: Math.round(brightnessValue)
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 25
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}