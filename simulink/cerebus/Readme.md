# Cerebus Parsing Library

These library blocks receive, parse, and organize UDP packets received on the Simulink Real time computer that originate from a Blackrock Cerebus NSP. This block parses spike packets (preserving spike waveforms) and continuous packets.

## Features:

- Minimizes memcpy operations to speed the receiving and processing of the UDP packets. This is done by means of a custom UDP receive block that builds on top of Simulink's real time UDP blocks
- Parses incoming  `cbPKT` format by using C code to typecast back to struct, which simplifies parsing logic
- Provides output in the form of an organized bus containing spike times, waveforms and continuous samples
- Performant, should handle incoming broadband data from at least 192 channels in ~200 microseconds
- Provides a mechanism for converting the 30 kHz Cerebus clock into the local Simulink model clock, and a mechanism for resynchronizing these clock offsets periodically.

## Limitations:

- Does not parse configuration packets
- Assumes contiguous numbering of incoming channels. Will output an array of unlabeled spike channels and unlabeled continous channels which are sent by the NSP in numerical order. Therefore, you will need to independently track which channel is which in the list.
- Tracks only one continuous sample group, though this is user configurable, i.e. can track .ns2 packets at 2kHz or .ns6 raw data at 30 kHz but not both simultaneously. This would be relatively easy to add if needed but you'd have to dig into the code and copy/paste.
- Clock synchronization method is not closed loop, so all packets received will be timestamped approximately 6 ms after they actually occurred. This could be improved via some closed loop method where the real time PC sends a pulse to the Cerebus which is then received and used to measure the true latency.

## Setup:

- Add `matudp/simulink` and all subfolders to the Matlab path.

- Build the required Mex files `xpcnbexpose.c` and `xpcnbfree.c`. You can do this by running `buildMexCode.m`

- If you would like serialization / deserialization code for the Cerebus buses to be auto-generated for you by `BusSerialize`, then you need to specify a path in which to save the generated code, i.e. by running 

```matlab
BusSerialize.setGeneratedCodePath(`/path/to/generatedCode');
```
If you do not need this generated code (which is not necessary for simply parsing the incoming packets), then you do not need to do this, but you will need to comment out one line in initializeCerebusBuses which reads:

```matlab
BusSerialize.updateCodeForBuses({'SpikeDataBus', 'ContinuousDataBus', 'CerebusStatisticsBus'});
```

- Run `initializeCerebusBuses.m`. There are also settings that affect the sizes of various buffers and specify which continuous group number (e.g. ns2 or ns6) to record.

- Open Simulink model `testCerebusParseInC`

- Double click the `Configure UDP Interface` block to setup the Ethernet card to receive UDP.

- Double click on the UDP expose block to configure the UDP receive settings.

- Update and build the model, connect to Real time target and press play. Use the fake brain to generate data and see if you can see the continuous data samples and spike rates on the real time machine.
