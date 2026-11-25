import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 公告详情只负责显示；数据传入和页面跳转由外层 ReaderHome 管理。
Page {
    id: announcementPage

    // Page 自带 title 属性，无需重复声明，外部可设置 title: "入馆须知"。
    title: "公告详情"
    property string announcementId: ""
    property string publishTime: ""
    property string bodyText: ""

    // 返回按钮只通知外层，不在此处直接访问其他文件的 StackView。
    signal backRequested()

    background: Rectangle { color: "transparent" }

    ScrollView {
        id: detailScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: contentArea.height
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Item {
            id: contentArea
            width: detailScroll.availableWidth
            // 正文较长时撑高整个内容区，超出视口后即可滚动。
            height: Math.max(detailScroll.availableHeight, pageContent.implicitHeight + 48)

            ColumnLayout {
                id: pageContent
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, Math.min(1000, parent.width - 48))
                spacing: 16

                Button {
                    text: "← 返回首页"
                    flat: true
                    onClicked: announcementPage.backRequested()
                }

                // 白色圆角面板高度由内部文字决定，不把正文限制在固定高度内。
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: articleContent.implicitHeight + 64
                    radius: 12
                    color: "white"

                    ColumnLayout {
                        id: articleContent
                        anchors.top: parent.top
                        anchors.topMargin: 32
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 32
                        anchors.rightMargin: 32
                        spacing: 20

                        Label {
                            Layout.fillWidth: true
                            text: announcementPage.title
                            textFormat: Text.PlainText
                            font.pixelSize: 24
                            font.bold: true
                            color: "#303133"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: announcementPage.publishTime.length > 0
                            text: "发布时间：" + announcementPage.publishTime
                            font.pixelSize: 12
                            color: "#909399"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: "#ebeef5"
                        }

                        Label {
                            Layout.fillWidth: true
                            // 当前按纯文本展示，换行使用 \n；不自动解析 HTML 标签。
                            text: announcementPage.bodyText.length > 0
                                  ? announcementPage.bodyText : "暂无公告正文"
                            textFormat: Text.PlainText
                            font.pixelSize: 15
                            color: "#606266"
                            wrapMode: Text.Wrap
                            lineHeight: 1.7
                        }
                    }
                }
            }
        }
    }
}
