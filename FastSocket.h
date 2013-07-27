//
//  FastSocket.h
//  Copyright (c) 2011-2013 Daniel Reese <dan@danandcheryl.com>
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


#define NEW_ERROR(num, str) [[NSError alloc] initWithDomain:@"FastSocketErrorDomain" code:(num) userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%s", (str)] forKey:NSLocalizedDescriptionKey]]

@interface FastSocket : NSObject {
@protected
	void *buffer;
	long size;
	long timeout;
	int segmentSize;
}

@property (nonatomic, readonly) int sockfd;
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSString *port;
@property (nonatomic, readonly) NSError *lastError;

- (id)initWithHost:(NSString *)host andPort:(NSString *)port;
- (id)initWithFileDescriptor:(int)fd;
- (void)buffer:(void **)buf size:(long *)size;

#pragma mark Actions

- (BOOL)connect;
- (BOOL)isConnected;
- (BOOL)close;

- (long)sendBytes:(void *)buf count:(long)count;

/**
 * Receives an unpredictable number bytes up to the specified limit. Stores the bytes
 * in the given buffer and returns the actual number received.
 *
 * @param buf   The buffer in which to store the bytes received.
 * @param limit The maximum number of bytes to receive, typically the size of the buffer.
 *
 * @return The actual number of bytes received.
 */
- (long)receiveBytes:(void *)buf limit:(long)limit;

/**
 * Receives the exact number of bytes specified unless a timeout or other error occurs.
 * Stores the bytes in the given buffer and returns whether the correct number of bytes
 * was received.
 *
 * @param buf   The buffer in which to store the bytes received.
 * @param count The exact number of bytes to receive, typically the size of the buffer.
 *
 * @return YES if the correct number of bytes was received, NO otherwise.
 */
- (BOOL)receiveBytes:(void *)buf count:(long)count;

- (long)sendFile:(NSString *)path;
- (long)receiveFile:(NSString *)path length:(long)length;
- (long)receiveFile:(NSString *)path length:(long)length md5:(NSData **)hash;

#pragma mark Settings

- (long)timeout;
- (BOOL)setTimeout:(long)seconds;

- (int)segmentSize;
- (BOOL)setSegmentSize:(int)bytes;

@end
