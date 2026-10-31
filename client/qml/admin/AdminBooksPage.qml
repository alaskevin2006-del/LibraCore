//部分模拟代码最后可以去掉
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 图书管理页面page,作为一个根节点，由 AdminHome.qml 加载
// 不需要再创建 ApplicationWindow
Page {
    id: page

    // 页面状态

    // 是否使用本地假数据
    property bool demoMode: true // property全局可见，属性绑定

    // 是否在加载中
    property bool loading: false

    // 错误信息，空字符串代表没有错误
    property string errorMessage: ""

    // 认为表单操作提示信息
    property string formMessage: ""

    // 点击查询时，向外部发送信号
    // 后面由 dhw 的网络模块接收并处理
    // 定义一个信号（signal），名叫 booksRequested，携带一个字符串参数 keyword（也就是用户在搜索框里输入的关键词）
    // 如果Page外部绑定了这个信号，点击查询时外部就会收到通知
    signal booksRequested(string keyword)



    // 本地模拟数据

    // var 是 QML 的一种属性类型，这里保存 JavaScript 数组
    // 定义一个名为 demoBooks 的数组，里面有三个对象，包含书名、作者、ISBN
    property var demoBooks: [
        {
            title: "C++ Primer",
            author: "Lippman",
            isbn: "9780321714114"
        },
        {
            title: "书",
            author: "hyq",
            isbn: "001"
        },
        {
            title: "书书",
            author: "hyqqq",
            isbn: "002"
        }
    ]

    // ListModel 保存当前需要展示的数据，比普通数组好在界面会自动刷新
    ListModel {
        id: bookModel
    }


    // 收到图书数据后，更新列表

    // rows 应当是一个由图书对象组成的数组
    // 例如 [{title:"...",author:"...",isbn:"..."}]
    function showBooks(rows) {
        // 先清空旧的显示数据
        bookModel.clear()

        // 确保传入的是数组
        if (!Array.isArray(rows)) {
            showError("图书数据格式不正确")
            return
        }

        // 遍历返回的每一本书
        for (let i = 0; i < rows.length; i++) {
            let book = rows[i]

            // append 的作用与 C++ vector 的push_back 相似
            bookModel.append({
                bookTitle: String(book.title ?? ""),
                author: String(book.author ?? ""),
                isbn: String(book.isbn ?? "")
            })
        }

        // 数据处理完成，关闭加载提示
        page.loading = false
        page.errorMessage = ""
    }

    // 请求失败时调用的函数
    function showError(message) {
        page.loading = false //停止加载
        bookModel.clear() //清空列表
        page.errorMessage = String(message) // 设置错误信息
    }



    // 查询图书

    // 刷新查询图书的函数
    function refreshBooks() {
        // 获取搜索框里的文字，去掉首尾空格
        let keyword = searchInput.text.trim()

        // 开始新请求，清除旧的加载状态、错误消息、列表
        page.loading = true
        page.errorMessage = ""
        bookModel.clear()

        if (page.demoMode) {
            // 演示模式：从本地数组筛选
            let key = keyword.toLowerCase() // 搜索关键词转为小写

            let result = page.demoBooks.filter(
                function(book) {
                    return book.title.toLowerCase().includes(key)
                           || book.isbn.includes(key)
                }
            )

            // 将查询结果交给显示函数
            showBooks(result)
        } else {
            // 真实模式：发出bookRequested 信号，通知外部网络模块去请求数据
            // 现在还没有实际连接它
            booksRequested(keyword)
        }
    }



    // 模拟新增图书

    //添加模拟图书的函数
    function addDemoBook() {
        // 还没有真实添加图书，只是学习基础表单和输入校验
        if (!page.demoMode) {
            return
        }

        //获取三个输入框的文字，去掉空格
        let title = titleInput.text.trim()
        let author = authorInput.text.trim()
        let isbn = isbnInput.text.trim()

        // 检查有没有漏填
        if (title === "" || author === "" || isbn === "") {
            page.formMessage = "请填写完整的图书信息"
            return
        }

        // 简单检查 ISBN 是否重复
        for (let i = 0; i < page.demoBooks.length; i++) {
            if (page.demoBooks[i].isbn === isbn) {
                page.formMessage = "ISBN 已存在（本地演示）"
                return
            }
        }

        // 向本地数组添加一本书
        page.demoBooks.push({
            title: title,
            author: author,
            isbn: isbn
        })

        // 清空输入内容
        titleInput.text = ""
        authorInput.text = ""
        isbnInput.text = ""

        page.formMessage = "模拟添加成功，未写入数据库"

        // 清除搜索条件，再刷新列表
        searchInput.text = ""
        refreshBooks()
    }

    // 当组件（页面）加载完成时，自动执行 refreshBooks() 查询一次
    Component.onCompleted: refreshBooks()



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

        // 提示标签，只有当 demoMode 为 true 时才可见
        Label {
            visible: page.demoMode
            text: "当前为本地演示模式，未连接数据库"
            color: "#a66a00"
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

        // 下面这组按钮只用于测试页面状态
        // 真实联网完成后可以隐藏
        RowLayout {
            visible: page.demoMode
            Layout.fillWidth: true

            Button {
                text: "测试空数据"
                onClicked: page.showBooks([])
            }

            Button {
                text: "测试加载"
                onClicked: {
                    bookModel.clear()
                    page.errorMessage = ""
                    page.loading = true
                }
            }

            Button {
                text: "测试失败"
                onClicked: page.showError(
                    "模拟错误：服务器连接失败"
                )
            }

            Button {
                text: "恢复数据"
                onClicked: page.refreshBooks()
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



        //本地新增图书表单

        // GroupBox 是带标题边框的盒子
        GroupBox {
            title: "新增图书表单（演示）"
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    TextField {
                        id: titleInput
                        placeholderText: "书名"
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: authorInput
                        placeholderText: "作者"
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: isbnInput
                        placeholderText: "ISBN"
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "模拟添加"
                        enabled: page.demoMode
                        onClicked: page.addDemoBook()
                    }
                }

                Label {
                    text: page.formMessage
                    color: "#b00020"
                    visible: page.formMessage !== ""
                }
            }
        }
    }
}
