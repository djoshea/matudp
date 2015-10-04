% 
% // Generic Cerebus packet data structure (1024 bytes total)
% typedef struct {
%     UINT32 time;        // system clock timestamp
%     UINT16 chid;        // channel identifier
%     UINT8  type;        // packet type
%     UINT8  dlen;        // length of data field in 32-bit chunks
%     UINT32 data[254];   // data buffer (up to 1016 bytes)
% } cbPKT_GENERIC;
% 
% cbPKT_GENERIC *cbGetNextPacketPtr(void);
% // Returns pointer to next packet in the shared memory space.  If no packet available, returns NULL
% 
% 
% ///////////////////////////////////////////////////////////////////////////////////////////////////
% //
% // Data Packet Structures (chid<0x8000)
% //
% ///////////////////////////////////////////////////////////////////////////////////////////////////
% 
% #define cbPKT_HEADER_SIZE 8  // define the size of the packet header in bytes
% 
% // Sample Group data packet
% typedef struct {
%     UINT32  time;       // system clock timestamp
%     UINT16  chid;       // 0x0000
%     UINT8   type;       // sample group ID (1-127)
%     UINT8   dlen;       // packet length equal
%     INT16   data[252];  // variable length address list
% } cbPKT_GROUP;
% 
% 
% // DINP digital value data
% typedef struct {
%     UINT32 time;        // system clock timestamp
%     UINT16 chid;        // channel identifier
%     UINT8  unit;        // reserved
%     UINT8  dlen;        // length of waveform in 32-bit chunks
%     UINT32 data[254];   // data buffer (up to 1016 bytes)
% } cbPKT_DINP;
% 
% 
% // AINP spike waveform data
% // cbMAX_PNTS must be an even number
% #define cbMAX_PNTS  128 // make large enough to track longest possible - spike width in samples
% 
% #define cbPKTDLEN_SPK   ((sizeof(cbPKT_SPK)/4)-2
% #define cbPKTDLEN_SPKSHORT (cbPKTDLEN_SPK - ((sizeof(INT16)*cbMAX_PNTS)/4))
% typedef struct {
%     UINT32 time;                // system clock timestamp
%     UINT16 chid;                // channel identifier
%     UINT8  unit;                // unit identification (0=unclassified, 31=artifact, 30=background)
%     UINT8  dlen;                // length of what follows ... always  cbPKTDLEN_SPK
%     float  fPattern[3];         // values of the pattern space (Normal uses only 2, PCA uses third)
%     INT16  nPeak;
%     INT16  nValley;
%     // wave must be the last item in the structure because it can be variable length to a max of cbMAX_PNTS
%     INT16  wave[cbMAX_PNTS];    // Room for all possible points collected
% } cbPKT_SPK;


d = @(x) typecast(x, 'uint8');

nSpikes = 50;
cbSpike = cell(nSpikes, 1);
for i = 1:2:nSpikes
    cbSpike{i} = cat(2, d(uint32(1000)), d(uint16(5)), d(uint8(1)), d(uint8(4 + 128/2)), d(single([0 0 0])), ...
        d(int16([0 0])), d(int16((1:128) + (i-1))));
    cbSpike{i+1} = cat(2, d(uint32(1000)), d(uint16(0)), d(uint8(5)), d(uint8(48/2)), d(int16((1:48) + (i-1))));
end

cbSpike = cat(2, cbSpike{:});

