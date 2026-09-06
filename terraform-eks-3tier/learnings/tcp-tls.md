```markdown
# Ports, Services, TCP and TLS — Practical End-to-End Flow

This README continues from the basic network journey.

The previous README covered:

Domain
→ DNS
→ IP
→ Routing
→ Default Gateway
→ ARP
→ MAC
→ Frames
→ Routers
→ Destination Network

This README focuses on what happens once the traffic is being delivered toward the destination:

Port
→ Service
→ TCP
→ TCP Handshake
→ TLS
→ Certificate
→ Authentication
→ Key Exchange
→ Symmetric Traffic Keys
→ Encrypted HTTP
→ Request
→ Response

TLS 1.2 vs TLS 1.3 is intentionally NOT covered here.

---

# 1. Start With a Real URL

Suppose the user enters:

https://amazon.com/products

We already know:

amazon.com
→ DNS
→ destination IP

Now we need to understand something else:

"Which service on that destination should receive this traffic?"

That is where ports come in.

---

# 2. What Is a Port?

A port identifies a network service/application endpoint on a host.

Think of an IP address as identifying the building.

The port identifies which door/service inside that building should receive the traffic.

For example:

142.250.72.14:443

means:

IP:
142.250.72.14

Port:
443

The IP answers:

"WHERE?"

The port answers:

"WHICH SERVICE?"

---

# 3. Why Do We Need Ports?

Imagine one server has several services running.

For example:

142.250.72.14

could have:

Port 22
→ SSH

Port 80
→ HTTP

Port 443
→ HTTPS

Port 5432
→ PostgreSQL

The IP address alone tells the network which host/network destination to reach.

The port allows the operating system to determine which application/service should receive the traffic.

So:

IP
→ gets traffic to the host

Port
→ gets traffic to the appropriate service/process

---

# 4. Common Ports

Some commonly encountered ports are:

80
→ HTTP

443
→ HTTPS

22
→ SSH

53
→ DNS

5432
→ PostgreSQL

3306
→ MySQL

These are conventions.

A service can sometimes be configured to listen on a different port.

For example, an application could run HTTP on:

8080

instead of:

80

So port numbers do not magically create the service.

The application/service is configured to listen on a particular port.

---

# 5. What Does "Listening on a Port" Mean?

Suppose a web server is configured to listen on:

443

Conceptually:

HTTPS server
→ listening
→ port 443

When traffic arrives at:

server-IP:443

the operating system knows:

"This traffic is destined for port 443."

It can then deliver the traffic to the process/socket associated with that port.

Think of it like a receptionist:

Building:
142.250.72.14

Door:
443

Receptionist:
"Traffic for 443? Send it to the HTTPS service."

---

# 6. Port vs Service

These are related but not identical.

Port:

A numbered endpoint used by network communication.

Service:

The application/network service that is listening on that port.

Example:

Port:
443

Service:
HTTPS web server

Another example:

Port:
22

Service:
SSH server

So:

Port = where the traffic is directed

Service = the software handling that traffic

---

# 7. Client Ports

The server commonly listens on a well-known port such as:

443

The client normally uses a temporary source port.

For example:

Client:

192.168.1.10:52341

Server:

142.250.72.14:443

So the connection can be represented as:

192.168.1.10:52341
→
142.250.72.14:443

Here:

192.168.1.10
→ client IP

52341
→ temporary client source port

142.250.72.14
→ server IP

443
→ server HTTPS port

The operating system chooses/manages the client's temporary source port.

---

# 8. Why Does the Client Need a Source Port?

Imagine your laptop has several applications communicating simultaneously.

For example:

Browser connection 1:

192.168.1.10:52341
→
Amazon:443

Browser connection 2:

192.168.1.10:52342
→
Google:443

SSH:

192.168.1.10:52343
→
Server:22

The source ports help the operating system distinguish the different connections.

This allows multiple network conversations to exist simultaneously.

---

# 9. Now We Reach TCP

The destination is:

Amazon IP:443

Port 443 indicates the HTTPS service.

But we still need a reliable communication mechanism.

This is where TCP comes in.

TCP stands for:

Transmission Control Protocol

TCP provides reliable, ordered communication between endpoints.

---

# 10. What Problem Does TCP Solve?

Imagine you send data across the Internet.

Packets can encounter:

- congestion
- delay
- loss
- reordering

The application should not have to manually manage every one of these problems.

TCP provides mechanisms to handle this.

TCP helps provide:

- connection establishment
- ordered delivery
- reliable delivery
- detection of missing data
- retransmission
- flow control

So TCP's responsibility is:

"Give the application a reliable ordered byte stream between two endpoints."

TCP does NOT provide encryption.

---

# 11. TCP Is Not the Same as IP

This distinction is important.

IP is concerned with:

"Where should this packet go?"

TCP is concerned with:

"How do we reliably communicate between these endpoints?"

So:

IP
→ addressing and routing

TCP
→ reliable transport

For example:

Source:
192.168.1.10

Destination:
142.250.72.14

TCP adds the concept of:

Source port:
52341

Destination port:
443

Together, this identifies the TCP communication endpoint pair.

---

# 12. TCP Connection

Before the application starts using TCP, the client and server establish a TCP connection.

The TCP connection is established using the:

Three-Way Handshake

The three messages are:

SYN

SYN-ACK

ACK

---

# 13. TCP Step 1 — SYN

The client wants to connect to:

Amazon:443

The operating system's TCP stack sends:

SYN

SYN means:

Synchronize

It is used to begin TCP connection establishment and synchronize TCP sequence-number state.

Conceptually, the client is saying:

"I want to establish a TCP connection with you."

Flow:

Client
→
Server

SYN

---

# 14. TCP Step 2 — SYN-ACK

The server receives the SYN.

The server's TCP stack responds:

SYN + ACK

Conceptually:

"I received your request and I am willing to establish the TCP connection."

Flow:

Client
→ Server:
SYN

Server
→ Client:
SYN + ACK

---

# 15. TCP Step 3 — ACK

The client receives the SYN-ACK.

The client's TCP stack responds:

ACK

Conceptually:

"I received your response."

Flow:

Client
→ Server:
SYN

Server
→ Client:
SYN + ACK

Client
→ Server:
ACK

The TCP connection is now established.

---

# 16. What Happens After TCP Is Established?

At this point we have:

Destination:
Amazon IP

Port:
443

TCP:
Established

But there is still no encryption.

If we simply sent HTTP now, the communication would not have TLS protection.

Therefore:

TCP
→
TLS
→
HTTP

TLS provides the security layer.

---

# 17. TLS

TLS stands for:

Transport Layer Security

TLS is responsible for securing communication.

The major goals are:

1. Confidentiality
2. Integrity
3. Server authentication

Think of:

TCP:

"We have a reliable phone line."

TLS:

"Now let's make the conversation secure and verify who we are talking to."

---

# 18. HTTPS

HTTPS means HTTP protected using TLS.

So:

HTTP
+
TLS
=
HTTPS

When the user accesses:

https://amazon.com/products

the application-level request is HTTP.

TLS protects that HTTP communication.

The simplified stack is:

HTTP
↓
TLS
↓
TCP
↓
IP
↓
Network

Each component has a different responsibility.

---

# 19. Who Creates the TCP Messages?

The browser does not manually create:

SYN

SYN-ACK

ACK

The operating system's networking stack handles TCP.

The browser asks the operating system to establish a connection.

Conceptually:

Browser:

"Connect me to amazon.com on port 443."

Operating System:

"Okay."

OS TCP stack:

SYN
→

SYN-ACK
←

ACK
→

TCP connection established.

So TCP is primarily implemented in the operating system's networking stack.

---

# 20. What Is the OS Networking Stack?

The operating system contains networking functionality that handles protocols such as TCP/IP.

Conceptually:

Application
↓
Operating System networking APIs
↓
TCP
↓
IP
↓
Network Interface
↓
Network

For example, the browser might call an operating system networking API such as a socket interface.

The browser does not need to manually construct every TCP segment.

The operating system handles the TCP mechanics.

---

# 21. What Is a Socket?

A socket is an abstraction that applications use to communicate over a network.

For a TCP connection, think of a socket as the application's communication endpoint.

For example:

Client socket:

192.168.1.10:52341

Server socket:

142.250.72.14:443

The application can use the socket to send and receive data.

The operating system handles the underlying networking details.

---

# 22. Browser → OS → TCP

Suppose you type:

https://amazon.com/products

The browser needs to communicate with:

Amazon IP:443

The browser asks the operating system:

"Open a network connection to this destination."

The operating system creates/manages the client-side socket.

Then the OS TCP stack performs:

SYN
→

SYN-ACK
←

ACK
→

Now the browser has an established TCP connection through which it can communicate.

---

# 23. TLS Starts After TCP

Now TCP is established.

The browser's TLS implementation starts the TLS handshake.

The browser does not ask TCP:

"Please encrypt this."

Instead, the browser uses a TLS implementation/library.

Conceptually:

Browser
↓
TLS implementation
↓
TCP connection
↓
IP
↓
Network

The TLS implementation creates TLS handshake messages.

TCP transports those TLS messages reliably.

---

# 24. TLS ClientHello

The client starts the TLS handshake with:

ClientHello

Conceptually:

"Here are the TLS versions, cryptographic capabilities, and other information I support. Let's establish a secure connection."

ClientHello can contain information such as:

- supported TLS versions
- supported cryptographic options
- random/nonce material
- SNI/server name
- key-exchange information in modern TLS

ClientHello is NOT:

- the HTTP request
- the certificate
- encrypted application data

It is a TLS handshake message.

---

# 25. ServerHello

The server's TLS implementation receives ClientHello.

The server chooses compatible TLS/security parameters.

Then it sends:

ServerHello

Conceptually:

Client:

"These are the options I support."

Server:

"These are the compatible options we will use."

This is part of TLS negotiation.

---

# 26. Certificate

The server needs to authenticate itself.

Suppose the client requested:

amazon.com

The server provides its TLS certificate.

The certificate contains information such as:

- domain identity
- public key
- issuer
- validity information
- other certificate information

The certificate is part of the server authentication process.

---

# 27. Certificate Authority

A Certificate Authority is commonly called:

CA

A simplified trust chain is:

Trusted Root CA
↓
Intermediate CA
↓
Server Certificate
↓
Domain + Public Key

The client has trusted root CA information.

It can use that trust to validate the server's certificate chain.

---

# 28. Certificate Validation

The client can check:

1. Does the certificate match the requested hostname?

For example:

Requested:
amazon.com

Certificate:
amazon.com

2. Is the certificate valid within its validity period?

3. Does the certificate chain lead to a trusted CA?

4. Are the relevant certificate signatures valid?

If validation fails, the client can reject the TLS connection or display a security warning.

---

# 29. Public Key and Private Key

The server has a cryptographic key pair:

Public key

Private key

The public key can be distributed.

The private key must remain secret.

The server certificate contains the public key.

The corresponding private key remains with the server.

Conceptually:

Certificate:
Public key

Server:
Private key

The private key should never be sent across the network.

---

# 30. Why Does the Server Need the Private Key?

The server needs to demonstrate that it possesses the private key corresponding to the certificate's public key.

During the TLS handshake, the server can create a cryptographic signature using its private key.

The client verifies that signature using the public key from the certificate.

Conceptually:

Server:

Private key
↓
Create signature

Network:

Signature
→

Client:

Public key
↓
Verify signature

If verification succeeds, the client has cryptographic evidence that the server possesses the corresponding private key.

This contributes to server authentication.

---

# 31. Authentication vs Authorization

Authentication asks:

"Who are you?"

Authorization asks:

"What are you allowed to do?"

TLS primarily handles server authentication.

For example:

TLS:

"Is this server authenticated for this domain?"

Application:

"Is this user allowed to access /products?"

These are separate concerns.

---

# 32. Key Exchange

Now the client and server need shared secret key material so that they can protect application data efficiently.

They cannot simply send:

"Here is our secret key."

because someone observing the network could potentially obtain it.

So TLS uses a key-exchange mechanism.

A major concept used in modern TLS is Diffie-Hellman-style key exchange.

A common modern form is:

ECDHE

Elliptic Curve Diffie-Hellman Ephemeral

The important concept is more important than the mathematics.

---

# 33. Practical Key Exchange Idea

The client creates a temporary private key-exchange value.

The server also creates its own temporary private key-exchange value.

Each side derives public key-exchange information.

They exchange the public information.

They do NOT exchange their private values.

Conceptually:

Client:

Private A
→
Public A

Server:

Private B
→
Public B

Exchange:

Client → Server:
Public A

Server → Client:
Public B

The private values stay on their respective machines.

---

# 34. How Do They Get the Same Secret?

The mathematics of the key-exchange mechanism is designed so both sides independently calculate matching shared secret material.

Client:

Client private value
+
Server public value
→
Shared secret

Server:

Server private value
+
Client public value
→
Same shared secret

The actual shared secret is never directly transmitted.

This is the key idea.

---

# 35. Shared Secret

After the key exchange:

Client:
has shared secret material

Server:
has matching shared secret material

The network did not carry:

"Here is the final secret."

Instead, the network carried the public key-exchange information necessary for both sides to calculate it.

---

# 36. Session/Traffic Keys

TLS then derives symmetric traffic keys from the shared secret material.

Conceptually:

Shared secret
+
TLS handshake information
↓
Key Derivation Function
↓
Traffic keys

Both sides independently derive the appropriate traffic keys.

The actual traffic keys do not need to be transmitted across the network.

---

# 37. Symmetric Encryption

Symmetric cryptography uses shared secret key material to protect data efficiently.

Conceptually:

Client:

HTTP request
+
traffic key
↓
encrypted TLS data

Server:

encrypted TLS data
+
matching traffic key
↓
HTTP request

This is efficient for the large amount of data exchanged during a normal HTTPS session.

---

# 38. Why Not Use Public-Key Encryption for All HTTP Data?

Asymmetric cryptography is useful for things such as:

- authentication
- signatures
- key establishment

But using asymmetric cryptography for all application data would be inefficient.

Therefore the general TLS model is:

Asymmetric cryptographic mechanisms
→
authentication / key establishment

Then:

Shared secret material
→
derive symmetric traffic keys

Then:

Symmetric cryptography
→
protect actual application data

---

# 39. The HTTP Request Finally Travels

Now the secure TLS connection is established.

The browser can send the actual HTTP request.

For example:

GET /products

The important thing is:

The browser does not simply send the plaintext HTTP request directly across the network.

Instead:

HTTP request
↓
TLS protection
↓
Encrypted TLS data
↓
TCP
↓
IP
↓
Network

---

# 40. What TCP Sees

TCP does not need to understand the HTTP contents.

TCP sees data that it needs to transport reliably.

The data may be TLS-protected.

So:

TLS:

"Protect the application data."

TCP:

"Transport the resulting data reliably."

IP:

"Deliver packets toward the destination."

This separation of responsibilities is important.

---

# 41. What the Server Receives

At the server:

Network interface
↓
IP processing
↓
TCP processing
↓
TLS processing
↓
HTTP/application

The server's TCP stack receives the TCP data.

TLS receives the TLS-protected data.

TLS verifies and decrypts the protected data using the established traffic keys.

The application can then receive the HTTP request.

Conceptually, the application finally sees:

GET /products

---

# 42. The Server Processes the Request

The web application receives:

GET /products

It may then:

- authenticate the user
- check authorization
- execute application logic
- query a database
- retrieve product information
- construct an HTTP response

For example:

HTTP 200 OK

Product information...

The application creates the HTTP response.

---

# 43. Response Travels Back

The response goes through the reverse process.

Application:

HTTP response

↓

TLS:

Protect response

↓

TCP:

Transport reliably

↓

IP:

Route toward client

↓

Network:

Deliver toward client

The client receives the protected TLS data.

TLS verifies/decrypts it.

The browser receives the HTTP response.

The browser then processes/renders the response.

---

# 44. Complete Practical Flow

Suppose the user enters:

https://amazon.com/products

The complete flow covered by this README is:

1. Browser receives the URL.

2. DNS has already resolved:

amazon.com
→
destination IP

3. The operating system determines that the destination should be reached through the network path.

4. The destination service is:

IP:443

5. Port 443 identifies the HTTPS service.

6. The browser asks the operating system to establish a TCP connection.

7. The OS TCP stack sends:

SYN

8. Server TCP stack responds:

SYN-ACK

9. Client TCP stack sends:

ACK

10. TCP connection is established.

11. Browser/TLS implementation begins the TLS handshake.

12. Client sends:

ClientHello

13. Server sends:

ServerHello

14. Server provides its certificate.

15. Client validates the certificate and certificate chain.

16. Server proves possession of the corresponding private key through the TLS authentication mechanism.

17. Client and server perform key exchange.

18. Public key-exchange information is exchanged.

19. Private key-exchange values remain secret.

20. Both sides independently derive matching shared secret material.

21. TLS derives symmetric traffic keys.

22. The browser creates the HTTP request:

GET /products

23. TLS protects the HTTP request.

24. TCP transports the protected data reliably.

25. IP/network infrastructure carries it toward the server.

26. Server TCP receives the data.

27. TLS verifies and decrypts the protected data.

28. The server application receives:

GET /products

29. The application processes the request.

30. The application creates an HTTP response.

31. TLS protects the response.

32. TCP transports it reliably.

33. The response travels back through the network.

34. Client TLS verifies and decrypts it.

35. Browser receives the HTTP response.

---

# 45. The Software Stack

A simplified practical stack is:

Browser / Application
↓
TLS implementation
↓
Operating System networking APIs
↓
TCP
↓
IP
↓
Network Interface
↓
Wi-Fi / Ethernet
↓
Network

On the server side:

Network Interface
↓
IP
↓
TCP
↓
TLS implementation
↓
Web Server / Application
↓
HTTP processing

This is simplified, but it gives the correct mental model.

---

# 46. Who Does What?

Browser / Application:

- creates the HTTP request
- asks the OS for a network connection
- uses a TLS implementation
- receives the HTTP response
- processes application data

TLS implementation:

- performs TLS handshake
- handles certificates
- performs server authentication
- performs key establishment
- derives traffic keys
- protects/decrypts application data

Operating System TCP stack:

- establishes TCP connections
- manages TCP state
- provides reliable ordered transport
- handles retransmission
- handles acknowledgements
- handles flow control

IP stack:

- handles IP addressing
- prepares IP packets
- interacts with routing decisions

Network Interface:

- sends and receives network traffic

Server Application:

- receives the HTTP request
- executes business logic
- generates the HTTP response

---

# 47. Important Separation of Responsibilities

Do not think:

"TLS does everything."

It does not.

TCP does not encrypt.

IP does not authenticate the server.

The browser does not manually perform every TCP operation.

ARP does not establish HTTPS.

The certificate does not encrypt all HTTP data.

The server private key is not sent to the client.

The final session/traffic keys are not sent across the network.

Each component has a specific responsibility.

---

# 48. The Core Mental Model

Port:

"Which service should receive this traffic?"

Service:

"The application/process listening on that port."

TCP:

"Give the endpoints reliable, ordered communication."

TLS:

"Secure the communication and authenticate the server."

Certificate:

"Associate the server's public key with its domain identity through a trusted certificate chain."

Private key:

"Remain secret on the server and support proof of possession/authentication."

Key exchange:

"Allow both sides to independently establish shared secret material without directly sending the secret."

Symmetric traffic keys:

"Efficiently protect the actual application data."

HTTP:

"Carry the actual web request and response."

---

# 49. Simplest Mental Model

For:

https://amazon.com/products

Think:

Domain
→
DNS finds IP

IP
→
destination

Port 443
→
HTTPS service

TCP
→
reliable connection

TLS
→
secure connection + server authentication

Certificate
→
server identity + public key

Key exchange
→
shared secret material

Traffic keys
→
symmetric protection

HTTP
→
GET /products

Server
→
processes request

Response
→
TLS protection
→
TCP
→
network
→
client

This is the practical relationship between ports, services, TCP, TLS, and HTTP.

TLS 1.2 vs TLS 1.3 will be covered separately.
```
