
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Page 表示一个页面
// 这个页面由 Main.qml 负责加载
Page {
    id: adminHome

    // 给当前页面声明一个布尔属性，表示是否正在显示图书管理页面
    // false：管理员首页
    // true：图书管理页面
    property bool showingBooks: false

    // ColumnLayout：将内部控件从上到下排列
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // 顶部横向布局
        RowLayout {
            Layout.fillWidth: true

            // 返回按钮
            Button {
                text: "返回管理员首页"

                // 只有打开图书管理页面时才显示
                visible: adminHome.showingBooks

                onClicked: {
                    // 修改变量，让页面切回管理员首页
                    adminHome.showingBooks = false
                }
            }

            // 显示当前页面标题
            Label {
                text: adminHome.showingBooks
                      ? "图书管理" : "管理员首页"

                font.pixelSize: 22
                font.bold: true
                Layout.fillWidth: true
            }
        }

        // Loader：根据需要加载不同的页面组件
        Loader {
            id: pageLoader

            // 占据顶部导航栏以外的剩余空间
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 根据 showingBooks 的值决定显示哪个组件
            // showingBooks == true：加载图书管理组件。
            // showingBooks == false：加载管理员首页组件。
            sourceComponent: adminHome.showingBooks
                             ? booksComponent : homeComponent
        }
    }

    // =================================================
    // 管理员首页
    // =================================================

    // Component 定义一个可以被 Loader 加载的组件
    Component {
        id: homeComponent

        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Label {
                    text: "欢迎进入管理员端"
                    font.pixelSize: 28
                    Layout.alignment: Qt.AlignHCenter
                }

                // 打开图书管理页面的按钮
                Button {
                    text: "图书管理"

                    Layout.preferredWidth: 180
                    Layout.alignment: Qt.AlignHCenter

                    onClicked: {
                        // 改成 true 后，Loader 自动显示图书页面
                        adminHome.showingBooks = true
                    }
                }
            }
        }
    }

    // =================================================
    // 图书管理页面
    // =================================================

    Component {
        // Component 可以理解为提前定义好的一个界面模板
        // 告诉 Qt：需要图书管理页面时，可以创建这个组件
        id: booksComponent

        // 这里调用你自己创建的 QML 组件
        AdminBooksPage {
        }
    }
}
