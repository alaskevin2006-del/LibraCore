# 公共网络模块 v0.2

读者端和管理员端可通过 `import LibraCore.Network 1.0` 使用同一个 `ApiClient`。
现有读者搜索通过 `BookService` 调用公共模块。现有的分页、列表数据转换和取消旧查询由 `BookService` 负责。

QML 调用 `ApiClient.request(method, path, query, body, requiresAuth)` 会立即返回请求 ID。
`path` 传以 `/` 开头的接口路径，查询参数放进 `query` 对象。
请求体支持 JSON 对象或数组，无请求体时传 `null`。GET 和 DELETE 使用无请求体的形式。
调用方通过 `requestFinished(id, result)` 按 ID 匹配响应，可同时发起多个请求。

```qml
import QtQml
import LibraCore.Network 1.0

QtObject {
    property string pendingId: ""

    function search(keyword) {
        pendingId = ApiClient.request("GET", "/api/v1/books",
                                      { q: keyword, page: 1, page_size: 20 })
    }

    function updateTitle(bookId, title) {
        pendingId = ApiClient.request("PATCH", "/api/v1/books/" + bookId,
                                      {}, { title: title }, true)
    }

    property Connections responses: Connections {
        target: ApiClient
        function onRequestFinished(id, result) {
            if (id !== pendingId)
                return
            if (result.ok)
                console.log("HTTP", result.status)
            else
                console.warn(result.errorKind, result.status, result.code, result.message)
        }
    }
}
```

- 成功时 `result.body` 是解析后的响应，业务层自行读取 `body.data` 和 `body.meta`。204 和 205 可以没有响应体。
- 失败时 `result.errorKind` 是 `request`、`network`、`http` 或 `json`，分别表示请求参数无效、网络问题、HTTP 错误或成功响应的 JSON 无效。没有 HTTP 响应时 `result.status` 为 0。后端返回业务错误时，可按 `result.code` 分支。
- D2 登录成功后调用 `ApiClient.setAccessToken(body.data.access_token)` 设置内存中的 Bearer 凭证。它返回是否成功，清除凭证使用 `clearAccessToken()`。只有 `requiresAuth` 为 `true` 的请求会携带已设置的凭证。
- 部署时把服务地址设为实际 API 源地址，例如正式环境的 HTTPS 地址。需要认证的请求和写请求会把 HTTP 重定向状态码返回给调用方。

## 图书查询验证

默认服务地址 http://localhost:8080；启动前可用环境变量 LIBRACORE_API_URL 指定服务源地址。

使用 Qt Creator 打开 client/CMakeLists.txt，选择 Qt 6.10 或更新的 Kit，构建并运行。

手工验证（需要契约兼容的后端或 mock）：
- 首次进入图书页请求 GET /api/v1/books?q=&page=1&page_size=20。
- 搜索中文、空格、& 等字符，检查 q 编码、回车与查询按钮。
- 返回 data/meta：显示 title/author/isbn；isbn=null 显示空字符串；点击打开详情。
- 返回多页数据：检查上一页、下一页和新搜索回到第一页。
- 返回空 data：显示空结果；延迟响应时显示加载状态。
- 停止服务、返回 HTTP 错误或无效 JSON：显示错误，恢复服务后重试。
- 快速连续搜索：旧请求取消，最终只显示最新请求结果。

API 为草案；上述步骤是验收说明，不代表已经完成真实后端联调。
