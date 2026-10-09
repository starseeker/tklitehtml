package require Tcl 8.6

if {[catch {package require Tk 8.6} message]} {
    puts "Tk tests skipped: $message"
    exit 77
}

package require tcltest 2
namespace import ::tcltest::test
::tcltest::configure -verbose start
::tcltest::testConstraint x11 [expr {[tk windowingsystem] eq "x11"}]

set packageIndex [lsearch -exact $argv -packagepath]
if {$packageIndex < 0 || $packageIndex + 1 >= [llength $argv]} {
    error "usage: all.tcl -packagepath directory"
}
lappend auto_path [file normalize [lindex $argv [expr {$packageIndex + 1}]]]
package require tklitehtml 0.1.0

proc makeWidget {args} {
    set widget [::tklitehtml::widget .html {*}$args]
    pack $widget -fill both -expand 1
    update
    return $widget
}

proc deleteWidget {} {
    if {[winfo exists .html]} {
        destroy .html
        update
    }
}

test package-1.1 {the extension provides its package and factory command} -body {
    list [package present tklitehtml] [namespace which ::tklitehtml::widget]
} -result {0.1.0 ::tklitehtml::widget}

test widget-1.1 {widget options support configure and cget} -setup {
    set widget [makeWidget -width 320 -height 180 -background #f8f8f8]
} -body {
    $widget configure -width 360 -height 200
    list [$widget cget -width] [$widget cget -height] [$widget cget -background]
} -cleanup {
    deleteWidget
} -result {360 200 #f8f8f8}

test document-1.1 {load exposes rendered Unicode text and character ranges} -setup {
    set widget [makeWidget]
    $widget load {<p>Hello Café world.</p><p>Hello café.</p>}
    update
} -body {
    set text [$widget text]
    set expectedFirst [string first Café $text]
    set expectedSecond [string first café $text [expr {$expectedFirst + 1}]]
    set ranges [$widget search -all -nocase café]
    list \
        [expr {[llength $ranges] == 2}] \
        [expr {[lindex $ranges 0 0] == $expectedFirst}] \
        [expr {[lindex $ranges 1 0] == $expectedSecond}] \
        [expr {[lindex $ranges 0 1] - [lindex $ranges 0 0] == 4}]
} -cleanup {
    deleteWidget
} -result {1 1 1 1}

test document-1.2 {user styles render and character boxes are queryable} -setup {
    set widget [makeWidget]
    $widget load -userstyle {body { font-size: 18px; } strong { color: #124578; }} \
        {<p>plain <strong>styled</strong> text</p>}
    update
} -body {
    set index [string first styled [$widget text]]
    lassign [$widget bbox $index] x y width height
    expr {$x >= 0 && $y >= 0 && $width > 0 && $height > 0}
} -cleanup {
    deleteWidget
} -result 1

test document-1.3 {title and fragment expose document navigation metadata} -setup {
    set widget [makeWidget -height 80]
    $widget load {<title>Navigation test</title><div style="height: 900px">top</div><h2 id="target">Target</h2>}
    update
} -body {
    $widget fragment target
    update
    list [$widget title] [expr {[lindex [$widget yview] 0] > 0.0}]
} -cleanup {
    deleteWidget
} -result {{Navigation test} 1}

test document-1.4 {text extraction preserves visual word and line boundaries} -setup {
    set widget [makeWidget]
    $widget load {<h2><span>Modeling</span> With CSG</h2><p>Second line</p>}
    update
} -body {
    set text [$widget text]
    list \
        [expr {[string first {Modeling With CSG} $text] >= 0}] \
        [expr {[string first "\n" $text] >= 0}]
} -cleanup {
    deleteWidget
} -result {1 1}

test search-1.1 {search option terminator permits a leading hyphen} -setup {
    set widget [makeWidget]
    $widget load {<p>-needle and needle</p>}
} -body {
    expr {[llength [$widget search -all -- -needle]] == 1}
} -cleanup {
    deleteWidget
} -result 1

test highlight-1.1 {named highlights accept, configure, and clear ranges} -setup {
    set widget [makeWidget]
    $widget load {<p>alpha beta alpha</p>}
    set ranges [$widget search -all alpha]
} -body {
    $widget highlight configure selection -background #80c0ff
    $widget highlight set selection $ranges
    update
    $widget highlight clear selection
    update
    set result ok
} -cleanup {
    deleteWidget
} -result ok

test find-1.1 {find tracks all matches and cycles the current match} -setup {
    set widget [makeWidget]
    $widget load {<p>one TWO one two</p>}
} -body {
    set count [$widget find set two]
    set first [$widget find current]
    $widget find next
    set second [$widget find current]
    $widget find previous
    list $count [expr {$first ne $second}] [expr {[$widget find current] eq $first}]
} -cleanup {
    deleteWidget
} -result {2 1 1}

proc recordScroll {first last} {
    set ::scrollFractions [list $first $last]
}

test scrolling-1.1 {standard view commands and scrollbar callbacks stay synchronized} -setup {
    set ::scrollFractions {}
    set widget [makeWidget -height 100 -yscrollcommand recordScroll]
    set paragraphs [string repeat {<p>scrolling content</p>} 80]
    $widget load $paragraphs
    update
} -body {
    $widget yview moveto 0.5
    update
    lassign [$widget yview] first last
    list [expr {$first > 0.0}] [expr {$last < 1.0}] [expr {[llength $::scrollFractions] == 2}]
} -cleanup {
    unset -nocomplain ::scrollFractions
    deleteWidget
} -result {1 1 1}

test scrolling-1.2 {X11 wheel buttons use portable class bindings} -constraints x11 -setup {
    set widget [makeWidget -width 100 -height 100]
    $widget load "<div style='width: 2000px'>wide</div>[string repeat {<p>wheel content</p>} 80]"
    update
} -body {
    set yBefore [lindex [$widget yview] 0]
    event generate $widget <Button-5> -x 10 -y 10
    update
    set xBefore [lindex [$widget xview] 0]
    event generate $widget <Shift-Button-5> -x 10 -y 10
    update
    list \
        [expr {[lindex [$widget yview] 0] > $yBefore}] \
        [expr {[lindex [$widget xview] 0] > $xBefore}] \
        [expr {[bind TkLiteHtml <MouseWheel>] ne ""}]
} -cleanup {
    deleteWidget
} -result {1 1 1}

proc testResource {widget kind url} {
    lappend ::resourceCalls [list $kind $url]
    if {$kind eq "image"} {
        return ::testImage
    }
    if {$kind eq "stylesheet"} {
        return {p { color: #2468ac; }}
    }
    return {}
}

test resources-1.1 {resource callbacks supply images and imported stylesheets} -setup {
    set ::resourceCalls {}
    image create photo ::testImage -width 3 -height 2
    ::testImage put #33aa55 -to 0 0 3 2
    set widget [makeWidget -resourcecommand testResource]
} -body {
    $widget load -baseurl https://example.invalid/docs/page.html {
        <link rel="stylesheet" href="theme.css">
        <p>resource</p><img src="picture.png" width="9" height="6">
    }
    update
    set kinds [lmap call $::resourceCalls {lindex $call 0}]
    list [expr {"stylesheet" in $kinds}] [expr {"image" in $kinds}]
} -cleanup {
    deleteWidget
    image delete ::testImage
    unset -nocomplain ::resourceCalls
} -result {1 1}

proc recordLink {widget url attributes} {
    set ::clickedLink [list $widget $url $attributes]
}

test links-1.1 {pointer activation invokes the link callback with metadata} -setup {
    unset -nocomplain ::clickedLink
    set widget [makeWidget -linkcommand recordLink]
    $widget load -baseurl https://example.invalid/docs/page.html {
        <p><a href="next.html" title="Next page" id="next-link">Open next</a></p>
    }
    update
} -body {
    set index [string first {Open next} [$widget text]]
    lassign [$widget bbox $index] x y width height
    event generate $widget <Motion> -x [expr {$x + 1}] -y [expr {$y + 1}]
    event generate $widget <ButtonPress-1> -x [expr {$x + 1}] -y [expr {$y + 1}]
    event generate $widget <ButtonRelease-1> -x [expr {$x + 1}] -y [expr {$y + 1}]
    update
    list \
        [lindex $::clickedLink 0] \
        [lindex $::clickedLink 1] \
        [dict get [lindex $::clickedLink 2] title] \
        [dict get [lindex $::clickedLink 2] id]
} -cleanup {
    unset -nocomplain ::clickedLink
    deleteWidget
} -result {.html https://example.invalid/docs/next.html {Next page} next-link}

test browser-1.1 {local browser follows relative links, fragments, and history} -setup {
    set testDirectory [file normalize [file join [::tcltest::temporaryDirectory] browser-test-[pid]]]
    file mkdir $testDirectory
    set firstPath [file join $testDirectory {first page.html}]
    set secondPath [file join $testDirectory second.html]
    set channel [open $firstPath w]
    puts $channel {<title>First</title><p>First page</p>}
    close $channel
    set channel [open $secondPath w]
    puts $channel {<title>Second</title><div style="height: 900px">Second page</div><h2 id="last">Last</h2>}
    close $channel
    set browser [::tklitehtml::browser .browser -width 240 -height 80]
    pack $browser -fill both -expand 1
    $browser goto $firstPath
    update
} -body {
    $browser goto second.html#last
    update
    set second [list [$browser title] [expr {[lindex [[$browser html] yview] 0] > 0.0}]]
    $browser back
    update
    list \
        $second \
        [$browser title] \
        [expr {[::tklitehtml::local_path [$browser location]] eq $firstPath}] \
        [expr {[winfo exists [$browser html]]}]
} -cleanup {
    catch {destroy .browser}
    update
    file delete -force $testDirectory
} -result {{Second 1} First 1 1}

test browser-1.2 {file URI conversion preserves Unicode and reserved path characters} -body {
    set path [file normalize [file join [::tcltest::temporaryDirectory] {manual # é.html}]]
    expr {[::tklitehtml::local_path [::tklitehtml::file_uri $path]] eq $path}
} -result 1

test errors-1.1 {invalid arity reports an error without destabilizing the widget} -setup {
    set widget [makeWidget]
} -body {
    set results {}
    foreach command {
        {load}
        {search}
        {highlight}
        {highlight clear one two}
        {find}
        {find next extra}
        {fragment}
        {bbox -1}
        {xview moveto}
    } {
        lappend results [catch {$widget {*}$command}]
    }
    set results
} -cleanup {
    deleteWidget
} -result {1 1 1 1 1 1 1 1 1}

test lifecycle-1.1 {clear and command deletion release widget-owned resources} -setup {
    set widget [makeWidget]
    $widget load {<p>temporary document</p>}
    update
} -body {
    $widget clear
    set empty [expr {[$widget text] eq ""}]
    set noFind [expr {[$widget find current] eq ""}]
    rename $widget {}
    update
    list $empty $noFind [winfo exists .html] [llength [info commands .html]]
} -cleanup {
    deleteWidget
} -result {1 1 0 0}

wm withdraw .
proc finishTests {} {
    set failed $::tcltest::numTests(Failed)
    # cleanupTests otherwise exits directly when Tk is non-interactive,
    # preventing the failure count from becoming the process status.
    ::tcltest::testConstraint interactive true
    ::tcltest::cleanupTests
    exit [expr {$failed != 0}]
}
finishTests
