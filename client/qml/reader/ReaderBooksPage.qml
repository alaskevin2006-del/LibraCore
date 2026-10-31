import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import LibraCore.Network 1.0

Page {
    id: readerBooksPage
    // 当前选中的图书信息
    property string selectedTitle: ""
    property string selectedAuthor: ""
    property string selectedIsbn: ""

    // 页面创建完成后，显示全部图书
    Component.onCompleted: {
        searchBooks("")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // 1. 页面标题
        Label {
            text: "图书查询"
            font.pixelSize: 24
            font.bold: true
        }

        // 2. 公共搜索组件
        BookSearchBar {
            id: searchBar
            Layout.fillWidth: true
            onSearchRequested: function(keyword) { searchBooks(keyword) }
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: booksApi.loading
            visible: running
        }
        Label {
            Layout.fillWidth: true
            visible: booksApi.error.length > 0
            text: booksApi.error
            wrapMode: Text.Wrap
        }
        Button {
            visible: booksApi.error.length > 0
            text: "重试"
            onClicked: searchBooks(activeKeyword, currentPage)
        }
        RowLayout {
            Button {
                text: "上一页"
                enabled: !booksApi.loading && booksApi.error.length === 0 && currentPage > 1
                onClicked: searchBooks(activeKeyword, currentPage - 1)
            }
            Label { text: currentPage + " / " + totalPages }
            Button {
                text: "下一页"
                enabled: !booksApi.loading && booksApi.error.length === 0 && currentPage < totalPages
                onClicked: searchBooks(activeKeyword, currentPage + 1)
            }
        }
        // 3. 公共图书列表组件
        BookListView {
            id: bookList
            Layout.fillWidth: true
            Layout.fillHeight: true

            visible: !booksApi.loading && booksApi.error.length === 0
            bookModel: visibleBooks

            // 接收图书被点击的信号
            onBookClicked: function(index) {

                // 根据下标获取当前点击的图书
                let book = visibleBooks.get(index)

                // 保存图书信息
                readerBooksPage.selectedTitle = book.bookTitle
                readerBooksPage.selectedAuthor = book.author
                readerBooksPage.selectedIsbn = book.isbn

                // 打开图书详情弹窗
                bookDetailDialog.open()
            }
        }
    }

    property int currentPage: 1
    property int totalPages: 0
    property string activeKeyword: ""
    ListModel { id: visibleBooks }
    BookService {
        id: booksApi
        onBooksReceived: function(books, meta) {
            visibleBooks.clear()
            for (let book of books) visibleBooks.append(book)
            currentPage = meta.page
            totalPages = meta.total_pages
        }
    }
    function searchBooks(keyword, page = 1) {
        activeKeyword = keyword
        visibleBooks.clear()
        booksApi.search(keyword, page, 20)
    }
    // 图书详情弹窗
    Dialog {
        id: bookDetailDialog

        title: "图书详情"

        anchors.centerIn: parent

        width: 400

        modal: true

        standardButtons: Dialog.Ok

        ColumnLayout {
            spacing: 15

            Label {
                text: "书名：" + readerBooksPage.selectedTitle
                font.pixelSize: 18
                font.bold: true
            }

            Label {
                text: "作者：" + readerBooksPage.selectedAuthor
                font.pixelSize: 16
            }

            Label {
                text: "ISBN：" + readerBooksPage.selectedIsbn
                font.pixelSize: 16
            }
        }
    }
}
