//
//  FastSocket.m
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

//
//  See the following for source information for this code:
//  http://beej.us/guide/bgnet/
//  http://www.phildev.net/mss/blackhole_description.shtml
//  http://www.mikeash.com/pyblog/friday-qa-2011-02-18-compound-literals.html
//  http://cr.yp.to/docs/connect.html
//
//  Set optimal packet size: 1500 bytes (Ethernet) - 40 bytes (TCP) - 12 bytes (Optional TCP timestamp) = 1448 bytes.
//  http://www.faqs.org/docs/gazette/tcp.html
//  http://smallvoid.com/article/windows-tcpip-settings.html
//  http://developer.apple.com/mac/library/documentation/Darwin/Reference/ManPages/man4/tcp.4.html
//
//  Disk caching is not needed unless the file will be accessed again soon (avoids
//  a buffer copy). Increasing the size of the TCP receive window is better for
//  fast networks. Using page-aligned memory allows the kernel to skip a buffer
//  copy. Using a multiple of the max segment size avoids partially filled network
//  buffers. Ethernet and IPv4 headers are each 20 bytes. OS X uses the optional
//  12 byte TCP timestamp. Disabling TCP wait (Nagle's algorithm) is better for
//  sending files since all packets are large and the waiting slows things down.
//


#import "FastSocket.h"
#import <CommonCrypto/CommonDigest.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include <sys/time.h>

int connect_timeout(int sockfd, const struct sockaddr *address, socklen_t address_len, long timeout);


@interface FastSocket () {
@protected
	void *_buffer;
	long _size;
	float _timeout;
	int _segmentSize;
}
@end


@implementation FastSocket

- (id)initWithHost:(NSString *)remoteHost andPort:(NSString *)remotePort {
	if ((self = [super init])) {
		_sockfd = 0;
		_host = [remoteHost copy];
		_port = [remotePort copy];
		_size = getpagesize() * 1448 / 4;
		_buffer = valloc(_size);
	}
	return self;
}

- (id)initWithFileDescriptor:(int)fd {
	if ((self = [super init])) {
		// Assume the descriptor is an already connected socket.
		_sockfd = fd;
		_size = getpagesize() * 1448 / 4;
		_buffer = valloc(_size);
		
		// Instead of receiving a SIGPIPE signal, have write() return an error.
		if (setsockopt(_sockfd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int)) < 0) {
			_lastError = NEW_ERROR(errno, strerror(errno));
			return nil;
		}
		
		// Disable Nagle's algorithm.
		if (setsockopt(_sockfd, IPPROTO_TCP, TCP_NODELAY, &(int){1}, sizeof(int)) < 0) {
			_lastError = NEW_ERROR(errno, strerror(errno));
			return nil;
		}
		
		// Increase receive buffer size.
		if (setsockopt(_sockfd, SOL_SOCKET, SO_RCVBUF, &_size, sizeof(_size)) < 0) {
			// Ignore this because some systems have small hard limits.
		}
		
		// Set timeout or segment size if requested.
		if (_timeout != 0.0f && ![self setTimeout:_timeout]) {
			return nil;
		}
	}
	return self;
}

- (void)buffer:(void **)outBuf size:(long *)outSize {
	if (outBuf && outSize) {
		*outBuf = _buffer;
		*outSize = _size;
	}
}

- (void)dealloc {
	[self close];
	free(_buffer);
}

#pragma mark Actions

- (BOOL)connect {
	return [self connect:0];
}

- (BOOL)connect:(long)nsec {
	// Construct server address information.
	struct addrinfo hints, *serverinfo, *p;
	
	bzero(&hints, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	
	int error = getaddrinfo([_host UTF8String], [_port UTF8String], &hints, &serverinfo);
	if (error) {
		_lastError = NEW_ERROR(error, gai_strerror(error));
		return NO;
	}
	
	// Loop through the results and connect to the first we can.
	@try {
		for (p = serverinfo; p != NULL; p = p->ai_next) {
			if ((_sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Instead of receiving a SIGPIPE signal, have write() return an error.
			if (setsockopt(_sockfd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int)) < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Disable Nagle's algorithm.
			if (setsockopt(_sockfd, IPPROTO_TCP, TCP_NODELAY, &(int){1}, sizeof(int)) < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Increase receive buffer size.
			if (setsockopt(_sockfd, SOL_SOCKET, SO_RCVBUF, &_size, sizeof(_size)) < 0) {
				// Ignore this because some systems have small hard limits.
			}
			
			if (nsec) {
				// Connect the socket using the given timeout.
				if (connect_timeout(_sockfd, p->ai_addr, p->ai_addrlen, nsec) < 0) {
					_lastError = NEW_ERROR(errno, strerror(errno));
					continue;
				}
			}
			else {
				// Connect the socket (default connect timeout is 75 seconds).
				if (connect(_sockfd, p->ai_addr, p->ai_addrlen) < 0) {
					_lastError = NEW_ERROR(errno, strerror(errno));
					continue;
				}
			}
			
			// Set timeout or segment size if requested.
			if (_timeout != 0.0f && ![self setTimeout:_timeout]) {
				return NO;
			}
			if (_segmentSize && ![self setSegmentSize:_segmentSize]) {
				return NO;
			}
			
			// Found a working address, so move on.
			break;
		}
		if (p == NULL) {
			_lastError = NEW_ERROR(1, "Could not contact server");
			return NO;
		}
	}
	@finally {
		freeaddrinfo(serverinfo);
	}
	return YES;
}

- (BOOL)isConnected {
	if (_sockfd == 0) {
		return NO;
	}
	
	struct sockaddr remoteAddr;
	if (getpeername(_sockfd, &remoteAddr, &(socklen_t){sizeof(remoteAddr)}) < 0) {
		_lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	return YES;
}

- (BOOL)close {
	if (_sockfd > 0 && close(_sockfd) < 0) {
		_lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	_sockfd = 0;
	return YES;
}

- (long)sendBytes:(const void *)buf count:(long)count {
	long sent;
	if ((sent = send(_sockfd, buf, count, 0)) < 0) {
		_lastError = NEW_ERROR(errno, strerror(errno));
	}
	return sent;
}

- (long)receiveBytes:(void *)buf limit:(long)limit {
	long received = recv(_sockfd, buf, limit, 0);
	if (received < 0) {
		_lastError = NEW_ERROR(errno, strerror(errno));
	}
	return received;
}

- (long)receiveBytes:(void *)buf count:(long)count {
	long expected = count;
	while (expected > 0) {
		long received = [self receiveBytes:buf limit:expected];
		if (received < 1) {
			break;
		}
		expected -= received;
		buf += received;
	}
	return (count - expected);
}

- (long)sendFile:(NSString *)path {
	int fd = 0;
	long sent = 0;
	@try {
		const char *cPath = [path fileSystemRepresentation];
		if ((fd = open(cPath, O_RDONLY)) < 0) {
			_lastError = NEW_ERROR(errno, strerror(errno));
			return -1;
		}
		if (fcntl(fd, F_NOCACHE, 1) < 0) {
			// Ignore because this will still work with disk caching on.
		}
		
		long count;
		while (1) {
			count = read(fd, _buffer, _size);
			if (count == 0) {
				break; // Reached end of file.
			}
			if (count < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			if ([self sendBytes:_buffer count:count] < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			sent += count;
		}
	}
	@finally {
		close(fd);
	}
	return sent;
}

- (long)receiveFile:(NSString *)path length:(long)length {
	return [self receiveFile:path length:length md5:nil];
}

- (long)receiveFile:(NSString *)path length:(long)length md5:(NSData **)outHash {
	int fd = 0;
	long remaining = length;
	@try {
		const char *cPath = [path fileSystemRepresentation];
		if ((fd = open(cPath, O_WRONLY | O_CREAT | O_TRUNC, 0664)) < 0) {
			_lastError = NEW_ERROR(errno, strerror(errno));
			return -1;
		}
		if (fcntl(fd, F_NOCACHE, 1) < 0) {
			// Ignore because this will still work with disk caching on.
		}
		
		uint8_t digest[CC_MD5_DIGEST_LENGTH];
		CC_MD5_CTX context;
		if (outHash) {
			CC_MD5_Init(&context);
		}
		
		long received;
		while (remaining > 0) {
			received = [self receiveBytes:_buffer limit:MIN(length, _size)];
			if (received == 0) {
				break; // Peer closed the connection.
			}
			if (received < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			if (write(fd, _buffer, received) < 0) {
				_lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			if (outHash) {
				CC_MD5_Update(&context, _buffer, (CC_LONG)received);
			}
			remaining -= received;
		}
		
		if (outHash) {
			CC_MD5_Final(digest, &context);
			*outHash = [NSData dataWithBytes:digest length:CC_MD5_DIGEST_LENGTH];
		}
	}
	@finally {
		close(fd);
	}
	return (length - remaining);
}

#pragma mark Settings

- (float)timeout {
	if (_sockfd > 0) {
		struct timeval tv;
		if (getsockopt(_sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, &(socklen_t){sizeof(tv)}) < 0) {
			_lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
		_timeout = ((tv.tv_sec * 1000000L) + tv.tv_usec) / 1000000.0f;
	}
	return _timeout;
}

- (BOOL)setTimeout:(float)seconds {
	NSAssert(seconds >= 0.0, @"Timeout value must be positive");
	if (_sockfd > 0) {
		struct timeval tv = {0, 0};
		if (seconds != 0.0f) {
			tv.tv_sec = (long)floorf(seconds);
			tv.tv_usec = (int)(fmodf(seconds, 1.0f) * 1000000L);
		}
		if (setsockopt(_sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv)) < 0 || setsockopt(_sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
			_lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
	}
	_timeout = seconds;
	return YES;
}

- (int)segmentSize {
	if (_sockfd > 0 && getsockopt(_sockfd, IPPROTO_TCP, TCP_MAXSEG, &_segmentSize, &(socklen_t){sizeof(_segmentSize)}) < 0) {
		_lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	return _segmentSize;
}

- (BOOL)setSegmentSize:(int)bytes {
	if (_sockfd > 0 && setsockopt(_sockfd, IPPROTO_TCP, TCP_MAXSEG, &bytes, sizeof(bytes)) < 0) {
		_lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	_segmentSize = bytes;
	return YES;
}

@end


/**
 This method is adapted from section 16.3 in Unix Network Programming (2003) by Richard Stevens et al.
 See http://books.google.com/books?id=ptSC4LpwGA0C&lpg=PP1&pg=PA448
 */
int	connect_timeout(int sockfd, const struct sockaddr *address, socklen_t address_len, long timeout) {
	fd_set rset, wset;
	struct timeval tval;
	int error = 0;
	
	// Get current flags to restore after.
	int flags = fcntl(sockfd, F_GETFL, 0);
	
	// Set socket to non-blocking.
	fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);
	
	// Connect should return immediately in the "in progress" state.
	int result = 0;
	if ((result = connect(sockfd, address, address_len)) < 0) {
		if (errno != EINPROGRESS) {
			return -1;
		}
	}
	
	// If connection completed immediately, skip waiting.
	if (result == 0) {
		goto done;
	}
	
	// Call select() to wait for the connection.
	// NOTE: If timeout is zero, then pass NULL in order to use default timeout. Zero seconds indicates no waiting.
	FD_ZERO(&rset);
	FD_SET(sockfd, &rset);
	wset = rset;
	tval.tv_sec = timeout;
	tval.tv_usec = 0;
	if ((result = select(sockfd + 1, &rset, &wset, NULL, timeout ? &tval : NULL)) == 0) {
		errno = ETIMEDOUT;
		return -1;
	}
	
	// Check whether the connection succeeded. If the socket is readable or writable, check for an error.
	if (FD_ISSET(sockfd, &rset) || FD_ISSET(sockfd, &wset)) {
		socklen_t len = sizeof(error);
		if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &len) < 0) {
			return -1;
		}
	}
	
done:
	// Restore original flags.
	fcntl(sockfd, F_SETFL, flags);
	
	// NOTE: On some systems, getsockopt() will fail and set errno. On others, it will succeed and set the error parameter.
	if (error) {
		errno = error;
		return -1;
	}
	return 0;
}
