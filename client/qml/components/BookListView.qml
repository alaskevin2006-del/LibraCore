import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 8

    // 外部页面传入图书数据
    property var bookModel: null

    // 用户点击图书时发出信号
    signal bookClicked(int index)

    RowLayout {
        Layout.fillWidth: true

        Label {
            text: "书名"
            font.bold: true
            Layout.preferredWidth: 220
        }

        Label {
            text: "作者"
            font.bold: true
            Layout.preferredWidth: 150
        }

        Label {
            text: "ISBN"
            font.bold: true
            Layout.fillWidth: true
        }
    }

    ListView {
        id: listView

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true
        model: root.bookModel

        delegate: Rectangle {
            id: bookRow

            required property string bookTitle
            required property string author
            required property string isbn
            required property int index

            width: ListView.view.width
            height: 50

            color: index % 2 === 0 ? "#f1f3f6" : "white"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                Label {
                    text: bookRow.bookTitle
                    Layout.preferredWidth: 210
                    elide: Text.ElideRight
                }

                Label {
                    text: bookRow.author
                    Layout.preferredWidth: 140
                    elide: Text.ElideRight
                }

                Label {
                    text: bookRow.isbn
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.bookClicked(bookRow.index)
            }
        }

        ScrollBar.vertical: ScrollBar {}
    }

    Label {
        text: "没有找到符合条件的图书"
        visible: listView.count === 0
    }
}