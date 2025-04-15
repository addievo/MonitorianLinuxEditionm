import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

Window {
    id: mainWindow
    visible: true
    width: 320
    height: Math.min(Math.max(150, 48 * monitorManager.monitors.length + 100), 400) * 1.15
    title: "Monitor Brightness Control"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Shadow effect for the window
    Rectangle {
        id: shadowRect
        anchors.fill: parent
        color: "#121418"
        border.color: "#35000000"
        border.width: 1
        radius: 8
        opacity: 0.98
    }

    // Position window near system tray
    function showAtSystemTrayPosition() {
        var screenWidth = Screen.width
        var screenHeight = Screen.height
        mainWindow.x = screenWidth - mainWindow.width - 20
        mainWindow.y = screenHeight - mainWindow.height - 40
        mainWindow.show()
        mainWindow.raise()
        mainWindow.requestActivate()
    }

    // Show centered on screen initially
    Component.onCompleted: {
        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
    }

    // Linked monitors management
    property var linkedMonitors: []
    signal linkedMonitorsUpdated() // Changed from linkedMonitorsChanged to avoid conflict

    function toggleMonitorLink(monitorId, linked) {
        if (linked) {
            if (!linkedMonitors.includes(monitorId)) {
                linkedMonitors.push(monitorId)
                console.log("Linked monitor: " + monitorId)
            }
        } else {
            var index = linkedMonitors.indexOf(monitorId)
            if (index !== -1) {
                linkedMonitors.splice(index, 1)
                console.log("Unlinked monitor: " + monitorId)
            }
        }
        linkedMonitorsUpdated()
    }

    function updateLinkedMonitors(sourceMonitorId, brightness) {
        // Only update if the source monitor is linked
        if (linkedMonitors.includes(sourceMonitorId)) {
            for (var i = 0; i < monitorManager.monitors.length; i++) {
                var monitor = monitorManager.monitors[i]
                if (linkedMonitors.includes(monitor.id) && monitor.id !== sourceMonitorId) {
                    console.log("Syncing monitor: " + monitor.id + " to brightness: " + brightness)
                    monitor.brightness = brightness
                }
            }
        }
    }

    function isAllLinked() {
        if (monitorManager.monitors.length === 0) return false

        for (var i = 0; i < monitorManager.monitors.length; i++) {
            if (!linkedMonitors.includes(monitorManager.monitors[i].id)) {
                return false
            }
        }
        return true
    }

    function linkAllMonitors(link) {
        if (link) {
            // Link all monitors
            linkedMonitors = []
            for (var i = 0; i < monitorManager.monitors.length; i++) {
                linkedMonitors.push(monitorManager.monitors[i].id)
            }
        } else {
            // Unlink all monitors
            linkedMonitors = []
        }
        linkedMonitorsUpdated()
    }

    // Allow dragging the window
    Rectangle {
        id: titleBar
        height: 36
        color: "#0078D7"
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 1
        }
        radius: 7

        // Only top corners should be rounded
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: -7
            }
            height: 8
            color: parent.color
        }

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }
            text: "Monitor Brightness Control"
            color: "#ffffff"
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            property point clickPos: "0,0"
            onPressed: {
                clickPos = Qt.point(mouse.x, mouse.y)
            }
            onPositionChanged: {
                var delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y)
                mainWindow.x += delta.x
                mainWindow.y += delta.y
            }
        }

        // Close button
        Rectangle {
            id: closeButton
            width: 36
            height: parent.height
            color: closeMouseArea.containsMouse ? "#E81123" : "transparent"
            anchors.right: parent.right
            anchors.top: parent.top

            Text {
                anchors.centerIn: parent
                text: "×"
                color: "#ffffff"
                font.pixelSize: 18
            }

            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: mainWindow.hide()
            }
        }

        // Minimize button
        Rectangle {
            id: minimizeButton
            width: 36
            height: parent.height
            color: minimizeMouseArea.containsMouse ? "#20ffffff" : "transparent"
            anchors.right: closeButton.left
            anchors.top: parent.top

            Text {
                anchors.centerIn: parent
                text: "−"
                color: "#ffffff"
                font.pixelSize: 18
            }

            MouseArea {
                id: minimizeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: mainWindow.showMinimized()
            }
        }
    }

    // Main content
    Item {
        anchors {
            top: titleBar.bottom
            left: parent.left
            right: parent.right
            bottom: statusBar.top
            leftMargin: 1
            rightMargin: 1
        }

        // Inner background with slight blur effect
        Rectangle {
            anchors.fill: parent
            color: "#0F1013"
        }

        // Monitors list
        ListView {
            id: monitorListView
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            spacing: 8
            model: monitorManager.monitors
            interactive: false // Disable scrolling

            delegate: MonitorSlider {
                width: monitorListView.width
                monitorName: modelData.displayName
                brightnessValue: modelData.brightness
                isControllable: modelData.controllable
                isLinked: linkedMonitors.includes(modelData.id)

                // Respond to global linked monitors changes
                Connections {
                    target: mainWindow
                    function onLinkedMonitorsUpdated() {
                        isLinked = linkedMonitors.includes(modelData.id)
                    }
                }

                onBrightnessChanged: {
                    modelData.brightness = value
                    updateLinkedMonitors(modelData.id, value)
                }

                onLinkToggled: {
                    toggleMonitorLink(modelData.id, linked)
                }
            }

            // Empty state message
            Item {
                anchors.fill: parent
                visible: monitorManager.monitors.length === 0

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.9
                    height: 90
                    color: "#1A1D24"
                    radius: 4
                    border.color: "#404652"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: monitorManager.ddcUtilAvailable ?
                                "No compatible monitors found" :
                                "ddcutil not available"
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: monitorManager.ddcUtilAvailable ?
                                "Connect DDC-compatible monitors" :
                                "Please install ddcutil and ensure proper permissions"
                            color: "#aaaaaa"
                            font.pixelSize: 11
                            width: parent.width - 20
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Status bar
    Rectangle {
        id: statusBar
        height: 45
        color: "#0F1013"
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 1
            rightMargin: 1
            bottomMargin: 1
        }
        radius: 7

        // Only bottom corners should be rounded
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: -7
            }
            height: 8
            color: parent.color
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 8

            // Refresh button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                Layout.leftMargin: 10
                Layout.rightMargin: 5
                color: refreshMouseArea.containsMouse ? "#252830" : "#1A1D24"
                radius: 4
                border.color: "#404652"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        id: refreshIcon
                        text: "⟳"
                        color: "#ffffff"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter

                        // Rotation behavior
                        Behavior on rotation {
                            NumberAnimation { duration: 500 }
                        }
                    }

                    Text {
                        text: "Refresh"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        refreshIcon.rotation += 360
                        monitorManager.detectMonitors()
                    }
                }
            }

            // Link/Unlink all button
            Rectangle {
                id: linkAllButton
                Layout.preferredWidth: 90
                Layout.preferredHeight: 30
                Layout.rightMargin: 10
                color: isAllLinked() ? "#252830" : "#1A1D24"
                radius: 4
                border.color: "#404652"
                border.width: 1
                visible: monitorManager.monitors.length > 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 15
                        height: 15
                        radius: 2
                        color: "transparent"
                        border.color: isAllLinked() ? "#3498DB" : "#60808080"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 1.5
                            color: isAllLinked() ? "#3498DB" : "transparent"
                            visible: isAllLinked()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#ffffff"
                            font.pixelSize: 10
                            visible: isAllLinked()
                        }
                    }

                    Text {
                        text: isAllLinked() ? "Unlink All" : "Link All"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: linkAllMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        linkAllMonitors(!isAllLinked())
                    }
                }
            }
        }
    }

    // Status notification
    Rectangle {
        id: notification
        width: notificationText.width + 40
        height: 40
        color: "#1A2040"
        opacity: 0
        radius: 8
        border.color: "#60A5FA"
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 15

        // Glass effect
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            opacity: 0.05
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#80ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        Text {
            id: notificationText
            anchors.centerIn: parent
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        // Show/hide animations
        NumberAnimation on opacity {
            id: showNotification
            from: 0
            to: 1
            duration: 200
            running: false
        }

        NumberAnimation on opacity {
            id: hideNotification
            from: 1
            to: 0
            duration: 200
            running: false
        }
    }

    // Handle error messages
    Connections {
        target: monitorManager

        function onMonitorOperationFailed(message) {
            // Only show error messages that are NOT related to brightness setting
            if (!message.includes("Failed to set brightness")) {
                notificationText.text = message
                showNotification.start()
                notificationTimer.restart()
            }
        }
    }

    Timer {
        id: notificationTimer
        interval: 3000
        onTriggered: hideNotification.start()
    }

    // System tray integration
    SystemTrayIcon {
        id: sysTrayIcon
        visible: true
        tooltip: "Monitor Brightness Control"

        onActivated: {
            if (reason === SystemTrayIcon.Trigger) {
                if (mainWindow.visible) {
                    mainWindow.hide()
                } else {
                    monitorManager.detectMonitors()
                    showAtSystemTrayPosition()
                }
            }
        }

        menu: Menu {
            MenuItem {
                text: "Open"
                onTriggered: {
                    monitorManager.detectMonitors()
                    showAtSystemTrayPosition()
                }
            }
            MenuItem {
                text: "Exit"
                onTriggered: Qt.quit()
            }
        }
    }
}