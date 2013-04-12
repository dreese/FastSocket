FastSocket
===============

Description
---------------

A fast, synchronous Objective-C wrapper around BSD sockets for iOS and OS X. Allows
you to send and receive raw bytes over a socket very quickly. Includes methods for
transferring files while optionally computing a checksum for verification.

This is the class to use if fast network communication is what you need. An
asynchronous API might be better if you want to do something else while your network
operations finish.

For more information, please visit the [project homepage](http://github.com/dreese/fast-socket).

Download
---------------

Download [FastSocket](https://github.com/dreese/fast-socket/archive/master.zip).

Examples
---------------

Create and connect a client socket.

    FastSocket *client = [[FastSocket alloc] initWithHost:@"localhost" andPort:@"34567"];
	[client connect];

Send a file.

    long sent = [client sendFile:@"/tmp/filetosend.txt"];

Receive a file of a given length.

	long received = [client receiveFile:@"/tmp/newlyreceivedfile.txt" length:1024];

Send raw bytes.

    char data[] = {42};
    long sent = [client sendBytes:data count:1];

Receive raw bytes.

    char data[42];
	long received = [client receiveBytes:data limit:42];

Close the connection.

	[client close];

Please check out the unit tests for more examples of how to use these classes.

Creator
---------------

[Daniel Reese](http://www.danandcheryl.com/)  
[@dreese](http://twitter.com/dreese)

License
---------------

FastSocket is available under the [MIT license](http://opensource.org/licenses/MIT).
