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


@implementation FastSocket

@synthesize sockfd;
@synthesize lastError;
@synthesize host;
@synthesize port;

- (id)initWithHost:(NSString *)remoteHost andPort:(NSString *)remotePort {
	if ((self = [super init])) {
		sockfd = 0;
		host = [remoteHost copy];
		port = [remotePort copy];
		size = getpagesize() * 1448 / 4;
		buffer = valloc(size);
	}
	return self;
}

- (id)initWithFileDescriptor:(int)fd {
	if ((self = [super init])) {
		// Assume the descriptor is an already connected socket.
		sockfd = fd;
		size = getpagesize() * 1448 / 4;
		buffer = valloc(size);
		
		// Instead of receiving a SIGPIPE signal, have write() return an error.
		if (setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int)) < 0) {
			lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
		
		// Disable Nagle's algorithm.
		if (setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &(int){1}, sizeof(int)) < 0) {
			lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
		
		// Increase receive buffer size.
		if (setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &size, sizeof(size)) < 0) {
			// Ignore this because some systems have small hard limits.
		}
		
		// Set timeout or segment size if requested.
		if (timeout && ![self setTimeout:timeout]) {
			return NO;
		}
	}
	return self;
}

- (void)buffer:(void **)outBuf size:(long *)outSize {
	if (outBuf && outSize) {
		*outBuf = buffer;
		*outSize = size;
	}
}

- (void)dealloc {
	[self close];
	free(buffer);
}

#pragma mark Actions

- (BOOL)connect {
	// Construct server address information.
	struct addrinfo hints, *serverinfo, *p;
	
	bzero(&hints, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	
	int error = getaddrinfo([host UTF8String], [port UTF8String], &hints, &serverinfo);
	if (error) {
		lastError = NEW_ERROR(error, gai_strerror(error));
		return NO;
	}
	
	// Loop through the results and connect to the first we can.
	@try {
		for (p = serverinfo; p != NULL; p = p->ai_next) {
			if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Instead of receiving a SIGPIPE signal, have write() return an error.
			if (setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int)) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Disable Nagle's algorithm.
			if (setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &(int){1}, sizeof(int)) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Increase receive buffer size.
			if (setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &size, sizeof(size)) < 0) {
				// Ignore this because some systems have small hard limits.
			}
			
			// Connect the socket (default connect timeout is 75 seconds).
			if (connect(sockfd, p->ai_addr, p->ai_addrlen) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				continue;
			}
			
			// Set timeout or segment size if requested.
			if (timeout && ![self setTimeout:timeout]) {
				return NO;
			}
			if (segmentSize && ![self setSegmentSize:segmentSize]) {
				return NO;
			}
			
			// Found a working address, so move on.
			break;
		}
		if (p == NULL) {
			lastError = NEW_ERROR(1, "Could not contact server");
			return NO;
		}
	}
	@finally {
		freeaddrinfo(serverinfo);
	}
	return YES;
}

- (BOOL)isConnected {
	if (sockfd == 0) {
		return NO;
	}
	
	struct sockaddr remoteAddr;
	if (getpeername(sockfd, &remoteAddr, &(socklen_t){sizeof(remoteAddr)}) < 0) {
		lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	return YES;
}

- (BOOL)close {
	if (sockfd > 0 && close(sockfd) < 0) {
		lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	sockfd = 0;
	return YES;
}

- (long)sendBytes:(void *)buf count:(long)count {
	long sent;
	if ((sent = send(sockfd, buf, count, 0)) < 0) {
		lastError = NEW_ERROR(errno, strerror(errno));
	}
	return sent;
}

- (long)receiveBytes:(void *)buf limit:(long)limit {
	long received = recv(sockfd, buf, limit, 0);
	if (received < 0) {
		lastError = NEW_ERROR(errno, strerror(errno));
	}
	return received;
}

- (BOOL)receiveBytes:(void *)buf count:(long)count {
	while (count > 0) {
		long received = [self receiveBytes:buf limit:count];
		if (received < 1) {
			break;
		}
		count -= received;
		buf += received;
	}
	return (count == 0);
}

- (long)sendFile:(NSString *)path {
	int fd = 0;
	long sent = 0;
	@try {
		const char *cPath = [path fileSystemRepresentation];
		if ((fd = open(cPath, O_RDONLY)) < 0) {
			lastError = NEW_ERROR(errno, strerror(errno));
			return -1;
		}
		if (fcntl(fd, F_NOCACHE, 1) < 0) {
			// Ignore because this will still work with disk caching on.
		}
		
		long count;
		while (1) {
			count = read(fd, buffer, size);
			if (count == 0) {
				break; // Reached end of file.
			}
			if (count < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			if ([self sendBytes:buffer count:count] < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
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
			lastError = NEW_ERROR(errno, strerror(errno));
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
			received = [self receiveBytes:buffer limit:MIN(length, size)];
			if (received == 0) {
				break; // Peer closed the connection.
			}
			if (received < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			if (write(fd, buffer, received) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				break;
			}
			if (outHash) {
				CC_MD5_Update(&context, buffer, (CC_LONG)received);
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

- (long)timeout {
	if (sockfd > 0) {
		struct timeval tv;
		if (getsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, &(socklen_t){sizeof(tv)}) < 0) {
			lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
		timeout = tv.tv_sec;
	}
	return timeout;
}

- (BOOL)setTimeout:(long)seconds {
	if (sockfd > 0) {
		struct timeval tv = {seconds, 0};
		if (setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv)) < 0 || setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
			lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
	}
	timeout = seconds;
	return YES;
}

- (int)segmentSize {
	if (sockfd > 0 && getsockopt(sockfd, IPPROTO_TCP, TCP_MAXSEG, &segmentSize, &(socklen_t){sizeof(segmentSize)}) < 0) {
		lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	return segmentSize;
}

- (BOOL)setSegmentSize:(int)bytes {
	if (sockfd > 0 && setsockopt(sockfd, IPPROTO_TCP, TCP_MAXSEG, &bytes, sizeof(bytes)) < 0) {
		lastError = NEW_ERROR(errno, strerror(errno));
		return NO;
	}
	segmentSize = bytes;
	return YES;
}

@end
