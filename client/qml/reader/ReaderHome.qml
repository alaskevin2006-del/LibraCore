pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// 读者端外壳：固定导航、页面栈和账户入口。
Page {
    id: readerHome
    property string currentPage: "home"
    background: Rectangle { color: "#f5f6f8" }

    function openPage(pageName) {
        if (pageName === "home" || pageName === "books")
            currentPage = pageName
        if (pageName === "home")
            readerStack.replace(indexComponent)
        else if (pageName === "books")
            readerStack.replace(booksComponent)
        else {
            placeholderTitle.text = pageName === "favorites" ? "我的收藏" : "我的借阅"
            placeholderDialog.open()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        ReaderNavigation {
            Layout.fillWidth: true
            currentPage: readerHome.currentPage
            onPageRequested: function(pageName) { readerHome.openPage(pageName) }
            onAccountRequested: function(action) {
                placeholderTitle.text = action === "profile" ? "个人信息" : action === "password" ? "修改密码" : "退出登录"
                placeholderDialog.open()
            }
        }
        StackView {
            id: readerStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            initialItem: indexComponent
        }
    }
    Component {
        id: indexComponent
        ReaderIndexPage {
            background: Rectangle { color: "transparent" }
            onBrowseBooksRequested: readerHome.openPage("books")
        }
    }
    Component {
        id: booksComponent
        ReaderBooksPage {
            background: Rectangle { color: "white"; radius: 12 }
        }
    }
    // 骨架页面尚未实现，先明确提示，避免打开后出现空白。
    Dialog {
        id: placeholderDialog
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok
        ColumnLayout {
            Label { id: placeholderTitle; font.pixelSize: 18 }
            Label { text: "此功能尚未实现，当前仅预览读者端外观。" }
        }
    }
}
