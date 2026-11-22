import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 平台首页；后续添加推荐轮播和公告。
Page {
    id: indexPage
    signal browseBooksRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        Item {
            Layout.fillHeight: true
        }

        Label {
            text: "欢迎使用 LibraCore 图书管理系统"
            font.pixelSize: 28
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            text: "查询图书"
            Layout.alignment: Qt.AlignHCenter

            onClicked: indexPage.browseBooksRequested()
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
