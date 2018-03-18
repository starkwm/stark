Bind.on('h', ['ctrl', 'shift'], () => {
  const win = Window.focused();

  if (!win) {
    return;
  }

  const r = win.screen.frameWithoutDockOrMenu;

  const x = r.x;
  const y = r.y;

  const width = r.width / 2;
  const height = r.height;

  win.setFrame({ x, y, width, height });
});

Bind.on('l', ['ctrl', 'shift'], () => {
  const win = Window.focused();

  if (!win) {
    return;
  }

  const r = win.screen.frameWithoutDockOrMenu;

  const x = (r.x + (r.width / 2));
  const y = r.y;

  const width = r.width / 2;
  const height = r.height;

  win.setFrame({ x, y, width, height });
});
