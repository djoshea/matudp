#ifndef _NETWORK_H_
#define _NETWORK_H_

#include <stdbool.h>
#include <inttypes.h>
#include "signal.h"

#define MAX_HOST_LENGTH 50
#define MAX_INTERFACE_LENGTH 20
typedef struct NetworkAddress {
    char interface[MAX_INTERFACE_LENGTH+1];
    char host[MAX_HOST_LENGTH+1];
    unsigned port;
} NetworkAddress;

// Packet data contents
#define PACKET_HEADER_STRING "#udp"
#define MAX_DATA_SIZE 65536
#define MAX_PACKET_LENGTH 65536
typedef struct PacketData
{
    uint16_t checksum; // checksum for data

    uint8_t data[MAX_DATA_SIZE];
    uint16_t length;
} PacketData;

void setNetworkAddress(NetworkAddress*, const char*, const char*, unsigned);
const char * getNetworkAddressAsString(const NetworkAddress*);
bool parseNetworkAddress(const char*, NetworkAddress*);

// receive, parse, buffering threads
void networkSetPacketReceivedCallbackFn(void (*)(const PacketData*));
int networkReceiveThreadStart(const NetworkAddress*);
void networkReceiveThreadTerminate();

// send utilities
void networkOpenSendSocket();
void networkCloseSendSocket();
bool networkSend(const char*, unsigned);

#define NETWORK_ERROR_SETUP 1
#define NETWORK_ERROR_SETUP_SEND 2
#define NETWORK_ERROR_SETUP_RECV 3

bool processRawPacket(uint8_t*, int, PacketData*);

#endif
