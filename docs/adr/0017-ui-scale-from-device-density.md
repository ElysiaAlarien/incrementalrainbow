# The UI scale comes from the density of the device, and the layout fits 640 x 360

The game runs in landscape on phones, tablets, and computers (#27). Before #27, the window stretched a fixed 1280 x 720 layout to the screen. On a phone, that made text about 2 mm high and buttons about 3 mm high, which is too small to read and to touch.

**The scale.** `UiScale` sets how many device pixels one logical pixel of the layout uses (`Window.content_scale_factor`, with the `canvas_items` stretch mode):

- On a phone or a tablet, one logical pixel is one Android "dp", 1/160 of an inch. Thus a touch target of 44 logical pixels is about 7 mm on all phones and tablets, the size in the Apple and WCAG guidelines.
- On a computer, the scale is the scale of the operating system (2 on a Mac Retina screen, 1.5 for 150% on Windows), but at least the window height over 1080. Thus the game is the same size as other apps in a small window, and does not look small in a full-screen window on a 1440p or 4K monitor that the operating system does not scale. Godot does not give the scale on Windows, so there it is the DPI over 96 (Windows gives the DPI of the scale that the user set).
- The logical size is never smaller than 640 x 360. A smaller screen gets a smaller scale.

So the layout must fit any logical size from 640 x 360 up. A small phone is about 654 x 368, a 4:3 tablet about 1241 x 930, and an ultrawide monitor about 2580 x 1080.

**The layout.** One section shows at a time, and a rail at the left opens the others. A row is made of short parts in flow containers, which wrap to more lines on a narrow screen, and of labels that wrap. No text is trimmed, because a tooltip does not show on a touch screen. Each frame shows only the top of the screen and the open section. A command shows all sections.

**The tests.** `DeviceProfiles` lists real devices. The layout smoke test runs the screen at the logical size that `UiScale` gives each one, with a game that fills the screen (`LayoutGame`). It fails when a control goes past the edge of the screen, when a label does not show all its text, or when a control that the player presses is smaller than 44 logical pixels.

We rejected these other ways:

- **Keep the fixed 1280 x 720 layout and only make the fonts larger.** On a phone, 1280 logical pixels across about 14 cm leave no room for larger text.
- **A layout for each kind of device.** Two or three layouts to keep in step, and devices between the kinds, such as large phones and small tablets, fit none well.
- **Read the DPI on all computers.** On Linux with X11, the DPI is the physical DPI of the monitor, which users do not expect to change the size of apps.
