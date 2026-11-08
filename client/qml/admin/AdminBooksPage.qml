import QtQuick // 导入基础界面类型和 ListModel。
import QtQuick.Controls // 导入页面、按钮、标签等控件。
import QtQuick.Layouts // 导入横向和纵向布局。
import "../components" // 与读者端共用搜索栏和图书列表组件。
import LibraCore.Network 1.0 // 导入已注册的 BookService 网络类型。

Page { // 管理员图书页面，由 AdminHome 加载。
    id: page // 当前页面的对象名称。
    property int currentPage: 1 // 最近一次成功返回的页码。
    property int requestedPage: 1 // 最近请求的页码，失败时用于原页重试。
    property int totalPages: 0 // 后端返回的总页数。
    property int totalBooks: 0 // 后端返回的匹配图书总数。
    property string activeKeyword: "" // 已提交的关键词，翻页时继续使用。


    property var selectedBook: ({}) // 保存所选图书快照，刷新模型后也不引用失效行。
    property string writeId: "" // 保存写请求编号，只处理属于本页面的响应。
    property string writeMethod: "" // 区分新增、修改、归档的成功状态码。
    property bool saving: false // 写请求进行中时禁用再次提交。
    property bool editing: false // 区分新增表单和编辑表单。
    property string feedback: "" // 操作成功或失败说明，与列表查询错误分开。
    property string formError: "" // 保留表单校验和提交失败信息。
    property bool operationSucceeded: false // 仅在收到契约要求的成功响应后设为 true。

    function hasSelection() { // 写操作必须使用服务端的十进制字符串 ID。
        return /^[1-9][0-9]*$/.test(String(page.selectedBook.id ?? "")) // 避免使用行号或 ISBN 作为主键。
    } // 选中检查结束。

    function openEditor(edit) { // 打开新增或编辑表单。
        page.editing = edit // 记录当前操作类型。
        page.formError = "" // 每次打开时清除上次错误。
        let b = edit ? page.selectedBook : ({}) // 新增为空白，编辑读取已选数据。
        titleField.text = b.title ?? "" // 填入书名。
        authorField.text = b.author ?? "" // 填入作者。
        isbnField.text = b.isbn ?? "" // ISBN 允许未知。
        publisherField.text = b.publisher ?? "" // 填入出版社。
        categoryField.text = b.category ?? "" // 分类在现有接口中是字符串。
        dateField.text = b.published_on ?? "" // 出版日期使用 YYYY-MM-DD。
        descriptionField.text = b.description ?? "" // 填入简介。
        editor.open() // 打开模态窗口。
    } // 打开表单结束。

    function nullableText(text) { // 接口约定可选字段支持 null。
        return text.trim() === "" ? null : text.trim() // 编辑时空值会明确清空该字段。
    } // 空值转换结束。

    function submitBook() { // 提交前先做界面校验，后端仍需独立验证。
        if (page.saving) return // 防止双击导致重复写请求。
        if (!titleField.text.trim() || !authorField.text.trim()) { // 只强制契约要求的两个字段。
            page.formError = "书名和作者不能为空" // 给出明确的必填反馈。
            return // 校验失败时不发送请求。
        } // 必填校验结束。
        let date = dateField.text.trim() // 读取可选出版日期。
        if (date !== "") { // 未填写时允许提交 null。
            let parsed = new Date(date + "T00:00:00Z") // 使用 UTC 解析，避免时区造成日期偏移。
            if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) { // 拦截格式错误及 2 月 30 日等无效日期。
                page.formError = "出版日期须为有效的 YYYY-MM-DD 日期" // 提示用户修正日期。
                return // 不向服务器发送无效日期。
            } // 日期错误处理结束。
        } // 日期校验结束。
        if (descriptionField.text.length > 2000) { // 简介长度与 OpenAPI 一致。
            page.formError = "简介不能超过 2000 个字符" // 保留输入以便修改。
            return // 长度超限不提交。
        } // 简介校验结束。
        let body = { title: titleField.text.trim(), author: authorField.text.trim(), isbn: nullableText(isbnField.text), publisher: nullableText(publisherField.text), category: nullableText(categoryField.text), published_on: date === "" ? null : date, description: nullableText(descriptionField.text) } // 仅发送 BookCreate/BookPatch 接受的字段。
        sendWrite(page.editing ? "PATCH" : "POST", page.editing ? "/api/v1/books/" + page.selectedBook.id : "/api/v1/books", body) // 新增与修改复用表单。
    } // 提交表单结束。

    function sendWrite(method, path, body) { // 统一使用团队公共网络模块，不自行编写网络层。
        if (page.saving) return // 写操作串行，避免请求编号被覆盖。
        page.saving = true // 响应返回前锁定写操作和关闭按钮。
        page.writeMethod = method // 保存预期状态码对应的操作。
        page.formError = "" // 清除上一次提交错误。
        page.feedback = "" // 清除旧的操作结果。
        page.operationSucceeded = false // 尚未成功，不能提前提示已保存。
        page.writeId = ApiClient.request(method, path, {}, body, true) // requiresAuth=true，携带登录模块设置的 Bearer 凭证。
    } // 写请求发送结束。

    Connections { // 监听公共单例；其他页面的请求会被编号过滤掉。
        target: ApiClient // 公共网络模块在 main.cpp 中注册为单例。
        function onRequestFinished(id, result) { // 接收响应结构及 HTTP 状态。
            if (id !== page.writeId) return // 忽略不属于本页面的请求。
            page.writeId = "" // 当前写请求已完成。
            page.saving = false // 恢复操作控件。
            let expected = page.writeMethod === "POST" ? 201 : page.writeMethod === "PATCH" ? 200 : 204 // 按接口契约判断成功。
            if (!result.ok || result.status !== expected) { // 网络失败和非预期响应均不能算成功。
                let message = result.message || "服务响应状态不符合接口约定" // 优先显示服务层错误说明。
                if (result.status === 401) message = "登录已失效或尚未登录，请先由公共登录模块完成管理员登录" // 不在管理页另建登录机制。
                if (result.status === 403) message = "当前账号没有管理员权限" // 权限由后端最终校验。
                if (result.code === "RESOURCE_IN_USE") message = "该书存在借出副本，不能归档，请先完成归还" // 解释引用约束失败。
                if (result.code === "DUPLICATE_RESOURCE") message = "图书唯一字段重复，请检查 ISBN 等信息" // 重复数据不能显示成功。
                page.formError = message // 保留编辑窗口和输入，供用户修正重试。
                page.feedback = message // 主页面也能看到失败原因。
                return // 失败时不修改本地列表伪装成成功。
            } // 失败处理结束。
            editor.close() // 成功后才关闭编辑窗口。
            archiveDialog.close() // 归档成功后关闭确认窗口。
            page.operationSucceeded = true // 只在成功响应之后设置成功状态。
            page.feedback = page.writeMethod === "DELETE" ? "归档成功；历史关联由后端保留" : "保存成功；正在重新查询列表" // 说明写入结果和随后刷新是两步操作。
            page.searchBooks(page.activeKeyword, 1) // 重新从后端读取，不手工伪造持久化结果。
        } // 响应处理结束。
    } // 公共网络信号监听结束。

    Dialog { // 新增和编辑共用一个表单窗口。
        id: editor // 由 openEditor 打开。
        title: page.editing ? "编辑图书" : "新增图书" // 标题随操作变化。
        anchors.centerIn: parent // 在页面中央显示。
        width: Math.min(560, page.width - 20) // 避免超出较窄窗口。
        height: Math.min(620, page.height - 20) // 小窗口中表单可以滚动。
        modal: true // 编辑期间防止误点背景。
        closePolicy: Popup.NoAutoClose // 显式取消，避免点击外部丢失输入。
        contentItem: ScrollView { // 保证较低窗口下所有字段均可访问。
            clip: true // 裁剪滚动区域之外的内容。
            ColumnLayout { // 依次排列字段。
                width: editor.availableWidth // 表单宽度跟随窗口。
                enabled: !page.saving // 提交期间锁定输入。
                Label { text: "书名 *（最多 255 字符）" } // 必填字段说明。
                TextField { id: titleField; Layout.fillWidth: true; maximumLength: 255 } // 限制长度与接口一致。
                Label { text: "作者 *（最多 255 字符）" } // 必填字段说明。
                TextField { id: authorField; Layout.fillWidth: true; maximumLength: 255 } // 作者输入。
                Label { text: "ISBN（可选，最多 20 字符）" } // 不额外要求只有 13 位，以免超出契约。
                TextField { id: isbnField; Layout.fillWidth: true; maximumLength: 20 } // 允许无 ISBN 的馆藏。
                Label { text: "出版社（可选）" } // 可选字段说明。
                TextField { id: publisherField; Layout.fillWidth: true; maximumLength: 255 } // 出版社输入。
                Label { text: "分类（可选）" } // 当前契约没有独立分类管理接口。
                TextField { id: categoryField; Layout.fillWidth: true; maximumLength: 100 } // 使用接口支持的分类字符串。
                Label { text: "出版日期（可选，YYYY-MM-DD）" } // 日期格式说明。
                TextField { id: dateField; Layout.fillWidth: true; maximumLength: 10 } // 提交前验证真实日历日期。
                Label { text: "简介（可选，最多 2000 字符）" } // 简介长度说明。
                TextArea { id: descriptionField; Layout.fillWidth: true; wrapMode: TextEdit.Wrap; selectByMouse: true } // 多行简介输入。
                Label { Layout.fillWidth: true; text: page.formError; visible: text.length > 0; color: "#c62828"; wrapMode: Text.Wrap } // 输入错误和提交错误就地显示。
            } // 表单布局结束。
        } // 滚动容器结束。
        footer: DialogButtonBox { // 显式连接按钮，避免 Dialog 默认接受后过早关闭。
            Button { text: page.saving ? "提交中…" : "保存"; enabled: !page.saving; onClicked: page.submitBook() } // 校验通过后才提交。
            Button { text: "取消"; enabled: !page.saving; onClicked: editor.close() } // 取消不发送请求。
        } // 编辑按钮结束。
    } // 编辑窗口结束。

    Dialog { // DELETE 的契约是归档，不是抹除历史数据。
        id: archiveDialog // 归档操作确认窗口。
        title: page.formError.length > 0 ? "归档失败：" + page.formError : "确认归档图书" // 明确告知真实业务含义。
        anchors.centerIn: parent // 窗口居中。
        width: Math.min(480, page.width - 20) // 适配窄窗口。
        modal: true // 防止确认时误操作列表。
        closePolicy: Popup.NoAutoClose // 通过按钮明确取消。
        contentItem: Label { text: "归档《" + (page.selectedBook.title ?? "") + "》？归档后普通查询不再显示；存在借出副本时后端会拒绝。"; wrapMode: Text.Wrap } // 提示影响及失败条件。
        footer: DialogButtonBox { // 提交后等待服务器确认。
            Button { text: page.saving ? "归档中…" : "确认归档"; enabled: !page.saving; onClicked: page.sendWrite("DELETE", "/api/v1/books/" + page.selectedBook.id, null) } // DELETE 不带请求体，携带管理员凭证。
            Button { text: "取消"; enabled: !page.saving; onClicked: archiveDialog.close() } // 取消不会改变数据。
        } // 归档按钮结束。
    } // 归档窗口结束。

    ListModel { // 与读者端一样，用模型保存当前页数据。
        id: visibleBooks // 列表组件从这个模型读取数据。
    } // 数据模型结束。

    BookService { // 与读者端一样，创建本页面独立的网络服务。
        id: booksApi // 搜索、加载状态和错误信息都通过此对象访问。
        onBooksReceived: function(books, meta) { // 接收网络服务校验过的图书和分页数据。
            visibleBooks.clear() // 显示新结果之前清空旧数据。
            for (let book of books) { // 与读者端一样遍历返回的图书序列。
                visibleBooks.append(book) // 保留服务已转换的 bookTitle、author、isbn 等字段。
            } // 所有图书加入模型后结束循环。
            page.currentPage = meta.page // 保存服务器实际返回的页码。
            page.totalPages = meta.total_pages // 保存总页数。
            page.totalBooks = meta.total // 保存匹配查询条件的图书总数。
        } // 成功响应处理结束；错误直接绑定 booksApi.error。
    } // 服务内部使用公共 ApiClient，请求地址与读者端完全相同。

    function searchBooks(keyword, pageNumber = 1) { // 与读者端一致：新搜索默认第一页。
        if (page.saving) return // 写请求完成前禁止刷新，保留表单关联的操作对象。
        page.selectedBook = ({}) // 刷新或翻页时清除旧选择，避免修改错误记录。
        page.activeKeyword = keyword.trim() // 保存去掉首尾空格的关键词。
        page.requestedPage = pageNumber // 记录本次目标页码。
        visibleBooks.clear() // 请求期间不显示上一次搜索的旧结果。
        booksApi.search(page.activeKeyword, pageNumber, 20) // 复用读者端 GET /api/v1/books，每页 20 条。
    } // 网络模块负责 HTTP 请求、超时、错误解析和取消旧查询。

    Component.onCompleted: page.searchBooks("") // 与读者端一致：进入页面自动加载全部图书第一页。

    ColumnLayout { // 从上到下排列页面内容。
        anchors.fill: parent // 填满当前页面。
        anchors.margins: 15 // 页面四周保留 15 像素。
        spacing: 8 // 相邻控件间距为 8 像素。

        Label { // 管理员页面标题。
            text: "管理员 - 图书管理" // 标明当前页面用途。
            font.pixelSize: 24 // 设置标题字号。
            font.bold: true // 标题加粗。
        } // 标题结束。

        RowLayout { // 本周图书 CRUD 操作入口。
            enabled: !page.saving && !booksApi.loading // 写入和查询期间锁定操作。
            Button { text: "新增图书"; onClicked: page.openEditor(false) } // 新建空表单。
            Button { text: "编辑选中图书"; enabled: page.hasSelection(); onClicked: page.openEditor(true) } // 使用所选记录填充表单。
            Button { text: "归档选中图书"; enabled: page.hasSelection(); onClicked: { page.formError = ""; archiveDialog.open() } } // 先确认再调用删除接口。
        } // 操作栏结束。
        Label { Layout.fillWidth: true; text: page.hasSelection() ? "已选择：" + page.selectedBook.title : "点击下方图书行后可编辑或归档"; elide: Text.ElideRight } // 显示选择状态。
        Label { Layout.fillWidth: true; text: page.feedback; visible: text.length > 0; color: page.operationSucceeded ? "#267238" : "#c62828"; wrapMode: Text.Wrap } // 操作结果独立于查询结果显示。

        BookSearchBar { // 使用与读者端相同的公共搜索栏。
            Layout.fillWidth: true // 搜索栏占满宽度。
            onSearchRequested: function(keyword) { // 接收公共组件发出的搜索信号。
                page.searchBooks(keyword) // 新关键词从第一页开始查询。
            } // 搜索信号处理结束。
        } // 公共搜索栏结束。

        BusyIndicator { // 请求期间显示加载动画。
            Layout.alignment: Qt.AlignHCenter // 动画水平居中。
            running: booksApi.loading // 与读者端一样直接绑定网络加载状态。
            visible: running // 请求结束时隐藏动画。
        } // 加载动画结束。

        Label { // 显示网络服务提供的错误信息。
            Layout.fillWidth: true // 错误文字占满一行。
            visible: booksApi.error.length > 0 // 仅在有错误时显示。
            text: booksApi.error // 不另建错误副本，始终显示当前服务状态。
            color: "#c62828" // 使用红色突出错误。
            wrapMode: Text.Wrap // 较长错误信息自动换行。
        } // 错误标签结束。

        Button { // 与读者端一样提供重试操作。
            visible: booksApi.error.length > 0 // 有错误时才显示按钮。
            text: "重试" // 按钮文字。
            enabled: !booksApi.loading // 加载期间避免重复请求。
            onClicked: page.searchBooks(page.activeKeyword, page.requestedPage) // 重试失败的那一页。
        } // 重试按钮结束。

        RowLayout { // 横向排列分页控件。
            Button { // 上一页操作。
                text: "上一页" // 按钮文字。
                enabled: !booksApi.loading && booksApi.error.length === 0 && page.currentPage > 1 // 第一页、加载中或失败时禁用。
                onClicked: page.searchBooks(page.activeKeyword, page.currentPage - 1) // 保持关键词并查询上一页。
            } // 上一页按钮结束。
            Label { // 显示分页信息。
                text: page.totalPages === 0 ? "0 / 0" : page.currentPage + " / " + page.totalPages // 空结果不显示不存在的第一页。
            } // 页码显示结束。
            Button { // 下一页操作。
                text: "下一页" // 按钮文字。
                enabled: !booksApi.loading && booksApi.error.length === 0 && page.currentPage < page.totalPages // 最后一页、加载中或失败时禁用。
                onClicked: page.searchBooks(page.activeKeyword, page.currentPage + 1) // 保持关键词并查询下一页。
            } // 下一页按钮结束。
            Label { // 展示本页及全部匹配记录数。
                visible: !booksApi.loading && booksApi.error.length === 0 // 加载或失败时不显示旧统计。
                text: "本页：" + visibleBooks.count + " 本，共：" + page.totalBooks + " 本" // 总数读取后端分页信息。
            } // 数量统计结束。
        } // 分页栏结束。

        BookListView { // 与读者端共用图书列表组件。
            Layout.fillWidth: true // 列表占满可用宽度。
            Layout.fillHeight: true // 列表占据页面剩余高度。
            visible: !booksApi.loading && booksApi.error.length === 0 // 与读者端一致，加载或失败时隐藏列表。
            onBookClicked: function(index) { // 公共列表只发下标，由本页取得记录。
                if (page.saving || booksApi.loading) return // 请求期间不允许更换操作对象。
                let book = visibleBooks.get(index) // 读取当前列表行。
                page.selectedBook = { id: String(book.id ?? ""), title: book.title, author: book.author, isbn: book.isbn, publisher: book.publisher, category: book.category, published_on: book.published_on, description: book.description } // 复制字段，保留主键字符串避免 BIGINT 精度损失。
            } // 行选择处理结束。
            bookModel: visibleBooks // 将网络返回的数据交给公共列表显示。
        } // 当前只实现联网查询，不添加尚无写入接口的模拟表单。
    } // 页面布局结束。
} // 管理员图书页面结束。
