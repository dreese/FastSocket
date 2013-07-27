//
//  FastServerSocket.m
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


#import "FastServerSocket.h"
#import "FastSocket.h"
#include <unistd.h>
#include <netdb.h>
#include <sys/socket.h>

@implementation FastServerSocket

@synthesize sockfd;
@synthesize port;
@synthesize lastError;

- (id)initWithPort:(NSString *)localPort {
	if ((self = [super init])) {
		port = [localPort copy];
	}
	return self;
}

- (id)initWithFileDescriptor:(int)fd {
	if ((self = [super init])) {
        struct sockaddr_storage currentSocket; 
        
        int error = getsockname(fd, (struct sockaddr *)&currentSocket, &(socklen_t){sizeof(currentSocket)});
        if(error){
            lastError = NEW_ERROR(error, gai_strerror(error));
            return nil;
        }
        
        sockfd = fd;
        
        if(currentSocket.ss_family == AF_INET6){
            struct sockaddr_in6 *currentSocketIn6 = (struct sockaddr_in6 *)&currentSocket;
            port = [NSString stringWithFormat:@"%i", currentSocketIn6->sin6_port];
        }
        
        else if(currentSocket.ss_family == AF_INET){
            struct sockaddr_in *currentSocketIn = (struct sockaddr_in *)&currentSocket;
            port = [NSString stringWithFormat:@"%i", currentSocketIn->sin_port];
        }
        
        else{
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
	[self close];
}

#pragma mark Actions

- (BOOL)listen {
	struct addrinfo hints, *serverinfo, *p;
	
	bzero(&hints, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_PASSIVE;
	
	int error = getaddrinfo(NULL, [port UTF8String], &hints, &serverinfo);
	if (error) {
		lastError = NEW_ERROR(error, gai_strerror(error));
		return NO;
	}
	
	// Loop through the results and bind to the first we can.
	@try {
		for (p = serverinfo; p != NULL; p = p->ai_next) {
			if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Reuse local address if it still exists.
			if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &(int){1}, sizeof(int)) < 0) {
				lastError = NEW_ERROR(errno, strerror(errno));
				return NO;
			}
			
			// Bind the socket.
			if (bind(sockfd, p->ai_addr, p->ai_addrlen) < 0) {
				close(sockfd);
				continue;
			}
			
			// Set timeout if requested.
			if (timeout && ![self setTimeout:timeout]) {
				return NO;
			}
			
			// Found a working address, so move on.
			break;
		}
		if (p == NULL) {
			lastError = NEW_ERROR(errno, strerror(errno));
			return NO;
		}
	}
	@finally {
		freeaddrinfo(serverinfo); // All done with this structure.
	}
	
	if (listen(sockfd, 10) == -1) {
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

- (FastSocket *)accept {
	struct sockaddr_storage remoteAddr;
	int clientfd = accept(sockfd, (struct sockaddr *)&remoteAddr, &(socklen_t){sizeof(remoteAddr)});
	if (clientfd == -1) {
		lastError = NEW_ERROR(errno, strerror(errno));
		return nil;
	}
	return [[FastSocket alloc] initWithFileDescriptor:clientfd];
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

@end
