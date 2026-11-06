import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 10

    // 对外提供搜索关键字
    property alias keyword: searchInput.text

    // 用户发起搜索时，通知外部页面
    signal searchRequested(string keyword)

    TextField {
        id: searchInput

        Layout.fillWidth: true
        placeholderText: "请输入书名或 ISBN"

        // 按回车搜索
        onAccepted: root.searchRequested(text.trim())
    }

    Button {
        text: "查询"

        // 点击按钮搜索
        onClicked: root.searchRequested(searchInput.text.trim())
    }
}