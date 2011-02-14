//
//  FastSocket.h
//  Copyright (c) 2011 Daniel Reese <dan@danandcheryl.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>


@interface FastSocket : NSObject {

}

- (id)initWithHost:(NSString *)host andPort:(int)port error:(NSError **)error;

#pragma mark Actions

- (BOOL)connect:(NSError **)error;
- (BOOL)close:(NSError **)error;

- (long)sendBytes:(void *)buf count:(long)count error:(NSError **)error;
- (long)receiveBytes:(void *)buf limit:(long)limit error:(NSError **)error;

- (long)sendFile:(NSString *)path error:(NSError **)error;
- (long)receiveFile:(NSString *)path length:(long)length error:(NSError **)error;
- (long)receiveFile:(NSString *)path length:(long)length md5:(NSData **)hash error:(NSError **)error;
- (long)receiveFile:(NSString *)path length:(long)length sha1:(NSData **)hash error:(NSError **)error;

#pragma mark Settings

- (int)timeout:(NSError **)error;
- (BOOL)setTimeout:(int)seconds error:(NSError **)error;

- (int)segmentSize:(NSError **)error;
- (BOOL)setSegmentSize:(int)size error:(NSError **)error;

@end
