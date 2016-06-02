// bind ctrl+shift+f to maximize focused window
var maximize = Bind.on("f", ["ctrl", "shift"], function() {
  var win = Window.focusedWindow();

  if (win) {
    win.maximize();
  }
});

// bind ctrl+shift+a to resize and reposition focused window to the left half of
// the screen.
var leftHalf = Bind.on("a", ["ctrl", "shift"], function() {
  var win = Window.focusedWindow();

  if (win) {
    var screen = win.screen();
    var width = screen.frameWithoutDockOrMenu().width;
    var height = screen.frameWithoutDockOrMenu().height;

    win.setFrame({ x: 0, y: 0, width: width/2, height: height });
  }
});

// bind ctrl+shift+d to resize and reposition focused window to the right half
// of the screen.
var rightHalf = Stark.bind("d", ["ctrl", "shift"], function() {
  var win = Window.focusedWindow();

  if (win) {
    var screen = win.screen();
    var width = screen.frameWithoutDockOrMenu().width;
    var height = screen.frameWithoutDockOrMenu().height;

    win.setFrame({ x: width/2, y: 0, width: width/2, height: height });
  }
});

// listen for when Terminal.app is launched and maximize every visible window.
var maximizeTerminal = Event.on("applicationDidLaunch", function(app) {
  var name = app.name();

  if (name === "Terminal") {
    _.each(app.visibleWindows(), function(win) {
      win.maximize();
    });
  }
});