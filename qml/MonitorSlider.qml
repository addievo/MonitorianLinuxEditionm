import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: parent.width
    height: 45
    color: isLinked ? "#f0f7ff" : "#ffffff"
    radius: 4
    border.color: isLinked ? "#6bbbff" : "#e0e0e0"
    border.width: 1

    property string monitorName: "Unknown Monitor"
    property int brightnessValue: 50
    property bool isControllable: true
    property bool isLinked: false

    signal brightnessChanged(int value)
    signal linkToggled(bool linked)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Link button
        Rectangle {
            id: linkButton
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            color: linkMouseArea.containsMouse ? "#e6e6e6" : "transparent"
            radius: 2
            border.color: linkMouseArea.containsMouse ? "#d0d0d0" : "transparent"
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 2
                color: isLinked ? "#007ACC" : "transparent"
                border.color: isLinked ? "#007ACC" : "#888888"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "#ffffff"
                    font.pixelSize: 10
                    visible: isLinked
                }
            }

            MouseArea {
                id: linkMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.linkToggled(!isLinked)
                }
            }
        }

        // Monitor info
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Monitor name
            Text {
                text: monitorName
                color: "#303030"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Brightness slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Slider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: brightnessValue
                    enabled: isControllable
                    live: true

                    property int pendingValue: brightnessValue

                    background: Rectangle {
                        x: brightnessSlider.leftPadding
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        width: brightnessSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#dddddd"

                        Rectangle {
                            width: brightnessSlider.visualPosition * parent.width
                            height: parent.height
                            color: isLinked ? "#007ACC" : "#444444"
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: brightnessSlider.pressed ? "#f0f0f0" : "#ffffff"
                        border.color: isLinked ? "#007ACC" : "#888888"
                        border.width: 1

                        // Simple shadow using a background rectangle
                        Rectangle {
                            z: -1
                            anchors.centerIn: parent
                            width: parent.width + 2
                            height: parent.height + 2
                            radius: parent.radius + 1
                            color: "#20000000"
                            visible: !brightnessSlider.pressed
                        }
                    }

                    // Update visual value during dragging
                    onMoved: {
                        pendingValue = Math.round(value)
                    }

                    // Apply changes only on release
                    onPressedChanged: {
                        if (!pressed && pendingValue !== brightnessValue) {
                            root.brightnessChanged(pendingValue)
                        }
                    }
                }

                // Brightness value
                Text {
                    text: brightnessSlider.pressed ? brightnessSlider.pendingValue : brightnessValue
                    color: "#303030"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.preferredWidth: 25
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}