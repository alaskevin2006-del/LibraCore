// 让 delegate 等内部组件能够明确访问外层的 navigation ID。
pragma ComponentBehavior: Bound

import QtQuick          // Rectangle、Item、Text 等基础界面类型
import QtQuick.Controls // Button、Menu、MenuItem 等交互控件
import QtQuick.Layouts  // RowLayout 和 Layout 布局属性

// 只负责显示和发出信号；页面切换由 ReaderHome 处理。
Rectangle {
    // id 仅用于当前 QML 组件内部引用，不是外部访问用的属性。
    id: navigation
    // 默认期望高度；外部 RowLayout/ColumnLayout 可据此分配空间。
    implicitHeight: 64
    color: "white"
    // 输入：由 ReaderHome 绑定当前页面标识，用来控制文字和下划线。
    property string currentPage: "home"
    // 输入：账户按钮显示的名字，目前使用默认值，后续可绑定登录用户。
    property string displayName: "读者"
    // 输出：只通知外层“想打开哪个页面”，本组件不操作 StackView。
    signal pageRequested(string pageName)
    // 输出：profile / password / logout，由外层决定如何处理。
    signal accountRequested(string action)

    // 第一层横向布局：品牌 → 导航按钮组 → 弹性空白 → 账户菜单。
    RowLayout {
        // 外层是普通 Rectangle，所以用 anchors 填满它。
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 24

        // 品牌也作为按钮，点击时请求回到首页。
        Button {
            text: "▥  LibraCore"
            font.pixelSize: 20
            font.bold: true
            flat: true
            onClicked: navigation.pageRequested("home")
        }

        // 第二层横向布局只管理四个导航按钮，按钮之间不留空隙。
        RowLayout {
            Layout.fillHeight: true
            spacing: 0
            // 遍历 model，每条数据创建一个 delegate 按钮。
            Repeater {
                // key 是程序使用的页面标识，label 是界面上的中文文字。
                model: [
                    { key: "home", label: "平台首页" },
                    { key: "books", label: "图书大厅" },
                    { key: "favorites", label: "我的收藏" },
                    { key: "loans", label: "我的借阅" }
                ]
                delegate: Button {
                    id: navButton
                    // 接收 Repeater 当前这条数据，如 { key: "books", label: "图书大厅" }。
                    required property var modelData
                    // 由父 RowLayout 管理尺寸，避免同时用 anchors 定位这个按钮。
                    Layout.fillHeight: true
                    // 期望宽度为 100，不代表任何窗口尺寸下都强制固定为 100。
                    Layout.preferredWidth: 100
                    text: modelData.label
                    font.pixelSize: 14
                    // 替换按钮默认内容，用自己的 Text 实现居中和选中颜色。
                    contentItem: Text {
                        text: navButton.text
                        font: navButton.font
                        // 三元表达式：当前按钮被选中时为蓝色，否则为灰色。
                        // 属性绑定会随 currentPage 自动更新，不需要手动刷新。
                        color: navigation.currentPage === navButton.modelData.key ? "#409eff" : "#606266"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 替换按钮默认背景：悬停变浅灰，选中时显示底部蓝线。
                    background: Rectangle {
                        color: navButton.hovered ? "#f5f7fa" : "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: "#409eff"
                            visible: navigation.currentPage === navButton.modelData.key
                        }
                    }
                    // 发出信号；外层通过 onPageRequested 接收页面标识。
                    onClicked: navigation.pageRequested(modelData.key)
                }
            }
        }
        // 不绘制内容的弹性占位，把账户按钮推到最右侧。
        Item { Layout.fillWidth: true }
        Button {
            id: accountButton
            text: navigation.displayName + "  ▾"
            flat: true
            // popup() 打开菜单；y 属性把菜单放在账户按钮下方。
            onClicked: accountMenu.popup()
            Menu {
                id: accountMenu
                y: accountButton.height
                MenuItem { text: "个人信息"; onTriggered: navigation.accountRequested("profile") }
                MenuItem { text: "修改密码"; onTriggered: navigation.accountRequested("password") }
                // 分隔一般账户操作和退出操作。
                MenuSeparator {}
                MenuItem { text: "退出登录"; onTriggered: navigation.accountRequested("logout") }
            }
        }
    }
    // 顶栏底部的一像素分割线。
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#ebeef5" }
}
