// 让 delegate 内部可以引用外层 carousel 和 cardList 的 ID。
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// 鼠标按住卡片左右拖动：卡片平移，松手后吸附到中间。
// 不使用定时器，不自动播放；图片由外部数据的 imageSource 提供。
Item {
    id: carousel
    // 期望高度，供首页的 ColumnLayout 分配空间。
    implicitHeight: 320
    // 外部输入的卡片数组，每条包含 title、color、imageSource、bookId。
    // 默认空数组，组件本身不请求网络数据。
    property var banners: []
    // 对外提供当前选中项的下标，从 0 开始；空列表时通常是 -1。
    // readonly 表示外部可以读取，但不能直接给这个属性赋值。
    readonly property int currentIndex: cardList.currentIndex
    // 点击居中的卡片时发出信号，具体如何打开详情由外层页面处理。
    signal bookRequested(string bookId)

    // PathView 的排列是循环的，不会像普通列表那样在第一张左边留空。
    PathView {
        id: cardList
        anchors.fill: parent
        // 下方留出 28 像素，给指示条使用。
        anchors.bottomMargin: 28
        // 数据数组中的每一条数据，对应一个 delegate 卡片。
        model: carousel.banners
        // 超出视口的内容不绘制。注意这是矩形裁切，不是圆角图片蒙版。
        clip: true

        // 中心对应路径的 50% 位置，松手后当前卡片吸附到这里。
        // 路径上最多显示三张；不足三条时只显示实际数量。
        // 只有至少三条数据时，才能同时展示中间、左侧、右侧三张不同卡片。
        pathItemCount: Math.min(3, carousel.banners.length)
        // 松手后停靠到某张卡片，不停在两张之间。
        snapMode: PathView.SnapToItem
        // 把当前项保持在指定区间；拖动时当前项会随位置改变。
        highlightRangeMode: PathView.StrictlyEnforceRange
        // 路径位置使用 0～1，0.5 就是中点；起止相同表示固定在中点。
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        // 点击指示条等方式更换当前项时，过渡用时 250 毫秒。
        highlightMoveDuration: 250
        // 限制快速甩动时沿路径运动的最大速度，单位为像素/秒。
        maximumFlickVelocity: 1600

        // 水平路径：卡片沿路径平移，越靠中间越大、层级越靠前。
        // 路径两端在视口外，循环换边时隐藏在裁切区域之外。
        path: Path {
            // 路径定义卡片中心的运动位置；起点放在左侧视口之外。
            startX: -cardList.width * 0.225
            startY: cardList.height / 2
            // 第一段直线到视口正中；第二段继续到右侧视口之外。
            PathLine { x: cardList.width / 2; y: cardList.height / 2 }
            PathLine { x: cardList.width * 1.225; y: cardList.height / 2 }
        }

        delegate: Item {
            id: card
            // PathView 将当前数据对象传给 modelData。
            required property var modelData
            // 当前卡片在数组中的下标：0、1、2……
            required property int index
            // 未缩放的卡片宽度为视口的 55%，高度为 280。
            width: cardList.width * 0.55
            height: 280

            // PathView 自动设置每张卡片的位置；距中心的距离决定大小和遮挡。
            // x 是卡片左边的位置，x + width/2 是卡片中心。
            // 两个中心相减再取绝对值，得到离视口中心多远。
            readonly property real distance: Math.abs(x + width / 2 - cardList.width / 2)
            // emphasis 表示突出程度：正中为 1，远离中心后逐渐降到 0。
            // 0.4833 约为当前路径上相邻卡片的间距占视口宽度的比例。
            // Math.max(1, ...) 避免初始宽度为 0 时除以 0。
            readonly property real emphasis: Math.max(0, 1 - distance / Math.max(1, cardList.width * 0.4833))
            // 中间缩放为 1，两侧最低为 0.78；默认围绕卡片中心缩放。
            scale: 0.78 + 0.22 * emphasis
            // z 越大越靠前，确保居中卡片盖在两侧卡片上。
            z: emphasis * 2

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: 10
                // || 在未提供有效颜色值时使用默认色。
                color: card.modelData.color || "#dce6ed"

                // 预留图片入口。外部传入 imageSource 后自动显示，无需修改组件。
                // 图片内缩，避免矩形图片覆盖外层卡片的圆角。
                Image {
                    id: bannerImage
                    anchors.fill: parent
                    anchors.margins: 10
                    // 目前首页传空字符串；以后填图片资源路径即可。
                    source: card.modelData.imageSource || ""
                    // 保持比例并填满区域，超出部分裁切，图片不会拉伸变形。
                    fillMode: Image.PreserveAspectCrop
                    // 本地图片也使用异步加载，减少加载时对界面的阻塞。
                    asynchronous: true
                    // 图片加载完成后才显示；失败或尚未加载时显示文字占位。
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: card.modelData.title || "推荐图书"
                    font.pixelSize: 22
                    color: "#303133"
                    // 未配置图片或加载失败时，保留文字占位。
                    visible: bannerImage.status !== Image.Ready
                }

                // TapHandler 只处理点击，不抢占 PathView 的拖动手势。
                TapHandler {
                    onTapped: {
                        // 点击侧边卡片先将它移到中间。
                        //！==是严格不相等//
                        if (cardList.currentIndex !== card.index)
                            cardList.currentIndex = card.index
                        // 已居中的卡片被点击，且有关联 ID 时才通知外层。
                        else if (card.modelData.bookId)
                            carousel.bookRequested(String(card.modelData.bookId))
                    }
                }
            }
        }
    }

    // 指示当前卡片，也可以点击切换；没有自动轮播。
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Repeater {
            // 有几张卡片就生成几个指示条按钮。
            model: carousel.banners.length
            delegate: Button {
                id: indicator
                required property int index
                width: 24
                height: 20
                // 为屏幕阅读器提供按钮含义，不会显示在按钮上。
                Accessible.name: "查看第 " + (index + 1) + " 张推荐"
                // 实际可点击区域为 24×20，里面只画 24×4 的细条。
                background: Item {
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 4
                        radius: 2
                        color: indicator.index === cardList.currentIndex ? "#409eff" : "#dcdfe6"
                    }
                }
                // 设置当前下标后，PathView 自动把对应卡片移到中间。
                onClicked: cardList.currentIndex = index
            }
        }
    }

    // 空数据时显示提示，不让整个区域完全空白。
    Text {
        anchors.centerIn: parent
        text: "暂无推荐内容"
        color: "#909399"
        visible: carousel.banners.length === 0
    }
}
