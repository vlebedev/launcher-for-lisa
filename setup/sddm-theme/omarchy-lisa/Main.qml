// SDDM greeter theme "omarchy-lisa": Omarchy's password-only login screen plus
// a user switcher, for a machine with more than one account.
//
// Omarchy's stock theme (/usr/share/sddm/themes/omarchy/Main.qml) always logs
// in userModel.lastUser and offers no way to choose another account. This copy
// keeps its look and adds a row of user names above the password box.
// Left/Right/Up/Down/Tab or a click select a user; Enter logs in.
//
// Image assets are taken from Omarchy's own theme directory so the logo keeps
// following the Omarchy theme switcher (omarchy-plymouth-set rewrites them).

import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  readonly property string assetDir: "/usr/share/sddm/themes/omarchy/"

  property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  function selectUser(index) {
    var count = userModel.rowCount()
    if (count <= 0)
      return
    root.userIndex = ((index % count) + count) % count
    root.loginFailed = false
    password.text = ""
    password.forceActiveFocus()
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Image {
      id: logo
      source: root.assetDir + "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    // User switcher: one label per account, the selected one highlighted.
    Row {
      id: users
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 36

      Repeater {
        model: userModel

        Item {
          id: userItem
          readonly property bool selected: index === root.userIndex
          width: label.width
          height: label.height

          onSelectedChanged: if (selected) root.currentUser = model.name
          Component.onCompleted: if (selected) root.currentUser = model.name

          Text {
            id: label
            text: (model.realName && model.realName.length > 0) ? model.realName : model.name
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            font.letterSpacing: 2
            color: userItem.selected ? "#c0caf5" : "#565f89"
          }

          Rectangle {
            anchors.top: label.bottom
            anchors.topMargin: 6
            width: label.width
            height: 2
            color: userItem.selected ? "#7aa2f7" : "transparent"
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selectUser(index)
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.assetDir + (root.loginFailed ? "lock-failed.png" : "lock.png")
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.assetDir + (root.loginFailed ? "entry-failed.png" : "entry.png")
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: root.assetDir + "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "•"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up ||
                       (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
              root.selectUser(root.userIndex - 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down ||
                       event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              root.selectUser(root.userIndex + 1)
              event.accepted = true
            }
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "← →  switch user"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 13
      color: "#3b4261"
      visible: userModel.rowCount() > 1
    }
  }

  Component.onCompleted: password.forceActiveFocus()
}
