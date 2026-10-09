package require Tcl 8.6

if {[catch {package require Tk 8.6} message]} {
    puts "Tk performance test skipped: $message"
    exit 77
}

set packageIndex [lsearch -exact $argv -packagepath]
if {$packageIndex < 0 || $packageIndex + 1 >= [llength $argv]} {
    error "usage: performance.tcl -packagepath directory"
}
lappend auto_path [file normalize \
    [lindex $argv [expr {$packageIndex + 1}]]]
package require tklitehtml 0.1.0

proc measureDocument {paragraphCount} {
    set paragraph {
        <p>The quick brown fox jumps over the lazy dog.</p>
    }
    set html [string repeat $paragraph $paragraphCount]
    set started [clock microseconds]
    .html load $html
    set loadMicroseconds [expr {[clock microseconds] - $started}]
    set started [clock microseconds]
    .html text
    set indexMicroseconds [expr {[clock microseconds] - $started}]
    return [expr {$loadMicroseconds + $indexMicroseconds}]
}

set widget [::tklitehtml::widget .html -width 800 -height 600]
pack $widget -fill both -expand true
update

set warmParagraphCount 100
set smallParagraphCount 750
set largeParagraphCount 1500
set maximumScale 3
set timingToleranceMicroseconds 250000
set maximumHighlightMicroseconds 5000000

# Warm caches before comparing the two document sizes.
measureDocument $warmParagraphCount
set smallMicroseconds [measureDocument $smallParagraphCount]
set largeMicroseconds [measureDocument $largeParagraphCount]
set allowedMicroseconds [expr {
    $smallMicroseconds * $maximumScale + $timingToleranceMicroseconds
}]
set started [clock microseconds]
$widget find set fox
$widget yview moveto 1
update
set highlightMicroseconds [expr {[clock microseconds] - $started}]

destroy .html
if {$largeMicroseconds > $allowedMicroseconds} {
    puts stderr [format \
        {document processing scaled unexpectedly: %d us -> %d us} \
        $smallMicroseconds $largeMicroseconds]
    exit 1
}
if {$highlightMicroseconds > $maximumHighlightMicroseconds} {
    puts stderr "highlight painting took $highlightMicroseconds us"
    exit 1
}
puts [format {document processing: %d us -> %d us; highlight: %d us} \
    $smallMicroseconds $largeMicroseconds $highlightMicroseconds]
exit 0
