import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 单张公告：只展示数据、报告点击，不请求接口和切换页面。
Rectangle {
    id: card
    implicitWidth: 480
    implicitHeight: 132
    radius: 10
    color: hover.hovered ? "white" : "transparent"

    property string announcementId: ""
    property url coverSource: ""
    property string title: ""
    property string summary: ""
    property string publishTime: ""
    signal announcementRequested(string announcementId)

    // Tab 可以选中卡片，回车或空格也能打开。
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: title
    Keys.onReturnPressed: announcementRequested(announcementId)
    Keys.onSpacePressed: announcementRequested(announcementId)
    border.width: activeFocus ? 1 : 0
    border.color: "#409eff"

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: card.announcementRequested(card.announcementId) }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 16

        Rectangle {
            Layout.preferredWidth: 120
            Layout.preferredHeight: 86
            radius: 6
            color: "#e4e9ed"

            // 暂时不提供图片时显示占位文字；图片路径由首页传入。
            Image {
                id: cover
                anchors.fill: parent
                anchors.margins: 6
                source: card.coverSource
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "公告封面"
                color: "#909399"
                font.pixelSize: 12
                visible: cover.status !== Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: card.title
                font.pixelSize: 15
                color: "#303133"
                // 标题一行显示，放不下的部分变成省略号。
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: card.summary
                font.pixelSize: 12
                color: "#606266"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            Label {
                Layout.fillWidth: true
                text: card.publishTime
                font.pixelSize: 11
                color: "#909399"
                elide: Text.ElideRight
            }
        }
    }
}
