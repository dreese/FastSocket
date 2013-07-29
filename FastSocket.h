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

/**
 Retrieves the internal buffer and its size for use outside the class. This buffer is good
 to use for sending and receiving bytes because it is a multiple of the segment size and
 allocated so that it is aligned on a memory page boundary.
 
 @return YES if the connection succeeded, NO otherwise.
 */
- (void)buffer:(void **)buf size:(long *)size;

#pragma mark Actions

/**
 Connect the socket to the remote host.
 
 @return YES if the connection succeeded, NO otherwise.
 */
- (BOOL)connect;

/**
 Returns whether the socket is currently connected.
 
 @return YES if the socket is connected, NO otherwise.
 */
- (BOOL)isConnected;

/**
 Closes the connection to the remote host.
 
 @return YES if the close succeeded, NO otherwise.
 */
- (BOOL)close;

/**
 Sends the specified number bytes from the given buffer.
 
 @param buf   The buffer containing the bytes to send.
 @param count The number of bytes to send, typically the size of the buffer.
 @return The actual number of bytes sent.
 */
- (long)sendBytes:(void *)buf count:(long)count;

/**
 Receives an unpredictable number bytes up to the specified limit. Stores the bytes
 in the given buffer and returns the actual number received.
 
 @param buf   The buffer in which to store the bytes received.
 @param limit The maximum number of bytes to receive, typically the size of the buffer.
 @return The actual number of bytes received.
 */
- (long)receiveBytes:(void *)buf limit:(long)limit;

/**
 Receives the exact number of bytes specified unless a timeout or other error occurs.
 Stores the bytes in the given buffer and returns whether the correct number of bytes
 was received.
 
 @param buf   The buffer in which to store the bytes received.
 @param count The exact number of bytes to receive, typically the size of the buffer.
 @return YES if the correct number of bytes was received, NO otherwise.
 */
- (BOOL)receiveBytes:(void *)buf count:(long)count;

/**
 Sends the contents of the file at the specified path. Uses an internal buffer to read
 a block of data from the file and send it over the network.
 
 @param path The path of the file to send.
 @return The actual number of bytes sent.
 */
- (long)sendFile:(NSString *)path;

/**
 Receives a file with the given length and writes it to the specified path. Uses an
 internal buffer to receive a block of data from the network and write it to disk.
 Overwrites any existing file.
 
 @param path   The path of the file to create.
 @param length The length of the file, measured in bytes.
 @return The actual number of bytes received.
 */
- (long)receiveFile:(NSString *)path length:(long)length;

/**
 Receives a file with the given length and writes it to the specified path and calculates
 its MD5 hash. The hash can be used for error checking. Uses an internal buffer to receive
 a block of data from the network and write it to disk. Overwrites any existing file.
 
 @param path   The path of the file to create.
 @param length The length of the file, measured in bytes.
 @param hash   An optional data object in which to store the calculated MD5 hash of the file.
 @return The actual number of bytes received.
 */
- (long)receiveFile:(NSString *)path length:(long)length md5:(NSData **)hash;

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

/**
 Returns the maximum segment size. The segment size is the largest amount of
 data that can be transmitted within a single packet. Too large of a value may result in packets
 being broken apart and reassembled during transmission, which is normal but can slow things
 down. Too small of a value may result in lots of overhead, which can also slow things down.
 
 A default value is automatically negotiated when a connection is established. However, the
 negotiation process may incorporate assumptions that are incorrect. If you understand the
 network condidtions, setting this value correctly may increase performance.
 
 @return The current maximum segment value, measured in bytes.
 */
- (int)segmentSize;

/**
 Sets the maximum segment size. The segment size is the largest amount of
 data that can be transmitted within a single packet, excluding headers. Too large of a value
 may result in packets being broken apart and reassembled during transmission, which is normal
 but can slow things down. Too small of a value may result in lots of overhead, which can
 also slow things down.
 
 A default value is automatically negotiated when a connection is established. However, the
 negotiation process may incorporate assumptions that are incorrect. If you understand the
 network condidtions, setting this value correctly may increase performance.
 
 @param bytes The maximum segment size, measured in bytes.
 @return YES if the segment size value was set successfully, NO otherwise.
 */
- (BOOL)setSegmentSize:(int)bytes;

@end
