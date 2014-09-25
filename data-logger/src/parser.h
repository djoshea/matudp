#ifndef PARSER_H_INCLUDED
#define PARSER_H_INCLUDED

#include "signal.h"
#include "network.h"

void processReceivedPacketData(const PacketData*);
const uint8_t* parseGroupInfoHeader(const uint8_t*, GroupInfo*);
const uint8_t* parseSignalFromBuffer(const uint8_t*, SignalSample*);

#define logParsingError printf

#endif // ifndef PARSER_H_INCLUDED

