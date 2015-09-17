#ifndef RTW_HEADER_CerebusBuses_h_
#define RTW_HEADER_CerebusBuses_h_
#include "rtwtypes.h"

typedef struct {
  real32_T spikeTimeOffsets[96];
  uint8_T spikeChannels[96];
  uint8_T spikeUnits[96];
  int16_T spikeWaveforms[4608];
} SpikeDataBus;

typedef struct {
  real32_T continuousTimeOffsets[96];
  int16_T continuousData[5760];
} ContinuousDataBus;

typedef struct {
  uint32_T nUDPPackets;
  uint32_T nUDPBytes;
  uint32_T nCBPackets;
  uint32_T nSpikes;
  uint32_T nSpikesByChannel[96];
  uint16_T nContinuousChannels;
  uint32_T nContinuousSamples;
  int16_T mostRecentContinuousSamples[96];
  uint32_T cerebusClock;
  real32_T clockOffset;
  uint32_T cerebusClockRef;
  uint32_T localClockRef;
} CerebusStatisticsBus;

#endif                                 /* RTW_HEADER_CerebusBuses_h_ */
