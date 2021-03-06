/* Webcamoid, webcam capture application.
 * Copyright (C) 2015  Gonzalo Exequiel Pedone
 *
 * Webcamoid is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Webcamoid is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Webcamoid. If not, see <http://www.gnu.org/licenses/>.
 *
 * Web-Site: http://webcamoid.github.io/
 */

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0 as LABS
import Ak 1.0
import Webcamoid 1.0

ApplicationWindow {
    id: wdgMainWidget
    title: Webcamoid.applicationName()
           + " "
           + Webcamoid.applicationVersion()
           + " - "
           + MediaSource.description(MediaSource.stream)
    visible: true
    x: (Screen.width - Webcamoid.windowWidth) / 2
    y: (Screen.height - Webcamoid.windowHeight) / 2
    width: Webcamoid.windowWidth
    height: Webcamoid.windowHeight

    function notifyUpdate(versionType)
    {
        if (Updates.notifyNewVersion
            && versionType == UpdatesT.VersionTypeOld) {
            trayIcon.show();
            trayIcon.showMessage(qsTr("New version available!"),
                                 qsTr("Download %1 %2 NOW!")
                                    .arg(Webcamoid.applicationName())
                                    .arg(Updates.latestVersion));
            notifyTimer.start();
        }
    }

    function showPane(pane, widget)
    {
        for (let i in pane.children)
            pane.children[i].destroy()

        let component = Qt.createComponent(widget + ".qml")

        if (component.status === Component.Ready) {
            let object = component.createObject(pane)
            object.Layout.fillWidth = true

            return object
        }

        return null
    }

    function savePhoto()
    {
        Recording.takePhoto()
        Recording.savePhoto(qsTr("%1/Picture %2.%3")
                            .arg(Recording.imagesDirectory)
                            .arg(Webcamoid.currentTime())
                            .arg(Recording.imageFormat))
        photoPreviewSaveAnimation.start()
    }

    function pathToUrl(path)
    {
        if (path.length < 1)
            return ""

        return "file://" + path
    }

    Timer {
        id: notifyTimer
        repeat: false
        triggeredOnStart: false
        interval: 10000

        onTriggered: trayIcon.hide()
    }

    onWidthChanged: Webcamoid.windowWidth = width
    onHeightChanged: Webcamoid.windowHeight = height
    onClosing: trayIcon.hide()

    Component.onCompleted: notifyUpdate(Updates.versionType);

    Connections {
        target: Updates

        onVersionTypeChanged: notifyUpdate(versionType);
    }
    Connections {
        target: trayIcon

        onMessageClicked: Qt.openUrlExternally(Webcamoid.projectDownloadsUrl())
    }

    VideoDisplay {
        id: videoDisplay
        objectName: "videoDisplay"
        visible: MediaSource.state === AkElement.ElementStatePlaying
        smooth: true
        anchors.fill: parent
    }
    Image {
        id: photoPreviewThumbnail
        source: pathToUrl(Recording.lastPhotoPreview)
        sourceSize: Qt.size(width, height)
        cache: false
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        x: k * AkUnit.create(16 * AkTheme.controlScale, "dp").pixels
        y: k * (controlsLayout.y
                + (controlsLayout.height - photoPreview.height) / 2)
        width: k * (photoPreview.width - parent.width) + parent.width
        height: k * (photoPreview.height - parent.height) + parent.height
        visible: false

        property real k: 0
    }
    Image {
        id: videoPreviewThumbnail
        source: pathToUrl(Recording.lastVideoPreview)
        sourceSize: Qt.size(width, height)
        cache: false
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        x: k * (parent.width
                - videoPreview.width
                - AkUnit.create(16 * AkTheme.controlScale, "dp").pixels)
        y: k * (controlsLayout.y
                + (controlsLayout.height - videoPreview.height) / 2)
        width: k * (videoPreview.width - parent.width) + parent.width
        height: k * (videoPreview.height - parent.height) + parent.height
        visible: false

        property real k: 0
    }

    ColumnLayout {
        id: leftControls
        width: AkUnit.create(150 * AkTheme.controlScale, "dp").pixels
        anchors.top: parent.top
        anchors.topMargin: AkUnit.create(16 * AkTheme.controlScale, "dp").pixels
        anchors.left: parent.left
        anchors.leftMargin: AkUnit.create(16 * AkTheme.controlScale, "dp").pixels
        state: cameraControls.state

        Button {
            icon.source: "image://icons/video-effects"
            display: AbstractButton.IconOnly
            flat: true

            onClicked: videoEffectsPanel.open()
        }
        Switch {
            id: chkFlash
            text: "Use flash"
            checked: true
            Layout.fillWidth: true
            visible: MediaSource.cameras.includes(MediaSource.stream)
        }
        ComboBox {
            id: cbxTimeShot
            textRole: "text"
            Layout.fillWidth: true
            visible: chkFlash.visible
            model: ListModel {
                id: lstTimeOptions

                ListElement {
                    text: qsTr("Now")
                    time: 0
                }
            }

            Component.onCompleted: {
                for (var i = 5; i < 35; i += 5)
                    lstTimeOptions.append({text: qsTr("%1 seconds").arg(i),
                                           time: i})
            }
        }

        states: [
            State {
                name: "Video"

                PropertyChanges {
                    target: chkFlash
                    visible: false
                }
            }
        ]

        transitions: Transition {
            PropertyAnimation {
                target: chkFlash
                properties: "visible"
                duration: cameraControls.animationTime
            }
        }
    }

    Button {
        id: rightControls
        icon.source: "image://icons/settings"
        display: AbstractButton.IconOnly
        flat: true
        anchors.top: parent.top
        anchors.topMargin: AkUnit.create(16 * AkTheme.controlScale, "dp").pixels
        anchors.right: parent.right
        anchors.rightMargin: AkUnit.create(16 * AkTheme.controlScale, "dp").pixels

        onClicked: settings.popup()
    }
    SettingsMenu {
        id: settings
        width: AkUnit.create(250 * AkTheme.controlScale, "dp").pixels

        onOpenAudioSettings: audioVideoPanel.openAudioSettings()
        onOpenVideoSettings: audioVideoPanel.openVideoSettings()
        onOpenSettings: settingsDialog.open()
    }
    RecordingNotice {
        anchors.top: parent.top
        anchors.topMargin: AkUnit.create(16 * AkTheme.controlScale, "dp").pixels
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Recording.state == AkElement.ElementStatePlaying
    }
    ColumnLayout {
        id: controlsLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Item {
            id: cameraControls
            Layout.margins:
                AkUnit.create(16 * AkTheme.controlScale, "dp").pixels
            height: AkUnit.create(64 * AkTheme.controlScale, "dp").pixels
            Layout.fillWidth: true

            readonly property int animationTime: 200

            Image {
                id: photoPreview
                source: pathToUrl(Recording.lastPhotoPreview)
                width: AkUnit.create(32 * AkTheme.controlScale, "dp").pixels
                height: AkUnit.create(32 * AkTheme.controlScale, "dp").pixels
                sourceSize: Qt.size(width, height)
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectCrop
                y: (parent.height - height) / 2

                MouseArea {
                    cursorShape: enabled?
                                     Qt.PointingHandCursor:
                                     Qt.ArrowCursor
                    anchors.fill: parent
                    enabled: photoPreview.visible
                             && photoPreview.status == Image.Ready

                    onClicked: {
                        if (photoPreview.status == Image.Ready)
                            Qt.openUrlExternally(photoPreview.source)
                    }
                }
            }
            RoundButton {
                id: photoButton
                icon.source: "image://icons/photo"
                radius: AkUnit.create(32 * AkTheme.controlScale, "dp").pixels
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Take a photo")
                focus: true
                enabled: Recording.state == AkElement.ElementStateNull
                         && (MediaSource.state === AkElement.ElementStatePlaying
                             || cameraControls.state == "Video")

                onClicked: {
                    if (cameraControls.state == "Video") {
                        cameraControls.state = ""
                    } else {
                        if (!chkFlash.visible) {
                            savePhoto()

                            return
                        }

                        if (cbxTimeShot.currentIndex == 0) {
                            if (chkFlash.checked)
                                flash.show()
                            else
                                savePhoto()

                            return
                        }

                        if (updateProgress.running) {
                            updateProgress.stop()
                            pgbPhotoShot.value = 0
                            cbxTimeShot.enabled = true
                            chkFlash.enabled = true
                        } else {
                            cbxTimeShot.enabled = false
                            chkFlash.enabled = false
                            pgbPhotoShot.start = new Date().getTime()
                            updateProgress.start()
                        }
                    }
                }
            }
            RoundButton {
                id: videoButton
                icon.source: Recording.state == AkElement.ElementStateNull?
                                 "image://icons/video":
                                 "image://icons/record-stop"
                radius: AkUnit.create(24 * AkTheme.controlScale, "dp").pixels
                x: parent.width - width
                y: (parent.height - height) / 2
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Record video")
                enabled: MediaSource.state === AkElement.ElementStatePlaying
                         || cameraControls.state == ""

                onClicked: {
                    if (cameraControls.state == "") {
                        cameraControls.state = "Video"
                    } else if (Recording.state == AkElement.ElementStateNull) {
                        Recording.state = AkElement.ElementStatePlaying
                    } else {
                        Recording.state = AkElement.ElementStateNull
                        videoPreviewSaveAnimation.start()
                    }
                }
            }
            Image {
                id: videoPreview
                source: pathToUrl(Recording.lastVideoPreview)
                width: 0
                height: 0
                sourceSize: Qt.size(width, height)
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectCrop
                visible: false
                x: parent.width - width
                y: (parent.height - height) / 2

                MouseArea {
                    cursorShape: enabled?
                                     Qt.PointingHandCursor:
                                     Qt.ArrowCursor
                    anchors.fill: parent
                    enabled: videoPreview.visible
                             && videoPreview.status == Image.Ready

                    onClicked: {
                        if (videoPreview.status == Image.Ready)
                            Qt.openUrlExternally("file://" + Recording.lastVideo)
                    }
                }
            }

            states: [
                State {
                    name: "Video"

                    PropertyChanges {
                        target: photoPreview
                        width: 0
                        height: 0
                        visible: false
                    }
                    PropertyChanges {
                        target: photoButton
                        radius: AkUnit.create(24 * AkTheme.controlScale, "dp").pixels
                        x: 0
                    }
                    PropertyChanges {
                        target: videoButton
                        radius: AkUnit.create(32 * AkTheme.controlScale, "dp").pixels
                        x: (parent.width - width) / 2
                    }
                    PropertyChanges {
                        target: videoPreview
                        width: AkUnit.create(32 * AkTheme.controlScale, "dp").pixels
                        height: AkUnit.create(32 * AkTheme.controlScale, "dp").pixels
                        visible: true
                    }
                }
            ]

            transitions: Transition {
                PropertyAnimation {
                    target: photoPreview
                    properties: "width,height,visible"
                    duration: cameraControls.animationTime
                }
                PropertyAnimation {
                    target: photoButton
                    properties: "radius,x"
                    duration: cameraControls.animationTime
                }
                PropertyAnimation {
                    target: videoButton
                    properties: "radius,x"
                    duration: cameraControls.animationTime
                }
                PropertyAnimation {
                    target: videoPreview
                    properties: "width,height,visible"
                    duration: cameraControls.animationTime
                }
            }
        }
        ProgressBar {
            id: pgbPhotoShot
            Layout.fillWidth: true
            visible: updateProgress.running

            property double start: 0

            onValueChanged: {
                if (value >= 1) {
                    updateProgress.stop()
                    value = 0
                    cbxTimeShot.enabled = true
                    chkFlash.enabled = true

                    if (chkFlash.checked)
                        flash.show()
                    else
                        savePhoto()
                }
            }
        }
    }
    VideoEffectsPanel {
        id: videoEffectsPanel

        onOpenVideoEffectsDialog: videoEffectsDialog.open()
    }
    AudioVideoPanel {
        id: audioVideoPanel
    }
    Item {
        id: splitView
        anchors.fill: parent

        property int panelBorder: AkUnit.create(1 * AkTheme.controlScale, "dp").pixels
        property int dragBorder: AkUnit.create(4 * AkTheme.controlScale, "dp").pixels
        property int minimumWidth: 100

        onWidthChanged: {
            paneLeft.width = Math.max(paneLeft.width,
                                      splitView.minimumWidth)
            paneLeft.width = Math.min(paneLeft.width,
                                      splitView.width
                                      - paneRight.width
                                      - splitView.panelBorder
                                      - splitView.dragBorder)
            paneRight.width = Math.max(paneRight.width,
                                       splitView.minimumWidth)
            paneRight.width = Math.min(paneRight.width,
                                       splitView.width
                                       - paneLeft.width
                                       - splitView.panelBorder
                                       - splitView.dragBorder)
        }

        Pane {
            id: paneLeft
            implicitWidth: 250
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            visible: optionWebcam.checked
                     || optionSettings.checked

            ScrollView {
                id: scrollViewLeft
                contentHeight: paneLeftLayout.height
                anchors.fill: parent
                clip: true

                ColumnLayout {
                    id: paneLeftLayout
                    width: scrollViewLeft.width
                }
            }
        }
        Rectangle {
            id: rectangleLeft
            width: splitView.panelBorder
            color: AkTheme.palette.active.dark
            anchors.leftMargin: -splitView.panelBorder / 2
            anchors.left: paneLeft.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: paneLeft.visible
        }
        MouseArea {
            cursorShape: Qt.SizeHorCursor
            width: splitView.panelBorder + 2 * splitView.dragBorder
            anchors.leftMargin: -width / 2
            anchors.left: paneLeft.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            drag.axis: Drag.XAxis
            visible: paneLeft.visible

            onPositionChanged: {
                paneLeft.width += mouse.x
                paneLeft.width = Math.max(paneLeft.width,
                                          splitView.minimumWidth)
                paneLeft.width = Math.min(paneLeft.width,
                                          splitView.width
                                          - paneRight.width
                                          - splitView.panelBorder
                                          - splitView.dragBorder)
            }
        }

        Pane {
            id: paneRight
            implicitWidth: 450
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            visible: optionWebcam.checked
                     || optionSettings.checked

            ScrollView {
                id: scrollViewRight
                contentHeight: paneRightLayout.height
                anchors.fill: parent
                clip: true

                ColumnLayout {
                    id: paneRightLayout
                    width: scrollViewRight.width
                }
            }
        }
        Rectangle {
            id: rectangleRight
            width: splitView.panelBorder
            color: AkTheme.palette.active.dark
            anchors.rightMargin: -splitView.panelBorder / 2
            anchors.right: paneRight.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: paneRight.visible
        }
        MouseArea {
            cursorShape: Qt.SizeHorCursor
            width: splitView.panelBorder + 2 * splitView.dragBorder
            anchors.rightMargin: -width / 2
            anchors.right: rectangleRight.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            drag.axis: Drag.XAxis
            visible: paneRight.visible

            onPositionChanged: {
                paneRight.width -= mouse.x
                paneRight.width = Math.max(paneRight.width,
                                           splitView.minimumWidth)
                paneRight.width = Math.min(paneRight.width,
                                           splitView.width
                                           - paneLeft.width
                                           - splitView.panelBorder
                                           - splitView.dragBorder)
            }
        }
    }

    footer: ToolBar {
        id: toolBar

        ButtonGroup {
            id: buttonGroup

            property Item currentOption: null

            onClicked: {
                if (currentOption == button) {
                    currentOption = null
                    button.checked = false
                } else {
                    currentOption = button
                }
            }
        }
        RowLayout {
            id: iconBar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.top: parent.top
            spacing: 0

            ToolButton {
                id: optionWebcam
                implicitWidth: toolBar.height
                implicitHeight: toolBar.height
                icon.source: "image://icons/webcam"
                icon.width: 0.75 * implicitWidth
                icon.height: 0.75 * implicitHeight
                checkable: true
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Configure sources")
                display: AbstractButton.IconOnly
                ButtonGroup.group: buttonGroup

                onClicked: {
                    showPane(paneLeftLayout, "MediaBar")
                    showPane(paneRightLayout, "MediaConfig")
                }
            }
            ToolButton {
                id: optionSettings
                implicitWidth: toolBar.height
                implicitHeight: toolBar.height
                icon.source: "image://icons/settings"
                icon.width: 0.75 * implicitWidth
                icon.height: 0.75 * implicitHeight
                checkable: true
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Preferences")
                display: AbstractButton.IconOnly
                ButtonGroup.group: buttonGroup

                onClicked: {
                    let options = {
                        "output": "OutputConfig",
                    }
                    let configBar = showPane(paneLeftLayout, "ConfigBar")

                    if (options[configBar.option])
                        showPane(paneRightLayout, options[configBar.option])

                    configBar.onOptionChanged.connect(function () {
                        if (options[configBar.option])
                            showPane(paneRightLayout, options[configBar.option])
                    })
                }
            }
        }
    }

    SequentialAnimation {
        id: photoPreviewSaveAnimation

        PropertyAnimation {
            target: photoPreviewThumbnail
            property: "k"
            to: 0
            duration: 0
        }
        PropertyAnimation {
            target: photoPreview
            property: "visible"
            to: false
            duration: 0
        }
        PropertyAnimation {
            target: photoPreviewThumbnail
            property: "visible"
            to: true
            duration: 0
        }
        PropertyAnimation {
            target: photoPreviewThumbnail
            property: "k"
            to: 1
            duration: 500
        }
        PropertyAnimation {
            target: photoPreviewThumbnail
            property: "visible"
            to: false
            duration: 0
        }
        PropertyAnimation {
            target: photoPreview
            property: "visible"
            to: true
            duration: 0
        }
    }
    SequentialAnimation {
        id: videoPreviewSaveAnimation

        PropertyAnimation {
            target: videoPreviewThumbnail
            property: "k"
            to: 0
            duration: 0
        }
        PropertyAnimation {
            target: videoPreview
            property: "visible"
            to: false
            duration: 0
        }
        PropertyAnimation {
            target: videoPreviewThumbnail
            property: "visible"
            to: true
            duration: 0
        }
        PropertyAnimation {
            target: videoPreviewThumbnail
            property: "k"
            to: 1
            duration: 500
        }
        PropertyAnimation {
            target: videoPreviewThumbnail
            property: "visible"
            to: false
            duration: 0
        }
        PropertyAnimation {
            target: videoPreview
            property: "visible"
            to: true
            duration: 0
        }
    }
    Timer {
        id: updateProgress
        interval: 100
        repeat: true

        onTriggered: {
            var timeout = 1000 * lstTimeOptions.get(cbxTimeShot.currentIndex).time
            pgbPhotoShot.value = (new Date().getTime() - pgbPhotoShot.start) / timeout
        }
    }
    Flash {
        id: flash

        onTriggered: savePhoto()
    }
    VideoEffectsDialog {
        id: videoEffectsDialog
        width: parent.width
        height: parent.height
    }
    SettingsDialog {
        id: settingsDialog
        width: parent.width
        height: parent.height

        onOpenVideoFormatDialog: videoFormatOptions.open()
        onOpenVideoCodecDialog: videoCodecOptions.open()
        onOpenAudioCodecDialog: audioCodecOptions.open()
    }
    VideoFormatOptions {
        id: videoFormatOptions
        width: parent.width
        height: parent.height
    }
    VideoCodecOptions {
        id: videoCodecOptions
        width: parent.width
        height: parent.height
    }
    AudioCodecOptions {
        id: audioCodecOptions
        width: parent.width
        height: parent.height
    }
    LABS.Settings {
        category: "GeneralConfigs"

        property alias useFlash: chkFlash.checked
        property alias photoTimeout: cbxTimeShot.currentIndex
    }
}
