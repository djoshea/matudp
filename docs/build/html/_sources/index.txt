.. MatUDP documentation master file, created by
   sphinx-quickstart on Thu Oct  2 22:59:57 2014.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

MatUDP: Simulink / Matlab structured communication
==================================================

MatUDP is a communication layer which connects for Mathworks Simulink Real Time (xPC Target), Matlab, and C via network communication over UDP. At its core, it provides a set of tools to declare structured data types or buses (akin to Simulink.Bus objects in Simulink and structs in Matlab), serialize them into UDP packets, and deserialize them at the receiver end. These core features support a number of applications in real-time applications built atop Simulink Real Time and Matlab:

* BusSerialize provides a simple interface for defining in code Simulink.Bus and Enum types with additional metadata for use in Simulink model, as well as auto-generating useful code for interacting with them.
* BusSerialize facilitates creating tunable parameters that can be easily adjusted on the xPC target with those structured Bus types.
* MatUdpDataLogger provides a C / mxArray-API based receiver that automatically logs data sent in the MatUDP serialized format. It revolves around the concept of trials which being at a specific time which is triggered by a special "next trial" control packet. By declaring fields as parameters, analog channels, or event channels, received data are buffered for a given trial and saved into a Matlab struct in a .mat file. The file location can be configured automatically by providing a special "data logger info" packet that specifies meta-information.
* MatUdpMexReceiver provides a MEX based receiver that buffers data similarly to MatUdpDataLogger but returns data straight into Matlab with very low (~1 ms) latency.
* Though a separate project from MatUDP, ScreenDraw is a wrapper for Psychophysics Toolbox v3 that provides an object-oriented approach to managing self-drawing, self-updating objects to the screen between each flip(). MatUDP provides a convenient network layer to control objects and execute Task commands in ScreenDraw.

Contents:

.. toctree::
   :maxdepth: 2



Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

