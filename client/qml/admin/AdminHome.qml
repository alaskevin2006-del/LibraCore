import QtQuick // 基础页面组件。
import QtQuick.Controls // 页面、按钮和 Loader 使用的控件。
import QtQuick.Layouts // 自动布局。

Page { // 管理员首页与两个业务页面的导航容器。
    id: adminHome // 导航状态所属对象。
    property string currentSection: "home" // home、books、readers 对应首页、图书、读者。
    readonly property var activePage: pageLoader.item // Loader 可加载不同页面，用动态类型访问公共 saving 属性。
    readonly property bool childSaving: activePage ? Boolean(activePage.saving) : false // 写请求期间禁止在此导航销毁业务页面。

    ColumnLayout { // 纵向安排导航与内容。
        anchors.fill: parent // 占满页面。
        anchors.margins: 15 // 页面边距。
        spacing: 10 // 控件间距。
        Flow { // 窄窗口下导航可自动换行。
            Layout.fillWidth: true // 导航占满宽度。
            spacing: 8 // 按钮间隔。
            enabled: !adminHome.childSaving // 提交未结束时保留页面和响应处理器。
            Button { text: "管理员首页"; onClicked: adminHome.currentSection = "home" } // 返回欢迎页。
            Button { text: "图书管理"; onClicked: adminHome.currentSection = "books" } // 打开现有图书 CRUD。
            Button { text: "读者管理"; onClicked: adminHome.currentSection = "readers" } // 打开新读者 CRUD。
        } // 导航结束。
        Loader { // 只实例化当前业务页面。
            id: pageLoader // 提供当前页面实例。
            Layout.fillWidth: true // 内容占满宽度。
            Layout.fillHeight: true // 内容占用剩余高度。
            sourceComponent: adminHome.currentSection === "books" ? booksComponent : adminHome.currentSection === "readers" ? readersComponent : homeComponent // 根据状态选择页面模板。
        } // 页面加载器结束。
    } // 页面布局结束。

    Component { // 首页模板。
        id: homeComponent // 默认欢迎页。
        Item { // 普通内容容器。
            property bool saving: false // 首页没有写请求，允许导航。
            ColumnLayout { // 居中显示欢迎文字和说明。
                anchors.centerIn: parent // 在可用内容区居中。
                width: parent.width // 使用可用宽度。
                spacing: 20 // 文字间距。
                Label { text: "欢迎进入管理员端"; font.pixelSize: 28; Layout.alignment: Qt.AlignHCenter } // 欢迎标题。
                Label { text: "通过上方入口管理图书与读者；写操作需要管理员登录。"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap } // 解释功能及公共登录依赖。
            } // 欢迎内容结束。
        } // 首页内容结束。
    } // 首页模板结束。
    Component { id: booksComponent; AdminBooksPage {} } // 复用图书页面，不修改其网络层。
    Component { id: readersComponent; AdminReadersPage {} } // 读者页面由 CMake 注册到同一模块。
} // 管理员导航页面结束。
