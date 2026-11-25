import QtQuick
import QtQuick.Controls.Basic

import "reader"
import "admin"

// 程序窗口只负责承载读者端或管理端，各端自己提供导航栏。
ApplicationWindow {
    id: window

    width: 1000
    height: 700
    minimumWidth: 900
    minimumHeight: 500
    // 默认最大化；width/height 作为还原窗口后的尺寸。
    visibility: Window.Maximized
    title: "LibraCore 图书馆管理系统"

    // 登录尚未接入，默认预览读者端。
    // 开发时改成 "admin" 可预览管理端；后续由真实登录角色决定。
    // 这个属性只用于界面选择，权限仍需后端校验。
    property string previewRole: "reader"

    Loader {
        anchors.fill: parent
        sourceComponent: window.previewRole === "admin" ? adminPage : readerPage
    }

    Component {
        id: readerPage
        ReaderHome {}
    }

    Component {
        id: adminPage
        AdminHome {}
    }
}
