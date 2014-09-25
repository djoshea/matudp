#include <pthread.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h> /* For strcmp() */
#include <time.h>

//Windows specific stuff
#ifdef WIN32
//#include <windows.h>
#include <winsock2.h>
#include <WS2tcpip.h>
#define close(s) closesocket(s)
#define s_errno WSAGetLastError()
#define EWOULDBLOCK WSAEWOULDBLOCK
#define usleep(a) Sleep((a)/1000)
#define MSG_NOSIGNAL 0
#define nonblockingsocket(s) {unsigned long ctl = 1;ioctlsocket( s, FIONBIO, &ctl );}
typedef int socklen_t;
//End windows stuff
#else
#include <arpa/inet.h>
#include <inttypes.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <fcntl.h>
#define nonblockingsocket(s)  fcntl(s,F_SETFL,O_NONBLOCK)
#define Sleep(a) usleep(a*1000)
#endif

// Local includes
#include "utils.h"
#include "parser.h"
#include "signal.h"
#include "network.h"

// bind port for broadcast UDP receive
#define SEND_IP "192.168.1.255"
#define SEND_PORT 10000

void *networkReceiveThread(void * dummy);
void networkReceiveThreadCleanup(void * dummy);

int sock;
bool sockOpen;
pthread_t netThread;
int sockOut;
bool sockOutOpen;
int recvFilterInterface = -1;

// Setup Socket Variables
struct sockaddr_in si_me, si_other;
int slen=sizeof(si_other);

// used to pass data to the processing function
static PacketData packetData;
// handle to callback
static void (*packetReceivedCallbackFn)(const PacketData*);

bool parseNetworkAddress(const char* str, NetworkAddress* addr) {
    char *ptr1 = NULL, *ptr2 = NULL;
    char interface[MAX_INTERFACE_LENGTH];
    char host[MAX_HOST_LENGTH];

    // find first colon
    ptr1 = strchr(str, ':');
    if(ptr1 != NULL) {
        // find second colon
        ptr2 = strchr(ptr1+1, ':');
    }

    //printf("parsing %s\n", str);

    if(ptr2 == NULL) {
        // no interface specified
        if(ptr1 == NULL) {
            // no host specified, just port
            setNetworkAddress(addr, "", "", atoi(str));
        } else {
            int len = ptr1 - str;
            strncpy(host, str, len);
            host[len] = '\0';
            setNetworkAddress(addr, "", host, atoi(ptr1+1));
        }
    } else {
        // interface sand host specified
        int len = ptr1 - str;
        strncpy(interface, str, len);
        interface[MAX_INTERFACE_LENGTH-1] = '\0';

        len = ptr2-(ptr1+1);
        if(len <= 0)
            strcpy(host, "");
        else {
            strncpy(host, ptr1+1, len);
            host[len] = '\0';
        }
        setNetworkAddress(addr, interface, host, atoi(ptr2+1));
    }

    return (addr->port > 0);
}

void setNetworkAddress(NetworkAddress* addr, const char *interface,
        const char* host, unsigned port) {
    strncpy(addr->interface, interface, MAX_INTERFACE_LENGTH);
    addr->interface[MAX_INTERFACE_LENGTH] = '\0';
    strncpy(addr->host, host, MAX_HOST_LENGTH);
    addr->host[MAX_HOST_LENGTH] = '\0';
    addr->port = port;
}

char netStrBuf[MAX_HOST_LENGTH+MAX_INTERFACE_LENGTH+10];
const char * getNetworkAddressAsString(const NetworkAddress* addr) {
    char *bufPtr;

    bufPtr = netStrBuf;
    if(strlen(addr->interface) == 0)
        strcpy(bufPtr, "");
    else {
        snprintf(bufPtr, MAX_INTERFACE_LENGTH, "%s:", addr->interface);
        bufPtr[MAX_INTERFACE_LENGTH] = '\0';
        bufPtr += strlen(bufPtr);
    }

    if(strcmp(addr->host, "") == 0)
        snprintf(bufPtr, MAX_HOST_LENGTH+10, "0.0.0.0:%u", addr->port);
    else
        snprintf(bufPtr, MAX_HOST_LENGTH+10, "%s : %u", addr->host, addr->port);

    return (const char*) netStrBuf;
}

// install the callback function to process incoming packets
void networkSetPacketReceivedCallbackFn(void (*fn)(const PacketData*)) {
	packetReceivedCallbackFn = fn;
}

// Start Network Receive Thread
int networkReceiveThreadStart(const NetworkAddress* recv) {

    // setup local receive address info
    struct addrinfo hints, *res, *p;
    char portString[20];
    const char * host;
    const char * interface;
    snprintf(portString, 20, "%u", recv->port);
    if(recv->host == NULL || strlen(recv->host) == 0)
        host = NULL;
    else
        host = recv->host;

    recvFilterInterface = -1;

    if(recv->interface == NULL || strlen(recv->interface) == 0)
        interface = NULL;
    else
        interface = recv->interface;

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET; // IP v4
    hints.ai_socktype = SOCK_DGRAM; // UDP datagrams
    hints.ai_flags = AI_PASSIVE; // fill my IP address for me if NULL in netConf.recvAddr

    // get receive address info list
    int status = 0;
    if ((status = getaddrinfo(host, portString, &hints, &res)) != 0) {
        logError("Network: getaddrinfo(%s) returned error: %s\n", host, gai_strerror(status));
        return NETWORK_ERROR_SETUP;
    }

    // loop through all results and bind the first we can
    for(p = res; p != NULL; p = p->ai_next) {
        // open socket for receiving
        if ((sock=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1) {
            logError("Network: socket returned error\n");
            continue;
        }

        // Set socket buffer size to avoid dropped packets
        int length = MAX_PACKET_LENGTH*50;
        if (setsockopt(sock, SOL_SOCKET, SO_RCVBUF, (char*)&length, sizeof(int)) == -1) {
            logError("Network: Error setting socket receive buffer size \n");
            close(sock);
            continue;
        }

        // allow socket to receive broadcast packets (if .255 dest ip is provided)
        int broadcast = 1;
        if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast)) == -1) {
            logError("Network: Error setting broadcast permissions!\n");
            close(sock);
            continue;
        }

        if(interface != NULL) {
            // store the interface index so we can compare later
            struct ifreq ifr;
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, interface, sizeof(ifr.ifr_name));
            ioctl(sock, SIOCGIFINDEX, &ifr);

            recvFilterInterface = ifr.ifr_ifindex;
            // attempt to bind device
            if (setsockopt(sock, SOL_SOCKET, SO_BINDTODEVICE, (void*)&ifr, sizeof(ifr)) == -1) {
                logError("Network: Could not bind to device interface %s. Try as root?\n", interface);
            }
        } else {
            recvFilterInterface = -1;
        }

        // receive packet information at recvmsg()
        if(setsockopt(sock, IPPROTO_IP, IP_PKTINFO, &broadcast, sizeof broadcast) == -1) {
            logError("Network: Error setting option IPPROTO_IP\n");
            close(sock);
            continue;
        }

        // generate ip string
        struct sockaddr_in *ipv4 = (struct sockaddr_in*) p->ai_addr;
        void* addr = &(ipv4->sin_addr);
        char ipstr[INET_ADDRSTRLEN];
        inet_ntop(AF_INET,  addr, ipstr, sizeof ipstr);

        // allow socket reuse for listening
        int set_option_on = 1;
        if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char*)&set_option_on,
                    sizeof(set_option_on)) == -1) {
            logError("Netlogwork: Could not enable SO_REUSEADDR\n");
            continue;
        }

        // bind the socket
        if (bind(sock,p->ai_addr, p->ai_addrlen)==-1) {
            close(sock);
            logError("Network: Bind could not bind address %s:%u\n", ipstr, recv->port  );
            continue;
        }

        break;
    }

    if(p == NULL) {
        // none in the list worked
        logError("Could not open receive socket\n");

        // done with the list of results
        freeaddrinfo(res);

        return NETWORK_ERROR_SETUP;
    }

    // print bound socket address info
    struct sockaddr_in *ipv4 = (struct sockaddr_in*) p->ai_addr;
    void* addr = &(ipv4->sin_addr);
    char ipstr[INET_ADDRSTRLEN];
    inet_ntop(AF_INET,  addr, ipstr, sizeof ipstr);
    logInfo("Network: listening for UDP at %s:%u\n", ipstr, recv->port);

    // done with the list of results
    freeaddrinfo(res);

    sockOpen = true;

    int rcNetwork = pthread_create(&netThread, NULL, networkReceiveThread, NULL);
    if (rcNetwork) {
        logError("Network: Return code from pthread_create() is %d\n", rcNetwork);
        return NETWORK_ERROR_SETUP;
    }

    return 0;
}

void networkReceiveThreadTerminate() {
    pthread_cancel(netThread);
    pthread_join(netThread, NULL);
}

void * networkReceiveThread(void * dummy)
{
    pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
    //pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, NULL);
    pthread_cleanup_push(networkReceiveThreadCleanup, NULL);

	uint8_t rawPacket[MAX_PACKET_LENGTH];

    struct iovec io;
    struct msghdr msgh;
    char controlbuf[0x100];
    struct sockaddr_in si_sender;
    struct cmsghdr *cmsg;
    int bytesRead;
    bool validPacket;

    while(1)
    {
        // prepare to receive packet info
        memset(&msgh,0,sizeof msgh);
        memset(&io, 0, sizeof io);
        io.iov_base = rawPacket;
        io.iov_len = MAX_PACKET_LENGTH;
        msgh.msg_iov = &io;
        msgh.msg_iovlen = 1;
        msgh.msg_name = &si_sender;
        msgh.msg_namelen = sizeof(si_sender);
        msgh.msg_control = controlbuf;
        msgh.msg_controllen = sizeof(controlbuf);

        // Read from the socket
        bytesRead = recvmsg(sock, &msgh, 0);

        if(recvFilterInterface > 0) {
            // loop through control headers
            for(cmsg = CMSG_FIRSTHDR(&msgh);
                    cmsg != NULL;
                    cmsg = CMSG_NXTHDR(&msgh, cmsg))
            {
                if (cmsg->cmsg_level == IPPROTO_IP && cmsg->cmsg_type == IP_PKTINFO)
                    break;
            }

            if(cmsg != NULL) {
                struct in_pktinfo *pi = (struct in_pktinfo*)CMSG_DATA(cmsg);
                unsigned int ifindex = pi->ipi_ifindex;

                printf("Packet from interface %u to %s (local %s)\n", ifindex,
                        inet_ntoa(pi->ipi_addr),
                        inet_ntoa(pi->ipi_spec_dst));
                if(ifindex != recvFilterInterface) {
                    logError("Rejecting packet at interface %u (accept at %u)\n", ifindex, recvFilterInterface);
                    continue;
                } else {
                    logInfo("Accepting packet at interface %u\n", ifindex);
                }

            } else {
                logError("Could not access packet receipt message header\n");
                continue;
            }
        }

        //logInfo("Received %d bytes!\n", bytesRead);

        if(bytesRead == -1)
            diep("recvfrom()");

        // read the raw packet and check its checksum
        validPacket = processRawPacket(rawPacket, bytesRead, &packetData);

        // pass the packetData to the callback function
        if (validPacket) {
        	if(packetReceivedCallbackFn != NULL) {
        		packetReceivedCallbackFn(&packetData);
        	} else {
                logError("No packetReceivedCallbackFn specified!\n");
            }
        } else {
            logError("Invalid packet checksum\n");
        }
    }

    close(sock);
    sockOpen = false;
    pthread_cleanup_pop(0);

    return NULL;
}

// look at the raw data off the socket and convert hat into a PacketData
// struct.
//
// packetData is the byte stream received directly off of the socket
// the data will contain an 8 bit header, 4 of which are "#udp", followed
// by a 2 byte uint16 length, and a 2 byte uint16 checksum
// and process the PacketSet if it is the last remaining Packet for it.
bool processRawPacket(uint8_t* rawPacket, int bytesRead, PacketData* p)
{
	// parse rawPacket into a PacketData struct
    memset(p, 0, sizeof(PacketData));

    const uint8_t* pBuf = rawPacket;

    if (bytesRead < 8) {
    	return false;
    }

    // check packet header string matches (otherwise could be garbage packet)
    // got rid of short header string, should be filtering packets by ip and port,
    // not packet contents
    /*
    if(strncmp((char*)pBuf, PACKET_HEADER_STRING, strlen(PACKET_HEADER_STRING)) != 0)
    {
    	// packet header does not match, discard
    	return false;
    }
    pBuf = pBuf + strlen(PACKET_HEADER_STRING);
    */

    int headerLength = 4;

    // store the length
    STORE_UINT16(pBuf, p->length);
    if(p->length > bytesRead - headerLength) {
    	logError("Invalid packet length!\n");
    	return false;
    }

    // store the checksum
    STORE_UINT16(pBuf, p->checksum);

    // copy the raw data into the data buffer
    STORE_UINT8_ARRAY(pBuf, p->data, p->length);

    // validate the checksum: sum(bytes as uint8) modulo 2^16
    uint32_t accum = 0;
    for(int i = 0; i < p->length; i++)
    	accum += p->data[i];
    accum = accum % 65536;

    // return true if checksum valid
    return accum == p->checksum;
}

void networkReceiveThreadCleanup(void* dummy) {
    logInfo("Network: Terminating thread\n");
    if(sockOpen)
        close(sock);
    sockOpen = false;
}

struct sockaddr_in si_send; // address for writing responses

void networkOpenSendSocket() {
    memset((char *) &si_send, 0, sizeof(si_send));
    si_send.sin_family = AF_INET;
    si_send.sin_port = htons(SEND_PORT);

    sockOut = sock;
    sockOutOpen = false;
    logInfo("Network: Ready to send to %s:%d\n", SEND_IP, SEND_PORT);
}

void networkCloseSendSocket() {
    sockOutOpen = false;
}

bool networkSend(const char* sendBuffer, unsigned bytesSend) {
    if(sendto(sockOut, (char *)sendBuffer, bytesSend,
        0, (struct sockaddr *)&si_send, sizeof(si_send)) == -1) {
        logError("Sendto error");
        return false;
    }

    return true;
}
