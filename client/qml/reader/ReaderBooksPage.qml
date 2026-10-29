import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

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
        }

        // 3. 公共图书列表组件
        BookListView {
            id: bookList
            Layout.fillWidth: true
            Layout.fillHeight: true

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

    // 4. 模拟图书数据
    ListModel {
        id: allBooks
        ListElement {
            bookTitle: "C++ Primer"
            author: "Stanley B. Lippman"
            isbn: "9780321714114"
        }

        ListElement {
            bookTitle: "Java 核心技术"
            author: "Cay S. Horstmann"
            isbn: "9780137673629"
        }

        ListElement {
            bookTitle: "深入理解计算机系统"
            author: "Randal E. Bryant"
            isbn: "9780134092669"
        }
    }
    ListModel {
        id: visibleBooks
    }
    function searchBooks(keyword) {

        // 先清空上一次的搜索结果
        visibleBooks.clear()

        // 去除关键词两端空格，并统一转成小写
        keyword = keyword.trim().toLowerCase()

        // 遍历所有图书
        for (let i = 0; i < allBooks.count; i++) {

            // 获取第 i 本图书
            let book = allBooks.get(i)

            // 判断书名或 ISBN 是否包含关键词
            if (book.bookTitle.toLowerCase().includes(keyword)
                    || book.isbn.includes(keyword)) {

                // 将符合条件的图书加入显示模型
                visibleBooks.append({
                    bookTitle: book.bookTitle,
                    author: book.author,
                    isbn: book.isbn
                })
            }
        }
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