import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Page 表示一个页面，不是整个程序窗口
// 以后由管理员首页负责打开这个页面
Page {
    id: page

    // ==================================================
    // 一、保存图书数据
    // ==================================================

    // ListModel 可以理解为保存多条图书记录的容器
    // 每个 ListElement 代表一本书
    ListModel {
        id: allBooks

        ListElement {
            bookTitle: "C++ Primer"
            author: "Lippman"
            isbn: "9780321714114"
        }

        ListElement {
            bookTitle: "Qt 入门"
            author: "作者A"
            isbn: "001"
        }

        ListElement {
            bookTitle: "数据结构"
            author: "作者B"
            isbn: "002"
        }
    }

    // 保存当前应该显示的图书
    // 搜索后，不一定需要显示全部图书
    ListModel {
        id: visibleBooks
    }

    // ==================================================
    // 二、查询图书
    // ==================================================

    // function 表示定义函数，和 C++ 函数类似
    function searchBooks() {

        // 先清空之前的查询结果
        visibleBooks.clear()

        // 获取用户输入的关键字
        // trim() 删除字符串首尾的空格
        // toLowerCase() 将英文变成小写，方便搜索
        let keyword = searchInput.text.trim().toLowerCase()

        // 遍历所有图书
        // 写法和 C++ 中的 for 循环非常相似
        for (let i = 0; i < allBooks.count; i++) {

            // get(i) 获取第 i 本书的数据
            let book = allBooks.get(i)

            // 判断书名或 ISBN 是否包含搜索关键字
            if (book.bookTitle.toLowerCase().includes(keyword)
                || book.isbn.includes(keyword)) {

                // 找到符合条件的图书后
                // 将其添加到显示列表中
                visibleBooks.append({
                    bookTitle: book.bookTitle,
                    author: book.author,
                    isbn: book.isbn
                })
            }
        }
    }

    // ==================================================
    // 三、新增一本模拟图书
    // ==================================================

    function addBook() {

        // 获取三个输入框的内容
        let title = titleInput.text.trim()
        let author = authorInput.text.trim()
        let isbn = isbnInput.text.trim()

        // 检查是否存在空输入
        if (title === "" || author === "" || isbn === "") {
            messageLabel.text = "请填写完整的图书信息"
            return
        }

        // 添加图书到本地数据模型
        // 注意：这里只改本地数据，不会写入 MySQL
        allBooks.append({
            bookTitle: title,
            author: author,
            isbn: isbn
        })

        // 清空搜索框，使新增图书能够显示出来
        searchInput.text = ""

        // 重新生成显示列表
        searchBooks()

        // 添加成功后清空三个输入框
        titleInput.text = ""
        authorInput.text = ""
        isbnInput.text = ""

        // 更新页面提示
        messageLabel.text = "模拟添加成功（未保存到数据库）"
    }

    // 页面创建完成后执行一次搜索
    // 因为空关键字匹配所有书，所以先显示全部图书
    Component.onCompleted: searchBooks()

    // ==================================================
    // 四、界面布局
    // ==================================================

    // ColumnLayout 将控件从上往下排列
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // 页面标题
        Label {
            text: "管理员 - 图书管理"
            font.pixelSize: 26
            font.bold: true
        }

        // 提醒用户目前使用的是模拟数据
        Label {
            text: "当前为本地演示数据，尚未连接数据库"
            color: "#a66a00"
        }

        // 查询栏：输入框和按钮横向排列
        RowLayout {
            Layout.fillWidth: true

            TextField {
                id: searchInput
                placeholderText: "请输入书名或 ISBN"

                // 自动填充横向剩余空间
                Layout.fillWidth: true

                // 在输入框按回车时也可以查询
                onAccepted: page.searchBooks()
            }

            Button {
                text: "查询"

                // 按钮点击后执行查询函数
                onClicked: page.searchBooks()
            }
        }

        // 图书数量
        Label {
            text: "当前显示：" + visibleBooks.count
                  + " 本 / 总计：" + allBooks.count + " 本"
        }

        // 图书列表的表头
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

        // ==================================================
        // 五、使用 ListView 显示图书
        // ==================================================

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 超出列表显示区域的内容会被裁剪
            clip: true

            // 数据来源是前面定义的 visibleBooks
            model: visibleBooks

            // delegate 决定每一行如何显示
            delegate: Rectangle {
                id: bookRow

                // 声明每一行需要使用的字段
                // 这些字段来自 ListModel
                required property string bookTitle
                required property string author
                required property string isbn
                required property int index

                width: ListView.view.width
                height: 50

                // 偶数行浅灰色，奇数行白色
                color: index % 2 === 0 ? "#f1f3f6" : "white"

                // 每一行内部使用横向布局
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
            }

            // 数据很多时可以滚动
            ScrollBar.vertical: ScrollBar {}
        }

        // 查询没有结果时显示提示
        Label {
            text: "没有找到符合条件的图书"
            visible: visibleBooks.count === 0
        }

        // ==================================================
        // 六、模拟新增图书表单
        // ==================================================

        Label {
            text: "新增图书（本地演示）"
            font.pixelSize: 20
            font.bold: true
        }

        // 输入书名
        TextField {
            id: titleInput
            placeholderText: "请输入书名"
            Layout.fillWidth: true
        }

        // 输入作者
        TextField {
            id: authorInput
            placeholderText: "请输入作者"
            Layout.fillWidth: true
        }

        // 输入 ISBN
        TextField {
            id: isbnInput
            placeholderText: "请输入 ISBN"
            Layout.fillWidth: true
        }

        // 模拟添加按钮
        Button {
            text: "添加图书（演示）"
            onClicked: page.addBook()
        }

        // 提示操作成功或者失败
        Label {
            id: messageLabel
            text: ""
            color: "#b00020"
        }
    }
}
