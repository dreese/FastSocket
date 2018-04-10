FastSocket
===============

Release Notes
---------------
2017 Nov 01 — [v1.6](https://github.com/dreese/FastSocket/releases/tag/v1.6)

	• Fixed a long-standing bug where the internal socket descriptor could become closed but not zeroed out.

2017 Oct 28 — [v1.5](https://github.com/dreese/FastSocket/releases/tag/v1.5)

	• Annotated code to improve auto-generated Swift interface.
	• Fixed several documentation issues.
	• Added document for contributions.

2017 Oct 06 — [v1.4](https://github.com/dreese/FastSocket/releases/tag/v1.4)

	• Changed -[FaskSocket timeout] and -[FaskSocket setTimeout:] methods so that the timeout value is a float, in order to handle sub-second values.
	• Fixed a compatibility issue with Xcode 9.
	• Added several unit tests.

2015 Jan 27 — [v1.3](https://github.com/dreese/FastSocket/releases/tag/v1.3)

	• Changed -[FaskSocket sendBytes:count:] method to return the actual number of bytes received instead of a BOOL. Now it matches the Readme.
	• Fixed a compiler warning caused by returning NO instead of nil from one of the init methods.
	• Added several unit tests.

2014 Feb 03 — [v1.2](https://github.com/dreese/FastSocket/releases/tag/v1.2)

	• Added -[FastSocket connect:] method for specifying a connection timeout, which is separate from the read/write timeout.
	• Added CocoaPod support with new podspec file.

2013 Oct 03 — [v1.1](https://github.com/dreese/FastSocket/releases/tag/v1.1)

	• Converted to ARC.
	• Added -[FastSocket isConnected] method.
	• Added -[FastSocket receiveBytes:count:] method for receiving an exact number of bytes. This differs from -[FastSocket receiveBytes:limit:] in that the new method waits for the given number of bytes is received, or a timeout, before returning.
	• Added header documentation for use in Xcode 5.

2012 Jun 24 — [v1.0](https://github.com/dreese/FastSocket/releases/tag/v1.0)

	• Initial release.
