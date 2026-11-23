// 允许内部 Component 明确引用外层 readerHome 等 ID。
pragma ComponentBehavior: Bound

import QtQuick          // Rectangle 等基础界面类型
import QtQuick.Controls // Page、StackView、Dialog、Label 等控件
import QtQuick.Layouts  // ColumnLayout 和 Layout 布局属性
// 导入公共组件所在的目录，使本文件能使用 ReaderNavigation。
import "../components"

// 读者端外壳：固定导航、页面栈和账户入口。
Page {
    // 本文件中用 readerHome 引用读者端根页面。
    id: readerHome
    // 当前已打开的主页面标识，传给导航栏以显示选中状态。
    // 默认 home 对应平台首页；它只是字符串，不会自己切换页面。
    property string currentPage: "home"
    // 整个读者端内容区的浅灰背景。
    background: Rectangle { color: "#f5f6f8" }

    // 统一处理页面请求，pageName 是调用方传来的字符串，例如 "books"。
    // 导航按钮和首页的查询按钮都调用这里，避免各处重复写跳转逻辑。
    function openPage(pageName) {
        // || 表示“或者”。目前只有首页和图书大厅真正接入页面容器。
        // 只在能打开实际页面时更新选中项；其他入口仍保留原选中状态。
        if (pageName === "home" || pageName === "books")
            currentPage = pageName
        // replace() 替换页面栈顶部的页面；这里用它在两个主页面之间切换。
        // 它不会保留被替换页面的实例，因此切回图书大厅会重新创建并查询。
        if (pageName === "home")
            readerStack.replace(indexComponent)
        else if (pageName === "books")
            readerStack.replace(booksComponent)
        else {
            // 收藏、借阅目前只有文件骨架，暂时显示提示，不打开空页面。
            // 三元表达式：是 favorites 就显示“我的收藏”，否则显示“我的借阅”。
            placeholderTitle.text = pageName === "favorites" ? "我的收藏" : "我的借阅"
            placeholderDialog.open()
        }
    }

    // 从上到下排列：固定导航栏 → 剩余空间中的页面容器。
    ColumnLayout {
        // 这里的 parent 是最外层 Page，布局填满整个读者端。
        anchors.fill: parent
        // 导航与下方内容之间不额外插入布局间距。
        spacing: 0
        // 创建 ReaderNavigation.qml 定义的导航组件。
        ReaderNavigation {
            Layout.fillWidth: true
            // 左边是导航组件的属性，右边是本文件根页面的属性。
            // 这是绑定：根页面状态改变时，导航选中样式自动更新。
            currentPage: readerHome.currentPage
            // 接收导航组件的 pageRequested 信号，再把标识交给 openPage。
            // 例如点击“图书大厅”：pageName 的值就是 "books"。
            onPageRequested: function(pageName) { readerHome.openPage(pageName) }
            // 接收头像菜单操作：profile / password / logout。
            // 当前都只是提示；尚未修改密码、清除 Token 或执行真实退出。
            onAccountRequested: function(action) {
                placeholderTitle.text = action === "profile" ? "个人信息" : action === "password" ? "修改密码" : "退出登录"
                // 更新提示标题后，打开公共占位弹窗。
                placeholderDialog.open()
            }
        }
        // 页面容器：可以把它理解成一叠页面，只展示最上面的一页。
        // push 增加一页，pop 返回上一页，replace 替换顶部页面。
        StackView {
            // openPage() 通过这个 ID 找到页面容器。
            id: readerStack
            // 由外层 ColumnLayout 分配尺寸，占据导航栏之外的剩余空间。
            Layout.fillWidth: true
            Layout.fillHeight: true
            // 页面容器四周留 20 像素的布局边距。
            Layout.margins: 20
            // 初始化时根据首页模板创建页面，作为页面栈的第一项。
            initialItem: indexComponent
        }
    }
    // Component 是可供创建页面的模板，不会仅因声明就显示。
    // StackView 使用这个模板时，才创建里面的 ReaderIndexPage 实例。
    Component {
        id: indexComponent
        // 具体首页内容放在 ReaderIndexPage.qml，不写在主文件里。
        ReaderIndexPage {
            // 透明背景使外层读者端的浅灰底色能透出来。
            background: Rectangle { color: "transparent" }
            // 接收首页“查询图书”按钮的信号，复用相同的跳转方法。
            onBrowseBooksRequested: readerHome.openPage("books")
        }
    }
    // 图书大厅模板，保留 ReaderBooksPage 已有的查询功能。
    Component {
        id: booksComponent
        ReaderBooksPage {
            // 覆盖该页面的背景：白色面板，圆角半径为 12。
            background: Rectangle { color: "white"; radius: 12 }
        }
    }
    // 骨架页面尚未实现，先明确提示，避免打开后出现空白。
    Dialog {
        id: placeholderDialog
        // 弹窗在父项中居中显示。
        anchors.centerIn: parent
        // 模态弹窗打开时，阻止对后方页面的交互。
        modal: true
        // 由 Dialog 提供标准“确定”按钮，点击后接受并关闭弹窗。
        standardButtons: Dialog.Ok
        ColumnLayout {
            // 标题由上方事件处理代码赋值；下方说明文字保持不变。
            Label { id: placeholderTitle; font.pixelSize: 18 }
            Label { text: "此功能尚未实现，当前仅预览读者端外观。" }
        }
    }
}
