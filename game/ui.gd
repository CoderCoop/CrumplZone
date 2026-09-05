class_name UI
extends RefCounted

## One conversion, used by every screen: how many viewport units make a CSS
## pixel on the device the game is actually running on.
##
## This exists because the mobile-first rule in AGENTS.md is written in real
## screen units — "touch targets are at least 44x44 px of *real* screen" — and
## Godot lays out in viewport units, which are not that. With the project's
## 800x600 base and an expanding aspect, a phone at 390 CSS px wide and a 2x
## display renders one viewport unit at about half a CSS pixel: a 58-unit
## button measures 28 px under a thumb. Measured in a browser, not guessed —
## see the tools/ screenshots on the pull request that introduced this.
##
## Laying UI out in CSS pixels and scaling the CanvasLayer by this factor makes
## a 44-unit control 44 px on a phone, on a laptop, and on a 4K monitor.

## Cached, because the JavaScript round trip is not free and the answer only
## changes when the window moves between displays.
static var _ratio := 0.0


## Viewport units per CSS pixel. Multiply a CSS-pixel size by this, or scale a
## CanvasLayer by it and lay its contents out in CSS pixels directly.
static func units_per_css(viewport: Viewport) -> float:
	# x.x of the screen transform is physical pixels per viewport unit: the
	# stretch factor Godot chose for this window size.
	var stretch := viewport.get_screen_transform().x.x
	if stretch <= 0.0:
		return 1.0
	return device_pixel_ratio() / stretch


## Can the browser offer to install this as an app? True only where the
## browser has fired the install prompt event and it has not been used yet —
## so never on a desktop that has already installed it, and never on iOS
## Safari, which has no such event and needs Share → Add to Home Screen.
## Answered as a number, not a boolean. A JavaScript `true` came back from the
## bridge as something that did not test as TYPE_BOOL, so the game read "no
## install on offer" while the page itself was answering yes and the button
## never appeared. Numbers survive the trip.
static func can_install() -> bool:
	return _ask("(window.__cz_can_install && window.__cz_can_install()) ? 1 : 0")


## Runs a probe that answers 1 or 0 and reports whether it said 1.
static func _ask(probe: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var value: Variant = JavaScriptBridge.eval(probe, true)
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return int(value) == 1
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			return String(value) == "1"
	return false


## Asks the browser to show its install prompt. The browser decides what that
## looks like; all this can do is ask, and only in response to a tap.
static func install() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__cz_install && window.__cz_install()", true)


## Tells the page whether the install button is on screen. The browser will
## not say whether a game drawn on a canvas is offering anything, so the build
## says so itself — which is what lets tools/verify-pwa.js check the offer
## end to end rather than checking that the hooks exist and hoping.
static func report_install_button(visible: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__cz_install_button = %s"
			% ("true" if visible else "false"), true)


## A newer build has arrived and is waiting to take over.
##
## The page watches for it; this only asks. Godot's service worker is
## cache-first over the whole app, so a player who does not ask keeps the build
## they first loaded — which matters when the game is being changed daily.
static func update_ready() -> bool:
	return _ask("(window.__cz_update_ready && window.__cz_update_ready()) ? 1 : 0")


## Switches to the newer build. The page reloads, so nothing after this runs.
##
## Called only where losing the current run costs nothing — the help screen and
## the end of a level — because this throws away a level in progress.
static func apply_update() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__cz_apply_update && window.__cz_apply_update()", true)


## Already running as an installed app rather than in a browser tab.
static func installed() -> bool:
	return _ask("(window.__cz_installed && window.__cz_installed()) ? 1 : 0")


## Physical pixels per CSS pixel. 1.0 anywhere that cannot say — a desktop
## export, the headless harnesses — which is the right answer there.
static func device_pixel_ratio() -> float:
	if _ratio > 0.0:
		return _ratio
	_ratio = 1.0
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			_ratio = clampf(float(value), 1.0, 4.0)
	return _ratio


## Lets a touch drag through a control tree to whatever is scrolling behind it.
##
## A ScrollContainer only drag-scrolls from events that actually reach it, and
## a Control with MOUSE_FILTER_STOP ends that chain. Every Button is STOP by
## default and so is every bare Control, which on a phone means the drag dies
## wherever the finger happened to land.
##
## Measured on the intro screen before this existed, counting events arriving
## at the ScrollContainer for one identical 12-step drag:
##
##      5% down the column, over a Label      24
##     15% down, over a spacer Control         0
##     30% down, over a Label                 24
##     50% down, over a district pin Button    0
##     70% down, over the city map             0
##     90% down, over a level tile Button      0
##
## STOP becomes PASS rather than IGNORE, so a button still takes its own taps
## and the scroll behind it hears the drag as well. A control that is already
## IGNORE or PASS is left alone.
static func let_drags_through(root: Control) -> void:
	if root.mouse_filter == Control.MOUSE_FILTER_STOP:
		root.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in root.get_children():
		if child is Control:
			let_drags_through(child as Control)
