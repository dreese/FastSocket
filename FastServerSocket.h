//
//  FastServerSocket.h
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

@class FastSocket;
@interface FastServerSocket : NSObject {
@protected
	long timeout;
}

@property (nonatomic, readonly) int sockfd;
@property (nonatomic, readonly) NSString *port;
@property (nonatomic, readonly) NSError *lastError;

- (id)initWithPort:(NSString *)port;
- (id)initWithFileDescriptor:(int)fd;

#pragma mark Actions

/**
 Starts listening for incoming connections.
 
 @return YES if the listen succeeded, NO otherwise.
 */
- (BOOL)listen;

/**
 Accepts an incoming connection from a remote host. Blocks until a connection is received.
 
 @return A socket connected to the remote host.
 */
- (FastSocket *)accept;

/**
 Closes the connection to the remote host.
 
 @return YES if the close succeeded, NO otherwise.
 */
- (BOOL)close;

#pragma mark Settings

/**
 Returns the number of seconds to wait without any network activity before giving up and
 returning an error. The default is zero seconds, in which case it will never time out.
 
 @return The current timeout value in seconds.
 */
- (long)timeout;

/**
 Sets the number of seconds to wait without any network activity before giving up and
 returning an error. The default is zero seconds, in which case it will never time out.
 
 @param seconds The number of seconds to wait before timing out.
 @return YES if the timeout value was set successfully, NO otherwise.
 */
- (BOOL)setTimeout:(long)seconds;

@end
