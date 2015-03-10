clear;

setDisplayContext('rig5-displayPC-debugPartial');

ns = NetworkShell();
ns.catchErrors = false;
dbstop if error
ns.run();

