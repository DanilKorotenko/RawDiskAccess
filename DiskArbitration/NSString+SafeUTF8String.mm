//
//  NSString+SafeUTF8String.m
//
//  Created by Danil Korotenko on 6/5/20.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////

const char *GetSafeUTF8String(NSString *aString)
{
    return aString == nil ? "" : (([aString UTF8String] == NULL) ? "" : [aString UTF8String]);
}
