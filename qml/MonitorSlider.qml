import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: parent.width
    height: 45
    color: "transparent"
    radius: 4
    border.width: 0

    property string monitorName: "Unknown Monitor"
    property int brightnessValue: 50
    property bool isControllable: true
    property bool isLinked: false

    signal brightnessChanged(int value)
    signal linkToggled(bool linked)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        // Link button
        Rectangle {
            id: linkButton
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            color: "transparent"
            border.color: isLinked ? "#3498DB" : "#60808080"
            border.width: 1
            radius: 3

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 2
                color: isLinked ? "#3498DB" : "transparent"
                visible: isLinked
            }

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "#ffffff"
                font.pixelSize: 10
                visible: isLinked
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
            spacing: 5

            // Monitor name
            Text {
                text: monitorName
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Brightness slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

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
                        height: 2
                        color: "#40404040"

                        Rectangle {
                            width: brightnessSlider.visualPosition * parent.width
                            height: parent.height
                            color: isLinked ? "#3498DB" : "#3498DB"
                        }
                    }

                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: "#FFFFFF"
                        border.color: isLinked ? "#3498DB" : "#3498DB"
                        border.width: 1
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
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}