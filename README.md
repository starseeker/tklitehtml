# TkLiteHtml

TkLiteHtml is a native Tcl/Tk widget backed by
[litehtml](https://github.com/litehtml/litehtml). It is intended to provide the
HTML viewing, link handling, search, find, and highlighting capabilities needed
to replace tkhtml3 and Hv3 in BRL-CAD.

The renderer deliberately has a small dependency surface: Tcl/Tk and litehtml.
It does not use Cairo, Pango, or a platform graphics API directly. Backgrounds,
images, borders, gradients, and highlights are composed into an RGBA buffer and
uploaded through Tk's photo API; text measurement and drawing use Tk's public
font APIs. This keeps the implementation applicable to X11, Windows, macOS
Aqua, and other Tk ports.

## Build

Initialize the litehtml submodule, then configure and build with CMake:

```sh
git submodule update --init
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
cmake --install build --prefix /desired/prefix
```

For dependency-managed builds, set `TKLITEHTML_USE_BUNDLED_LITEHTML=OFF` and
provide litehtml's CMake package on `CMAKE_PREFIX_PATH`. The install exports a
`tklitehtml` CMake target so dependency managers can expose it to consumers;
BRL-CAD can then use that target to order staging without linking the module
into its executables.

The build uses Tcl and Tk stubs. If CMake cannot find the intended Tcl/Tk
installation, set `TCL_LIBRARY`, `TK_LIBRARY`, `TCL_STUB_LIBRARY`,
`TK_STUB_LIBRARY`, `TCL_INCLUDE_PATH`, and `TK_INCLUDE_PATH` explicitly.
`TK_PLATFORM_INCLUDE_PATH` may also be set when a Unix Tk installation keeps
the platform headers referenced by `tk.h` outside the compiler's normal include
path. These are build inputs only; TkLiteHtml does not link to X11 or Xmin.

GUI tests require a display. They return CTest's skip code when Tk cannot open
one. The same suite can be run under Xvfb, Xmin, or a native desktop session.

## Basic use

```tcl
package require Tk
package require tklitehtml 0.1.0

scrollbar .scroll -command {.html yview}
tklitehtml::widget .html \
    -yscrollcommand {.scroll set} \
    -linkcommand openLink \
    -resourcecommand loadResource

pack .scroll -side right -fill y
pack .html -side left -fill both -expand 1

.html load -baseurl https://example.invalid/help/index.html {
    <h1>Help</h1>
    <p>Read the <a href="commands.html">command reference</a>.</p>
}
```

Mouse-wheel bindings are installed for the `TkLiteHtml` widget class. They
normalize X11 button events and Win32/Aqua `<MouseWheel>` deltas, including
Shift-wheel horizontal scrolling, into the widget's `xview` and `yview`
commands.

## Widget API

Create a widget with:

```tcl
tklitehtml::widget pathName ?option value ...?
```

Supported options are:

- `-width`, `-height`, and `-background`
- `-xscrollcommand` and `-yscrollcommand`
- `-linkcommand`
- `-resourcecommand`

The widget command supports:

```text
pathName load ?-baseurl uri? ?-userstyle css? html
pathName clear
pathName configure ?option? ?value ...?
pathName cget option
pathName text
pathName search ?-all? ?-nocase? ?--? pattern
pathName highlight configure name -background color
pathName highlight set name ranges
pathName highlight clear ?name?
pathName find set ?-case? pattern
pathName find current|next|previous|clear
pathName fragment identifier
pathName bbox index
pathName see index
pathName title
pathName xview ?moveto fraction|scroll count units|pages?
pathName yview ?moveto fraction|scroll count units|pages?
```

Text indexes are Unicode character offsets. Search and highlight ranges are
half-open `{first last}` pairs, so `last` is the first character after the
match. `search` returns the first range unless `-all` is specified. `find set`
highlights all matches, selects the first, and returns the match count;
`find next` and `find previous` cycle the current match and scroll it into view.
`fragment` scrolls to an element by HTML `id`, and `title` returns the current
document title.

## Local document browser

For applications that need navigation rather than a single rendered document,
the package also supplies a composite browser:

```tcl
set browser [tklitehtml::browser .browser]
pack $browser -fill both -expand 1
$browser goto /path/to/index.html
```

The browser adds scrollbars and supports `goto`, `back`, `location`, `title`,
and `html` (which returns the underlying widget). Relative and fragment links,
file URIs, percent-encoded paths, and navigation history are handled without an
HTTP client. A `-linkcommand` callback may replace the default navigation; it
receives the browser path, resolved URL, and link attribute dictionary. The
portable `tklitehtml::file_uri` and `tklitehtml::local_path` commands convert
between local paths and file URIs.

### Link callback

The command prefix supplied with `-linkcommand` receives the widget path,
resolved URL, and a dictionary of available `href`, `title`, `id`, and `class`
attributes:

```tcl
proc openLink {widget url attributes} {
    puts "open $url"
}
```

Fragment links scroll within the current document before invoking the callback.

### Resource callback

The command prefix supplied with `-resourcecommand` receives the widget path,
resource kind, and resolved URL:

```tcl
proc loadResource {widget kind url} {
    switch -- $kind {
        image      { return myTkPhotoImage }
        stylesheet { return {body { color: #222; }} }
    }
    return {}
}
```

For `image`, return the name of a Tk photo image. For `stylesheet`, return CSS
text. When the callback returns nothing, local image and stylesheet paths are
loaded directly. Network access is intentionally left to the embedding
application.

## Current rendering scope

The widget implements the core static-document path: Tk fonts and text,
software-composited colors and transparency, rectangular borders, list
markers, Tk photo images, linear gradients, clipping, links, scrolling, and
responsive relayout. Radial and conic gradients currently use a solid-color
fallback, and rounded border rasterization is not yet implemented. JavaScript,
forms, and an HTTP client are outside the widget's scope.
