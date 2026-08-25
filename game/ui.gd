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
static func can_install() -> bool:
	if not OS.has_feature("web"):
		return false
	var value: Variant = JavaScriptBridge.eval(
		"(window.__cz_can_install && window.__cz_can_install()) || false", true)
	return typeof(value) == TYPE_BOOL and bool(value)


## Asks the browser to show its install prompt. The browser decides what that
## looks like; all this can do is ask, and only in response to a tap.
static func install() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__cz_install && window.__cz_install()", true)


## Already running as an installed app rather than in a browser tab.
static func installed() -> bool:
	if not OS.has_feature("web"):
		return false
	var value: Variant = JavaScriptBridge.eval(
		"(window.__cz_installed && window.__cz_installed()) || false", true)
	return typeof(value) == TYPE_BOOL and bool(value)


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
