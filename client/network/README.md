# 图书查询验证

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
