pragma ComponentBehavior: Bound // 行模板绑定本页面作用域，可明确访问 page 状态。
import QtQuick // 基础对象、模型和列表。
import QtQuick.Controls // 页面、对话框和输入控件。
import QtQuick.Layouts // 自动排列控件。
import LibraCore.Network 1.0 // 使用团队公共 ApiClient。

Page { // 独立读者管理页面，不直接访问数据库。
    id: page // 页面对象名称。
    property string queryId: "" // 标识最新列表请求，忽略过期响应。
    property string writeId: "" // 单独匹配写请求，不与查询混用。
    property string writeMethod: "" // 决定预期成功状态码。
    property bool loading: false // 列表请求状态。
    property bool saving: false // 写请求状态，防止重复提交。
    property bool editing: false // 区分新增和修改表单。
    property int currentPage: 1 // 最近成功返回的页码。
    property int requestedPage: 1 // 最近请求页码，用于失败重试。
    property int totalPages: 0 // 服务端返回总页数。
    property int totalReaders: 0 // 服务端返回总条数。
    property var selectedReader: ({}) // 保存行快照，不持有模型行引用。
    property string queryError: "" // 列表错误与写操作反馈分开。
    property string feedback: "" // 显示写入结果。
    property string formError: "" // 对话框内显示校验或接口错误。
    property bool operationSucceeded: false // 仅真实成功响应后设为 true。

    ListModel { id: readersModel } // 保存当前页读者，更新后列表自动刷新。

    function hasSelection() { // 主键必须符合接口中的字符串 ID 格式。
        return /^[1-9][0-9]*$/.test(String(page.selectedReader.id ?? "")) // 不把 BIGINT 转为 JS 数值。
    } // 选择校验结束。

    function loadReaders(pageNumber = 1) { // 当前读者列表接口只支持分页，没有关键词参数。
        if (page.saving) return // 写操作期间不更换操作对象。
        page.loading = true // 开启加载动画。
        page.queryError = "" // 清除上一次查询错误。
        page.requestedPage = pageNumber // 失败重试时使用同一页。
        page.selectedReader = ({}) // 刷新后必须重新选择记录。
        readersModel.clear() // 不将旧列表当成新查询结果。
        page.queryId = ApiClient.request("GET", "/api/v1/readers", { page: pageNumber, page_size: 20 }, null, true) // 管理员列表也必须携带登录凭证。
    } // 列表查询结束。

    function errorText(result) { // 将常见业务错误转换为可理解的说明。
        if (result.status === 401) return "尚未登录或登录失效，请通过公共登录模块重新登录" // 页面不另建凭证机制。
        if (result.status === 403) return "当前账号没有管理员权限" // 真正权限由后端校验。
        if (result.status === 404) return "该读者记录已不存在，请刷新列表" // 处理其他管理员已变更记录的情况。
        if (result.code === "RESOURCE_IN_USE") return "该读者存在有效借阅，不能注销，请先完成归还" // 解释关联约束。
        if (result.code === "DUPLICATE_RESOURCE") return "用户名或其他唯一字段已存在，请修改后重试" // 重复账号不能报成功。
        return result.message || "服务响应不符合接口约定" // 其余错误保留网络模块说明。
    } // 错误映射结束。

    function validList(body) { // 在修改模型前验证完整响应，避免显示半份数据。
        if (!body || !Array.isArray(body.data) || !body.meta) return false // 必须是 data 数组和 meta 对象。
        let meta = body.meta // 读取分页结构。
        for (let key of ["page", "page_size", "total", "total_pages"]) { // 验证分页数值类型与整数约束。
            if (typeof meta[key] !== "number" || !Number.isInteger(meta[key]) || meta[key] < 0) return false // 排除负数、字符串和小数。
        } // 分页基础校验结束。
        if (meta.page < 1 || meta.page_size < 1 || meta.page_size > 100) return false // 与 OpenAPI 分页范围一致。
        for (let row of body.data) { // 遍历每一条读者记录。
            if (!row || typeof row.id !== "string" || !/^[1-9][0-9]*$/.test(row.id)) return false // 主键必须为十进制字符串。
            if (typeof row.username !== "string" || typeof row.display_name !== "string" || typeof row.is_active !== "boolean" || typeof row.created_at !== "string") return false // 验证必需字段。
            if (row.email !== undefined && row.email !== null && typeof row.email !== "string") return false // 邮箱可缺省或为 null。
        } // 读者字段校验结束。
        return true // 整批响应通过验证。
    } // 响应校验结束。

    function openEditor(edit) { // 新增和编辑共用表单。
        page.editing = edit // 控制字段和提交结构。
        page.formError = "" // 不显示上一次错误。
        let row = edit ? page.selectedReader : ({}) // 新增使用空记录。
        usernameField.text = row.username ?? "" // 编辑时用户名只读。
        passwordField.text = "" // 不展示、读取或复用已有密码。
        nameField.text = row.display_name ?? "" // 读者显示名称。
        emailField.text = row.email ?? "" // null 邮箱显示为空。
        activeField.checked = edit ? row.is_active : true // 新增不发送契约未允许的状态字段。
        editor.open() // 打开模态窗口。
    } // 打开编辑窗口结束。

    function submitReader() { // 校验通过才向后端提交。
        if (page.saving) return // 避免双击发送两次。
        if (!nameField.text.trim() || (!page.editing && !usernameField.text.trim())) { // 新增需要用户名，所有操作需要显示名称。
            page.formError = "请填写显示名称和新增账号的用户名" // 就地反馈缺失字段。
            return // 校验失败不发送网络请求。
        } // 必填校验结束。
        if (!page.editing && passwordField.text.length < 8) { // 新增密码最少 8 个字符。
            page.formError = "初始密码至少需要 8 个字符" // 不输出密码内容。
            return // 短密码不提交。
        } // 密码校验结束。
        let email = emailField.text.trim() // 邮箱去除首尾空格。
        if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { // 基础邮箱格式检查，最终仍由后端验证。
            page.formError = "请输入有效邮箱，或留空" // 邮箱不是必填。
            return // 无效邮箱不提交。
        } // 邮箱校验结束。
        let body = { display_name: nameField.text.trim(), email: email === "" ? null : email } // 空邮箱用 null 明确清空。
        if (page.editing) { // ReaderPatch 允许修改资料和状态。
            body.is_active = activeField.checked // 修改时发送启用状态。
        } else { // ReaderCreate 要求用户名和初始密码。
            body.username = usernameField.text.trim() // 用户名只在新增时提交。
            body.password = passwordField.text // 不 trim 密码，避免改变用户输入。
        } // 新增和编辑字段分支结束。
        sendWrite(page.editing ? "PATCH" : "POST", page.editing ? "/api/v1/readers/" + page.selectedReader.id : "/api/v1/readers", body) // 只发送接口允许的字段。
    } // 表单提交结束。

    function sendWrite(method, path, body) { // 统一发出带认证的写请求。
        if (page.saving) return // 同一时间最多一个写请求。
        page.saving = true // 锁定重复操作。
        page.writeMethod = method // 保存成功状态码所需的操作类型。
        page.formError = "" // 清除旧提交错误。
        page.feedback = "" // 清除旧反馈。
        page.operationSucceeded = false // 不提前声称成功。
        page.writeId = ApiClient.request(method, path, {}, body, true) // 使用公共单例内存中的 Bearer 凭证。
    } // 写请求发送结束。

    Connections { // 响应来自公共单例，需要按请求编号区分。
        target: ApiClient // 监听公共网络对象。
        function onRequestFinished(id, result) { // 接收请求完成信号。
            if (id === page.queryId) { // 处理最新的读者列表查询。
                page.queryId = "" // 清除已完成编号。
                page.loading = false // 停止加载动画。
                if (!result.ok || result.status !== 200) { // HTTP 或网络失败。
                    page.queryError = page.errorText(result) // 展示可理解的错误。
                    return // 不把失败当作空列表。
                } // 请求失败分支结束。
                if (!page.validList(result.body)) { // 检查业务响应结构。
                    page.queryError = "读者列表响应格式错误：请与后端核对 data、meta 和读者字段" // 不接受错误数据。
                    return // 不更新列表。
                } // 响应格式校验结束。
                for (let row of result.body.data) { // 数据验证完成后再写入模型。
                    readersModel.append({ readerId: row.id, username: row.username, displayName: row.display_name, email: row.email ?? "", active: row.is_active, createdAt: row.created_at }) // 转为稳定的 QML 模型字段。
                } // 列表更新结束。
                page.currentPage = result.body.meta.page // 采用服务端实际页码。
                page.totalPages = result.body.meta.total_pages // 更新分页上限。
                page.totalReaders = result.body.meta.total // 更新总条数。
                return // 不进入写响应分支。
            } // 查询处理结束。
            if (id !== page.writeId) return // 忽略其他页面和旧查询的响应。
            page.writeId = "" // 写请求已经结束。
            page.saving = false // 恢复交互。
            let expected = page.writeMethod === "POST" ? 201 : page.writeMethod === "PATCH" ? 200 : 204 // 与读者 CRUD 契约一致。
            if (!result.ok || result.status !== expected) { // 失败时保留表单输入。
                page.formError = page.errorText(result) // 对话框就地显示错误。
                page.feedback = page.formError // 页面也保存失败说明。
                return // 不伪造本地数据变更。
            } // 写失败处理结束。
            editor.close() // 成功才关闭编辑窗口，关闭时清空密码。
            deactivateDialog.close() // 成功才关闭注销窗口。
            page.operationSucceeded = true // 标记真实收到成功响应。
            page.feedback = page.writeMethod === "DELETE" ? "注销成功；历史记录由后端保留" : "保存成功；正在重新查询读者列表" // 写成功与列表刷新分开报告。
            page.loadReaders(1) // 重新读取后端数据，不在客户端伪造持久化结果。
        } // 响应处理结束。
    } // 网络信号监听结束。

    Component.onCompleted: page.loadReaders() // 进入页面自动请求第一页。

    ColumnLayout { // 页面纵向布局。
        anchors.fill: parent // 填满页面。
        anchors.margins: 15 // 四周留白。
        spacing: 8 // 控件间距。
        Label { text: "管理员 - 读者管理"; font.pixelSize: 24; font.bold: true } // 标题。
        Flow { // 操作按钮随窗口宽度换行。
            Layout.fillWidth: true // 使用全部可用宽度。
            spacing: 8 // 按钮间距。
            enabled: !page.loading && !page.saving // 请求时禁止冲突操作。
            Button { text: "新增读者"; onClicked: page.openEditor(false) } // 打开新增表单。
            Button { text: "编辑选中读者"; enabled: page.hasSelection(); onClicked: page.openEditor(true) } // 编辑所选资料。
            Button { text: "注销选中读者"; enabled: page.hasSelection() && page.selectedReader.is_active; onClicked: { page.formError = ""; deactivateDialog.open() } } // 已停用账号不重复注销。
            Button { text: "刷新"; onClicked: page.loadReaders(page.currentPage) } // 重新查询当前页。
        } // 操作栏结束。
        Label { Layout.fillWidth: true; text: page.hasSelection() ? "已选择：" + page.selectedReader.username : "点击读者记录后可编辑或注销"; elide: Text.ElideRight } // 明确选中对象。
        Label { Layout.fillWidth: true; text: page.feedback; visible: text.length > 0; wrapMode: Text.Wrap; color: page.operationSucceeded ? "#267238" : "#c62828" } // 操作反馈。
        BusyIndicator { running: page.loading || page.saving; visible: running; Layout.alignment: Qt.AlignHCenter } // 显示查询或提交中的状态。
        Label { Layout.fillWidth: true; text: page.queryError; visible: text.length > 0; color: "#c62828"; wrapMode: Text.Wrap } // 查询错误。
        Button { text: "重试查询"; visible: page.queryError.length > 0; enabled: !page.loading && !page.saving; onClicked: page.loadReaders(page.requestedPage) } // 保持失败页码。
        RowLayout { // 分页操作。
            enabled: !page.loading && !page.saving && page.queryError.length === 0 // 请求和失败期间禁止翻页。
            Button { text: "上一页"; enabled: page.currentPage > 1; onClicked: page.loadReaders(page.currentPage - 1) } // 第一页禁用。
            Label { text: page.totalPages === 0 ? "0 / 0" : page.currentPage + " / " + page.totalPages } // 空列表页码。
            Button { text: "下一页"; enabled: page.currentPage < page.totalPages; onClicked: page.loadReaders(page.currentPage + 1) } // 最后一页禁用。
            Label { text: "共 " + page.totalReaders + " 位读者"; visible: !page.loading && page.queryError.length === 0 } // 总数由后端提供。
        } // 分页栏结束。
        Label { text: "暂无读者数据"; visible: !page.loading && page.queryError.length === 0 && readersModel.count === 0 } // 成功空结果提示。
        ListView { // 每条记录采用两行布局，避免窄窗口表格列拥挤。
            Layout.fillWidth: true // 列表宽度跟随页面。
            Layout.fillHeight: true // 占据剩余高度。
            clip: true // 裁剪滚动内容。
            spacing: 4 // 记录间距。
            visible: !page.loading && page.queryError.length === 0 // 失败或加载时不显示过期记录。
            model: readersModel // 使用当前页模型。
            delegate: Rectangle { // 一位读者的显示模板。
                id: rowItem // 子控件访问当前行。
                required property string readerId // 字符串主键。
                required property string username // 登录用户名。
                required property string displayName // 显示名称。
                required property string email // 空邮箱已转为空字符串。
                required property bool active // 账号状态。
                required property string createdAt // 注册时间。
                width: ListView.view.width // 行宽跟随列表。
                height: 76 // 预留两行文字空间。
                color: page.selectedReader.id === readerId ? "#dcecff" : "#f1f3f6" // 高亮选中的读者。
                ColumnLayout { // 纵向展示账号与联系信息。
                    anchors.fill: parent // 填满行背景。
                    anchors.margins: 8 // 内容内边距。
                    Label { Layout.fillWidth: true; text: rowItem.displayName + "（" + rowItem.username + "） · " + (rowItem.active ? "启用" : "停用"); elide: Text.ElideRight } // 主信息。
                    Label { Layout.fillWidth: true; text: "邮箱：" + (rowItem.email || "未填写") + " · 创建：" + rowItem.createdAt; elide: Text.ElideRight } // 辅助信息。
                } // 行文字布局结束。
                MouseArea { // 点击后保存当前行快照。
                    anchors.fill: parent // 全行可选。
                    enabled: !page.saving // 提交期间不能切换所选读者。
                    onClicked: page.selectedReader = { id: rowItem.readerId, username: rowItem.username, display_name: rowItem.displayName, email: rowItem.email, is_active: rowItem.active } // 复制值，不持有模型引用。
                } // 行点击区域结束。
            } // 行模板结束。
            ScrollBar.vertical: ScrollBar {} // 列表超出区域时可滚动。
        } // 列表结束。
    } // 页面布局结束。

    Dialog { // 新增和编辑共用对话框。
        id: editor // 编辑窗口名称。
        title: page.editing ? "编辑读者" : "新增读者" // 动态标题。
        anchors.centerIn: parent // 居中。
        width: Math.min(520, page.width - 20) // 适配较窄窗口。
        height: Math.min(560, page.height - 20) // 限制高度，内容滚动。
        modal: true // 阻止误点背景。
        closePolicy: Popup.NoAutoClose // 显式取消或成功后关闭。
        onClosed: passwordField.text = "" // 不将初始密码留在关闭的表单里。
        contentItem: ScrollView { // 小窗口下仍可访问全部字段。
            clip: true // 裁剪边界。
            ColumnLayout { // 字段从上到下排列。
                width: editor.availableWidth // 跟随对话框宽度。
                enabled: !page.saving // 提交期间锁定输入。
                Label { text: page.editing ? "用户名（不可修改）" : "用户名 *（最多 64 字符）" } // ReaderPatch 不允许改用户名。
                TextField { id: usernameField; Layout.fillWidth: true; maximumLength: 64; readOnly: page.editing } // 用户名输入。
                Label { text: "初始密码 *（至少 8 字符）"; visible: !page.editing } // 编辑没有修改密码接口。
                TextField { id: passwordField; Layout.fillWidth: true; visible: !page.editing; echoMode: TextInput.Password } // 密码掩码，不输出到日志。
                Label { text: "显示名称 *（最多 100 字符）" } // 显示名称说明。
                TextField { id: nameField; Layout.fillWidth: true; maximumLength: 100 } // 名称长度限制。
                Label { text: "邮箱（可选）" } // 邮箱允许留空。
                TextField { id: emailField; Layout.fillWidth: true; inputMethodHints: Qt.ImhEmailCharactersOnly } // 提示输入法使用邮箱字符。
                CheckBox { id: activeField; text: "账号启用"; visible: page.editing } // 只在编辑时发送 is_active。
                Label { Layout.fillWidth: true; text: "用户名和密码仅在新增时提交；有有效借阅时应通过注销操作由后端检查。"; wrapMode: Text.Wrap } // 解释业务边界。
                Label { Layout.fillWidth: true; text: page.formError; visible: text.length > 0; color: "#c62828"; wrapMode: Text.Wrap } // 保留输入并显示错误。
            } // 表单布局结束。
        } // 表单滚动容器结束。
        footer: DialogButtonBox { // 不使用默认接受按钮，避免校验失败时自动关闭。
            Button { text: page.saving ? "提交中…" : "保存"; enabled: !page.saving; onClicked: page.submitReader() } // 保存前校验。
            Button { text: "取消"; enabled: !page.saving; onClicked: editor.close() } // 取消不写入。
        } // 按钮栏结束。
    } // 编辑窗口结束。

    Dialog { // 注销是停用并保留历史，不是物理删除。
        id: deactivateDialog // 注销确认窗口。
        title: "确认注销读者" // 明确操作含义。
        anchors.centerIn: parent // 居中。
        width: Math.min(480, page.width - 20) // 限制宽度。
        modal: true // 不允许误点背景。
        closePolicy: Popup.NoAutoClose // 使用明确取消按钮。
        contentItem: ColumnLayout { // 说明和错误同时显示。
            Label { Layout.fillWidth: true; text: "注销账号“" + (page.selectedReader.username ?? "") + "”？历史借阅保留；存在有效借阅时后端会拒绝。"; wrapMode: Text.Wrap } // 注销影响。
            Label { Layout.fillWidth: true; text: page.formError; visible: text.length > 0; color: "#c62828"; wrapMode: Text.Wrap } // 引用约束失败就地提示。
        } // 确认内容结束。
        footer: DialogButtonBox { // 注销按钮。
            Button { text: page.saving ? "注销中…" : "确认注销"; enabled: !page.saving; onClicked: page.sendWrite("DELETE", "/api/v1/readers/" + page.selectedReader.id, null) } // 无请求体，携带认证。
            Button { text: "取消"; enabled: !page.saving; onClicked: deactivateDialog.close() } // 取消不发送请求。
        } // 确认按钮栏结束。
    } // 注销窗口结束。
} // 读者管理页面结束。
