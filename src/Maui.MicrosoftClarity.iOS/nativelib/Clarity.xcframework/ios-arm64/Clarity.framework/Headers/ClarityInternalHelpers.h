#ifndef ClarityInternalHelpers_h
#define ClarityInternalHelpers_h

#import <Foundation/Foundation.h>

@interface ClarityInternalHelpers : NSObject

+ (id)safeValueForKey:(NSString *)key fromObject:(id)object;

+ (id)safeExecuteBlock:(id (^)(void))block catch:(void (^)(NSException *))catchBlock finally:(void (^)(void))finallyBlock;

@end

#endif /* ClarityInternalHelpers_h */
