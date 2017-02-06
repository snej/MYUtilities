//
//  ExceptionUtils.h
//  MYUtilities
//
//  Created by Jens Alfke on 1/5/08.
//  Copyright 2008-2013 Jens Alfke. All rights reserved.
//  See BSD license at bottom of ExceptionUtils.m.
//

#import <Foundation/Foundation.h>


#ifdef NSAppKitVersionNumber10_4 // only enable this in a project that uses AppKit
/** Edit your Info.plist to make this your app's principal class,
    and most exceptions will be reported via a modal alert. 
    This includes exceptions caught by AppKit (i.e. uncaught ones from event handlers)
    and ones you report yourself via MYReportException and @catchAndReport. */
@interface MYExceptionReportingApplication : NSApplication
@end
#endif


/** A useful macro to use in code where you absolutely cannot allow an exception to 
    go uncaught because it would crash (e.g. in a C callback or at the top level of a thread.)
    It catches the exception but makes sure it gets reported. */
#define catchAndReport(MSG...) @catch(NSException *x) {MYReportException(x,MSG);}


/** Report an exception that's being caught and consumed.
    Logs a warning to the console, and calls the current MYReportException target if any. */
void MYReportException( NSException *x, NSString *where, ... );


/** Sets a callback to be invoked when MYReportException is called.
    In a GUI app, the callback would typically call [NSApp reportException: theException].
    The ExceptionReportingApplication class, below, sets this up automatically. */
void MYSetExceptionReporter( void (*reporter)(NSException*) );


@interface NSException (MYUtilities)
/** Returns a textual, human-readable backtrace of the point where the exception was thrown. */
- (NSString*) my_callStack;
@end


#if DEBUG
    /** Returns true if the current process is being debugged -- either launched from the debugger,
        or has had a debugger attached to it. Not available in a non-debug build (always returns
        false) because the check it performs isn't ABI-stable. */
    bool MYIsDebuggerAttached(void);
#else
    #define MYIsDebuggerAttached()  false
#endif

#if TARGET_CPU_X86_64 || TARGET_CPU_X86
/** Pauses the debugger at the call to this macro, as though there were a breakpoint on it.
    Has no effect if no debugger is attached, or in a non-debug build. */
#define MYBreakpoint() ({ if (MYIsDebuggerAttached()) {__asm__("int $3\n" : : );} })
#else
void _MYBreakpoint(void);
#define MYBreakpoint() ({ if (MYIsDebuggerAttached()) {_MYBreakpoint();} })
#endif
