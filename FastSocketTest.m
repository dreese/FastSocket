//
//  FastSocketTest.h
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

#import <SenTestingKit/SenTestingKit.h>
#import "FastSocket.h"
#import "FastServerSocket.h"


@interface FastSocketTest : SenTestCase {
	FastSocket *client;
	FastServerSocket *server;
}

@end


@implementation FastSocketTest

- (void)setUp {
	server = [[FastServerSocket alloc] initWithPort:@"34567"];
	client = [[FastSocket alloc] initWithHost:@"localhost" andPort:@"34567"];
}

- (void)tearDown {
	[client close];
	[server close];
}

#pragma mark Tests

- (void)testConnect {
	// No failures yet.
	STAssertNil([client lastError], @"Last error should be nil");
	
	// Nothing is listening yet.
	STAssertFalse([client connect], @"Connection attempt succeeded");
	STAssertNotNil([client lastError], @"Last error should not be nil");
	
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Connection should now succeed.
	STAssertTrue([client connect], @"Connection attempt failed");
	//STAssertNil([client lastError], @"Last error should be nil"); // TODO: Not sure if this should be cleared out or just left alone.
}

- (void)testIsConnected {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Check connected state before and after connecting, and after closing.
	STAssertFalse([client isConnected], @"Should not be connected");
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertTrue([client isConnected], @"Client should be connected");
	STAssertTrue([client close], @"Connection should be closed");
	STAssertFalse([client isConnected], @"Client should no longer be connected");
	
	// Close server socket and verify that the client knows it's no longer connected.
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertTrue([client isConnected], @"Client should be connected");
	STAssertTrue([server close], @"Connection should be closed");
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	STAssertFalse([client isConnected], @"Client should no longer be connected");
}

- (void)testTimeoutBefore {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value before connect.
	STAssertTrue([client setTimeout:100], @"Could not set timeout");
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertEquals([client timeout], 100, @"Timeout is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testTimeoutAfter {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value after connect.
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertTrue([client setTimeout:100], @"Could not set timeout");
	STAssertEquals([client timeout], 100, @"Timeout is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testTimeoutMultipleBefore {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice before connect.
	STAssertTrue([client setTimeout:100], @"Could not set timeout");
	STAssertTrue([client setTimeout:101], @"Could not set timeout second time");
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertEquals([client timeout], 101, @"Timeout is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testTimeoutMultipleAfter {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice after connect.
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertTrue([client setTimeout:100], @"Could not set timeout");
	STAssertTrue([client setTimeout:101], @"Could not set timeout second time");
	STAssertEquals([client timeout], 101, @"Timeout is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testSegmentSizeBefore {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value before connect.
	STAssertTrue([client setSegmentSize:10000], @"Could not set segment size");
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertEquals([client segmentSize], 10000, @"Segment size is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testSegmentSizeAfter {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value after connect.
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertTrue([client setSegmentSize:10000], @"Could not set segment size");
	STAssertEquals([client segmentSize], 10000, @"Segment size is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testSegmentSizeMultipleBefore {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice before connect.
	STAssertTrue([client setSegmentSize:10000], @"Could not set segment size");
	STAssertTrue([client setSegmentSize:10001], @"Could not set segment size second time");
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertEquals([client segmentSize], 10001, @"Segment size is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testSegmentSizeMultipleAfter {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice after connect.
	STAssertTrue([client connect], @"Connection attempt failed");
	STAssertTrue([client setSegmentSize:10000], @"Could not set segment size");
	STAssertFalse([client setSegmentSize:10001], @"Should not be able to increase segment size once set");
	STAssertTrue([client setSegmentSize:9999], @"Could not set segment size second time");
	STAssertEquals([client segmentSize], 9999, @"Segment size is not correct");
	STAssertTrue([client close], @"Could not close connection");
}

- (void)testSendingAndReceivingBytes {
	// Spawn a thread to listen.
	[NSThread detachNewThreadSelector:@selector(listenAndRepeat:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Send a byte array.
	int lenVal = 10;
	char lenArr[] = {lenVal};
	char data[] = {1, -2, 3, -4, 5, -6, 7, -8, 9, 0};
	[client connect];
	long sent = [client sendBytes:lenArr count:1];
	sent = [client sendBytes:data count:lenVal];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	
	// Receive a byte array.
	char received[lenVal];
	while ([client receiveBytes:received limit:lenVal] < 0) {
		NSLog(@"%@", [client lastError]);
	}
	
	// Compare results.
	STAssertEquals(memcmp(data, received, lenVal), 0, nil);
	[client close];
}

#pragma mark Helpers

- (void)simpleListen:(id)obj {
	@autoreleasepool {
		[server listen]; // Incoming connections just queue up.
	}
}

- (void)listenAndRepeat:(id)obj {
	@autoreleasepool {
		[server listen];
		FastSocket *incoming = [server accept];
		if (!incoming) {
			NSLog(@"%@", [server lastError]);
		}
		
		// Read length as first byte.
		char lenArr[1];
		long count = [incoming receiveBytes:lenArr limit:1];
		while (count < 1) {
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
			count = [incoming receiveBytes:lenArr limit:1];
		}
		int lenVal = lenArr[0];
		
		// Read bytes.
		char buffer[lenVal];
		[incoming receiveBytes:buffer limit:lenVal];
		
		// Write bytes.
		[incoming sendBytes:buffer count:lenVal];
		
		// Close connection.
		[incoming close];
	}
}

@end
