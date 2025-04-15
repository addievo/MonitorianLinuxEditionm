import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: parent.width
    height: 52
    color: isLinked ? "#202C40" : "#20253A"
    radius: 8
    border.color: isLinked ? "#60A5FA" : "#40506080"
    border.width: 1
    opacity: 0.98

    // Glass effect
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        opacity: 0.08
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#80ffffff" }
            GradientStop { position: 1.0; color: "#00ffffff" }
        }
    }

    property string monitorName: "Unknown Monitor"
    property int brightnessValue: 50
    property bool isControllable: true
    property bool isLinked: false

    signal brightnessChanged(int value)
    signal linkToggled(bool linked)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Link button
        Rectangle {
            id: linkButton
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            color: linkMouseArea.containsMouse ? "#30ffffff" : "transparent"
            radius: 4
            border.color: isLinked ? "#60A5FA" : "#40808080"
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 3
                color: isLinked ? "#60A5FA" : "#20ffffff"
                border.color: isLinked ? "#80C8FF" : "#60808080"
                border.width: isLinked ? 0 : 1
                opacity: isLinked ? 1.0 : 0.7

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "#ffffff"
                    font.pixelSize: 11
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
                spacing: 12

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
                        color: "#30404040"

                        Rectangle {
                            width: brightnessSlider.visualPosition * parent.width
                            height: parent.height
                            color: isLinked ? "#60A5FA" : "#50A0F0"
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: brightnessSlider.pressed ? "#F0F0F0" : "#FFFFFF"
                        border.color: isLinked ? "#60A5FA" : "#50A0F0"
                        border.width: 1
                        antialiasing: true

                        // Glass effect for handle
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            opacity: 0.2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#80ffffff" }
                                GradientStop { position: 1.0; color: "#00ffffff" }
                            }
                        }

                        // Shadow
                        Rectangle {
                            z: -1
                            anchors.centerIn: parent
                            width: parent.width + 2
                            height: parent.height + 2
                            radius: 9
                            color: "#30000000"
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
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}