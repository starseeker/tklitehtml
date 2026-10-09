The goal is to create a https://github.com/litehtml/litehtml based Tk widget
that is suitable to replace tkhtml3 and hv3 in BRL-CAD.  It is not necessary
that the API be identical - we can update our calling code if it makes sense
to create a more modern/cleaner Tcl/Tk API - but we need to support the key
features - link clicking, search and highlighting, find matching and highlighting,
etc.

tkhtml3/hv3 has long been unmaintained, and litehtml is active, so the concept
(if workable) is to use it as our core and implement the needed Tcl/Tk logic
on top of it.

external has a submodule of litehtml and the hv3/tkhtml sources currently used
by BRL-CAD.  brlcad_tcl has BRL-CAD's Tcl/Tk code, which should contain most
of its uses of tkhtml3 - as I said before, we don't need to match the API
but it should provide some sense of features.
