function build_udpMexReceiver()

try
    udpMexReceiver('STOP');
catch
end

current = pwd;
cd(fileparts(which('udpMexReceiver.c')));

%libPath = getenv('LD_LIBRARY_PATH');
% libPath = ['/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:' libPath];
%libPath = ['/usr/lib/gcc/x86_64-linux-gnu:' libPath];
%setenv('LD_LIBRARY_PATH', libPath);
mex -g -v -lrt -L/usr/lib/gcc/x86_64-linux-gnu $(CC)=gcc-4.4...
    udpMexReceiver.c ...
    ../serializedDataLogger/src/network.c ../serializedDataLogger/src/trie.c ...
    ../serializedDataLogger/src/signal.c ../serializedDataLogger/src/parser.c ...
    ../serializedDataLogger/src/utils.c ../serializedDataLogger/src/writer.c
cd(pwd);

end
