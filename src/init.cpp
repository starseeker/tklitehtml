#include "widget.h"

#include <tcl.h>
#include <tk.h>

#if defined(_WIN32)
#define TKLITEHTML_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define TKLITEHTML_EXPORT __attribute__((visibility("default")))
#else
#define TKLITEHTML_EXPORT
#endif

extern "C" TKLITEHTML_EXPORT int Tklitehtml_Init(Tcl_Interp* interp)
{
    if(Tcl_InitStubs(interp, "8.6", 0) == nullptr || Tk_InitStubs(interp, "8.6", 0) == nullptr)
    {
        return TCL_ERROR;
    }

    Tcl_Namespace* ns = Tcl_FindNamespace(interp, "::tklitehtml", nullptr, 0);
    if(ns == nullptr)
    {
        ns = Tcl_CreateNamespace(interp, "::tklitehtml", nullptr, nullptr);
        if(ns == nullptr)
        {
            return TCL_ERROR;
        }
    }

    if(tklitehtml::register_widget_command(interp) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return Tcl_PkgProvide(interp, "tklitehtml", "0.1.0");
}
