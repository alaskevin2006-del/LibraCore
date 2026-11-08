import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LibraCore.Network 1.0

// 图书管理页面page,作为一个根节点，由 AdminHome.qml 加载
// 不需要再创建 ApplicationWindow
Page {
    id: page

    // 页面状态

    property bool demoMode: false

    // 加载状态由网络模块统一维护
    readonly property bool loading: booksApi.loading

    // 错误信息，空字符串代表没有错误
    property string errorMessage: ""

    // 分页状态
    property int currentPage: 1
    property int totalPages: 0
    property int totalBooks: 0
    property string activeKeyword: ""

    // 认为表单操作提示信息
    property string formMessage: ""

    // 点击查询时，向外部发送信号
    // 后面由 dhw 的网络模块接收并处理
    // 定义一个信号（signal），名叫 booksRequested，携带一个字符串参数 keyword（也就是用户在搜索框里输入的关键词）
    // 如果Page外部绑定了这个信号，点击查询时外部就会收到通知
    signal booksRequested(string keyword)

    // ListModel 保存当前需要展示的数据，比普通数组好在界面会自动刷新
    ListModel {
        id: bookModel
    }


    // 收到图书数据后，更新列表

    // rows 应当是一个由图书对象组成的数组
    // 例如 [{title:"...",author:"...",isbn:"..."}]
    function showBooks(rows) {
        bookModel.clear()

        // BookService 返回 QVariantList。
        // 这里按可遍历序列处理，不强制要求 Array.isArray()。
        if (rows === null || rows === undefined
                || typeof rows.length !== "number") {
            showError("图书数据格式不正确")
            return
        }

        for (let i = 0; i < rows.length; i++) {
            let book = rows[i]

            bookModel.append({
                bookTitle: String(book.title ?? ""),
                author: String(book.author ?? ""),
                isbn: String(book.isbn ?? "")
            })
        }

        page.errorMessage = ""
    }

    function showError(message) {
        bookModel.clear()
        page.errorMessage = String(message)
    }



    // 查询图书

    // 刷新查询图书的函数
    // 点击查询、按回车、首次进入页面时使用。
    // 新查询默认从第一页开始。
    function refreshBooks() {
        page.activeKeyword = searchInput.text.trim()
        requestBooks(1)
    }

    // 翻页时继续使用上一次提交的关键词
    function requestBooks(pageNumber) {
        page.errorMessage = ""
        bookModel.clear()

        booksApi.search(page.activeKeyword, pageNumber, 20)
    }


    // 当组件（页面）加载完成时，自动执行 refreshBooks() 查询一次
    Component.onCompleted: refreshBooks()

    BookService {
        id: booksApi

        // 网络请求成功：更新列表和分页信息
        onBooksReceived: function(books, meta) {
            page.showBooks(books)

            page.currentPage = meta.page
            page.totalPages = meta.total_pages
            page.totalBooks = meta.total
        }

        // 网络请求失败：显示错误
        onStateChanged: {
            if (booksApi.error.length > 0) {
                page.showError(booksApi.error)
            }
        }
    }

    // 绘制界面

    ColumnLayout {
        anchors.fill: parent //布局填满整个页面
        anchors.margins: 15 //页面四周留出 15 像素的边距
        spacing: 8 // 内部元素之间的间距为 8 像素

        // 标题
        Label {
            text: "管理员 - 图书管理"
            font.pixelSize: 24 //字体大小
            font.bold: true //是否为粗体
        }

        // 查询输入框和按钮

        //RowLayout是水平布局
        RowLayout {
            Layout.fillWidth: true // 占满整行宽度

            //搜索输入框
            TextField {
                id: searchInput
                Layout.fillWidth: true // 占满整行宽度
                placeholderText: "输入书名或 ISBN"

                // 按回车也能查询
                onAccepted: page.refreshBooks()
            }

            Button {
                text: "查询"
                enabled: !page.loading// 如果正在 loading，按钮禁用（变灰）
                onClicked: page.refreshBooks() //点击时查询
            }
        }

        // 加载动画
        BusyIndicator {
            running: page.loading
            visible: page.loading
            Layout.alignment: Qt.AlignHCenter // 水平居中
        }

        // 网络错误提示
        Label {
            text: page.errorMessage
            visible: page.errorMessage !== ""
            color: "#c62828"
        }

        // 空数据提示
        Label {
            text: "暂无图书数据"
            visible: !page.loading
                     && page.errorMessage === ""
                     && bookModel.count === 0
        }

        // 当前显示的图书数量
        Label {
            text: "显示图书：" + bookModel.count + " 本"
        }

        // 表头
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



        // ListView 显示图书

         // ListView 是一个滚动列表控件
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80 //最小高度
            clip: true //裁剪超出边界的部分
            spacing: 2 //行间距

            // 指定数据模型
            model: bookModel

            // delegate 是每一行的显示模板
            delegate: Rectangle {
                id: bookRow

                // 声明从数据模型读取的字段
                required property string bookTitle
                required property string author
                required property string isbn
                required property int index

                width: ListView.view.width
                height: 44

                // 隔行显示浅灰色
                color: index % 2 === 0
                       ? "#f1f3f6" : "#ffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8

                    Label {
                        text: bookRow.bookTitle
                        Layout.preferredWidth: 210
                        elide: Text.ElideRight // 如果文字太长，末尾显示省略号
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
            }

            // 数据较多时可以滚动，显示滚动条
            ScrollBar.vertical: ScrollBar {}
        }
    }
}
