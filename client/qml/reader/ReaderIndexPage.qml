pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// 平台首页；导航栏在外层 ReaderHome 中，不会随首页内容滚动。
Page {
    id: indexPage
    signal browseBooksRequested()
    // 模拟公告数据，封面路径暂时留空；后续再替换成接口数据。
    property var announcements: [
        { id: "1", title: "入馆须知", summary: "请保持安静，爱护馆藏，共同维护整洁舒适的阅读环境。", cover: "", time: "2026-11-23" },
        { id: "2", title: "图书借阅温馨提示", summary: "借阅前请核对书目信息，归还请到服务台由管理员办理。", cover: "", time: "2026-11-22" },
        { id: "3", title: "本月新书上架通知", summary: "文学、历史与科学类新书已上架，欢迎前往图书大厅查看。", cover: "", time: "2026-11-21" },
        { id: "4", title: "文明阅读倡议", summary: "轻拿轻放，不折页、不涂画，让好书与更多读者相遇。", cover: "", time: "2026-11-20" }
    ]
    background: Rectangle { color: "transparent" }

    ScrollView {
        id: homeScroll
        anchors.fill: parent
        clip: true

        // 内容宽度跟随可用宽度，不出现横向滚动条。
        contentWidth: availableWidth
        contentHeight: contentArea.height
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Item {
            id: contentArea
            width: homeScroll.availableWidth
            // 至少填满视口；未来轮播、公告超出视口后自然形成长页面。
            height: Math.max(homeScroll.availableHeight, homeContent.implicitHeight + 48)

            ColumnLayout {
                id: homeContent
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                // 宽屏最多 1200，两侧保留空白；窄屏时跟随窗口收窄。
                width: Math.max(0, Math.min(1200, parent.width - 48))
                spacing: 20

                // 轮播组件由首页布局分配宽度，高度参考组件的 implicitHeight。
                BookCarousel {
                    Layout.fillWidth: true
                    // 模拟轮播数据，后续由接口提供标题和关联图书。
                    banners: [
                        { title: "精选推荐 · 文学", color: "#dce6ed", imageSource: "", bookId: "1" },
                        { title: "精选推荐 · 科学", color: "#dce8dc", imageSource: "", bookId: "2" },
                        { title: "精选推荐 · 历史", color: "#e8ddcf", imageSource: "", bookId: "3" }
                    ]
                }

                // 轮播下方展示公告标题和两列卡片。
                Label {
                    Layout.fillWidth: true
                    text: "图书管理规则公告"
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width < 700 ? 1 : 2
                    columnSpacing: 24
                    rowSpacing: 12

                    Repeater {
                        model: indexPage.announcements
                        delegate: AnnouncementCard {
                            required property var modelData
                            Layout.fillWidth: true
                            // 所有列等宽，避免标题长短影响布局。
                            Layout.preferredWidth: 1
                            announcementId: modelData.id
                            coverSource: modelData.cover
                            title: modelData.title
                            summary: modelData.summary
                            publishTime: modelData.time
                            onAnnouncementRequested: function(announcementId) {
                                noticeDialog.title = title
                                noticeDialog.open()
                            }
                        }
                    }
                }

            }
        }
    }
    // 先说明这是演示入口，下一步再接入独立的公告详情页。
    Dialog {
        id: noticeDialog
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok
        Label { text: "当前为模拟公告，详情页面尚未接入。" }
    }
}
