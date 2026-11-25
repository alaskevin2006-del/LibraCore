pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// 平台首页；导航栏在外层 ReaderHome 中，不会随首页内容滚动。
Page {
    id: indexPage
    signal browseBooksRequested()

    // 将当前公告的完整数据交给外层；页面栈由 ReaderHome 管理。
    signal announcementRequested(var announcement)
    // 模拟公告数据，封面路径暂时留空；后续再替换成接口数据。
    property var announcements: [
        { id: "1", title: "入馆须知", summary: "请保持安静，爱护馆藏，共同维护整洁舒适的阅读环境。", cover: "", time: "2026-11-23", body: "亲爱的读者：\n\n欢迎来到 LibraCore 图书馆。进入阅览区域后，请保持安静，将手机调至静音模式。\n\n请爱护公共设施与馆藏图书，保持座位及周边环境整洁。离馆前请带好随身物品。\n\n感谢你的理解与配合。\n\n（以上为界面演示内容，正式公告以后端发布为准。）" },
        { id: "2", title: "图书借阅温馨提示", summary: "借阅前请核对书目信息，归还请到服务台由管理员办理。", cover: "", time: "2026-11-22", body: "亲爱的读者：\n\n借阅前，请核对图书名称及可借数量。在图书详情页确认借阅后，可到“我的借阅”查看记录。\n\n归还请到服务台由管理员办理，办理后重新查询借阅记录及可借数量。具体借期和应还日期以后续确认的系统规则为准。\n\n（以上为界面演示内容。）" },
        { id: "3", title: "本月新书上架通知", summary: "文学、历史与科学类新书已上架，欢迎前往图书大厅查看。", cover: "", time: "2026-11-21", body: "亲爱的读者：\n\n本月新增文学、历史与科学类图书。欢迎前往图书大厅，通过分类或书名搜索寻找感兴趣的书籍。\n\n实际馆藏、可借数量及上架情况，请以图书大厅返回的信息为准。\n\n（以上为模拟上新公告，不代表真实馆藏变更。）" },
        { id: "4", title: "文明阅读倡议", summary: "轻拿轻放，不折页、不涂画，让好书与更多读者相遇。", cover: "", time: "2026-11-20", body: "亲爱的读者：\n\n一本好书可以陪伴很多人。阅读时请轻拿轻放，不折页、不涂画；如发现图书破损，请向工作人员反馈。\n\n请保持安静，不在阅览区域追逐打闹。让我们共同维护舒适的阅读环境。\n\n（以上为界面演示内容。）" }
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
                            id: announcementCard
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
                                // 卡片只报告 ID；它的数据对象中还包含详情所需的正文。
                                // 同时传出数据，外层就不必依赖首页内部的 Repeater。
                                indexPage.announcementRequested(announcementCard.modelData)
                            }
                        }
                    }
                }

            }
        }
    }
}
