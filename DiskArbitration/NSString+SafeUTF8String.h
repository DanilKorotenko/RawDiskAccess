//
//  NSString+SafeUTF8String.h
//
//  Created by Danil Korotenko on 6/5/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

const char *GetSafeUTF8String(NSString *aString);

NS_ASSUME_NONNULL_END
