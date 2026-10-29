import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: readerHome

    // 是否正在显示图书查询页面
    property bool showingBooks: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // 返回按钮
        Button {
            text: "← 返回读者首页"
            visible: readerHome.showingBooks

            onClicked: readerHome.showingBooks = false
        }

        // 根据当前状态切换页面
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            sourceComponent: readerHome.showingBooks
                             ? booksPageComponent
                             : homeComponent
        }
    }

    // 读者主页
    Component {
        id: homeComponent

        ColumnLayout {
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

                onClicked: readerHome.showingBooks = true
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // 图书查询页面
    Component {
        id: booksPageComponent

        ReaderBooksPage {
        }
    }
}
