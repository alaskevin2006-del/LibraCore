import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// 导入我们自己创建的两个页面目录
import "reader"
import "admin"

ApplicationWindow {
    id: window

    width: 900
    height: 600
    minimumWidth: 600
    minimumHeight: 400

    visible: true
    title: "LibraCore 图书馆管理系统"

    // 整个主窗口采用垂直布局
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 顶部导航栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60

            color: "#2c3e50"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 15

                // 系统名称
                Label {
                    text: "LibraCore"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"

                    Layout.fillWidth: true
                }

                // 读者端按钮
                Button {
                    text: "读者端"

                    onClicked: {
                        stackView.replace(readerPage)
                    }
                }

                // 管理员端按钮
                Button {
                    text: "管理员端"

                    onClicked: {
                        stackView.replace(adminPage)
                    }
                }
            }
        }

        // 页面显示区域
        StackView {
            id: stackView

            Layout.fillWidth: true
            Layout.fillHeight: true

            // 程序启动时默认显示读者端
            initialItem: readerPage
        }
    }

    // 读者端页面组件
    Component {
        id: readerPage

        ReaderHome {
        }
    }

    // 管理员端页面组件
    Component {
        id: adminPage

        AdminHome {
        }
    }
}