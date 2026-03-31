import QtQuick
import QtQuick.Layouts
import Quickshell
import io.qt.examples.textstyle

Widget {
    id: root
    
    property string apiUrl: "http://localhost:8384/rest"
    property string apiKey: ""
    property int updateInterval: 5000
    property bool showDeviceCount: true
    property bool showProgressBar: true
    
    property var syncthingData: ({
        "connected": false,
        "devices": [],
        "folders": [],
        "uptime": 0,
        "globalBytes": 0,
        "localBytes": 0
    })
    
    Timer {
        interval: root.updateInterval
        running: true
        repeat: true
        onTriggered: updateSyncthingStatus()
    }
    
    function updateSyncthingStatus() {
        if (apiKey === "") {
            syncthingData.connected = false
            return
        }
        
        // Fetch system status
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiUrl + "/system/status")
        xhr.setRequestHeader("X-API-Key", apiKey)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var data = JSON.parse(xhr.responseText)
                    syncthingData.connected = true
                    syncthingData.uptime = data.uptime || 0
                    syncthingData.globalBytes = data.globalBytes || 0
                    syncthingData.localBytes = data.localBytes || 0
                } else {
                    syncthingData.connected = false
                }
            }
        }
        xhr.send()
        
        // Fetch connections
        var connXhr = new XMLHttpRequest()
        connXhr.open("GET", apiUrl + "/system/connections")
        connXhr.setRequestHeader("X-API-Key", apiKey)
        connXhr.onreadystatechange = function() {
            if (connXhr.readyState === XMLHttpRequest.DONE) {
                if (connXhr.status === 200) {
                    var connData = JSON.parse(connXhr.responseText)
                    syncthingData.devices = connData.connections || []
                }
            }
        }
        connXhr.send()
    }
    
    Rectangle {
        color: "transparent"
        implicitWidth: content.implicitWidth + 10
        implicitHeight: 24
        
        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                text: "⚡"
                color: syncthingData.connected ? "#4CAF50" : "#F44336"
                font.pixelSize: 14
            }
            
            Text {
                text: syncthingData.connected ? "Sync" : "Offline"
                color: palette.text
                font.pixelSize: 12
            }
            
            Text {
                visible: showDeviceCount && syncthingData.connected
                text: "(" + syncthingData.devices.length + ")"
                color: palette.text
                font.pixelSize: 10
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Toggle detailed view or open Syncthing web UI
                Qt.openUrlExternally("http://localhost:8384/")
            }
        }
    }
}