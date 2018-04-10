FastSocket
===============

Description
---------------

A fast, synchronous Objective-C wrapper around BSD sockets for iOS and OS X.
Send and receive raw bytes over a socket as fast as possible. Includes methods
for transferring files while optionally computing a checksum for verification.

Use this class if fast network communication is what you need. If you want to
do something else while your network operations finish, then an asynchronous
API might be better.

For more information, please visit the [project homepage](http://github.com/dreese/FastSocket).
FastSocket is also available as a [CocoaPod](http://cocoapods.org/?q=fastsocket).

Download
---------------

Download the [latest release](https://github.com/dreese/FastSocket/releases) of FastSocket or try the [nightly version](https://github.com/dreese/FastSocket/archive/master.zip).

Examples
---------------

Create and connect a client socket.

	FastSocket *client = [[FastSocket alloc] initWithHost:@"localhost" andPort:@"34567"];
	[client connect];

Send a file.

	long sent = [client sendFile:@"/tmp/filetosend.txt"];

Receive a file of a given length.

	long received = [client receiveFile:@"/tmp/newlyreceivedfile.txt" length:1024];

Send a string.

	NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
	long count = [client sendBytes:[data bytes] count:[data length]];

Receive a string.

	char bytes[expectedLength];
	[client receiveBytes:bytes count:expectedLength];
	NSString *received = [[NSString alloc] initWithBytes:bytes length:expectedLength encoding:NSUTF8StringEncoding];

Send raw bytes.

	char data[] = {42};
	long sent = [client sendBytes:data count:1];

Receive available raw bytes up to the given limit.

	char data[42];
	long received = [client receiveBytes:data limit:42];

Receive the exact number of raw bytes given.

	char data[1000];
	long received = [client receiveBytes:data count:1000];

Close the connection.

	[client close];

Please check out the unit tests for more examples of how to use these classes.

Creator
---------------

[Daniel Reese](http://www.danielreese.com/)
[@dreese](http://twitter.com/dreese)

License
---------------

FastSocket is available under the [MIT license](http://opensource.org/licenses/MIT).
