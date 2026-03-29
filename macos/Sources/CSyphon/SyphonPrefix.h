// Prefix header for Syphon SPM build
// Replaces Syphon_Prefix.pch

#ifdef __OBJC__
    #import <Cocoa/Cocoa.h>

    #ifdef DEBUG
        #define SYPHONLOG(format, ...)  NSLog(@"SYPHON DEBUG: %@: %@", NSStringFromClass([self class]), [NSString stringWithFormat:format, ##__VA_ARGS__]);
    #else
        #define SYPHONLOG(format, ...)
    #endif
#endif
